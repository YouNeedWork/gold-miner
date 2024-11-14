module gold_miner::gold_miner {
    use std::option;
    use std::u64;
    use bitcoin_move::bbn;
    use gold_miner::boost_nft;
    use moveos_std::timestamp;
    use moveos_std::table_vec;
    use moveos_std::table_vec::TableVec;
    use moveos_std::simple_map::{Self, SimpleMap};
    use moveos_std::event::emit;
    use gold_miner::gold;
    use moveos_std::signer::address_of;
    use moveos_std::object::{Self, Object, account_named_object_id};
    use rooch_framework::account_coin_store;

    use grow_bitcoin::grow_bitcoin;

    friend gold_miner::auto_miner;

    /// The logic for gold miner Game
    struct GoldMiner has key, store {
        /// invite info
        invite_info: SimpleMap<address, TableVec<address>>,
        /// invite info
        invite_reward: SimpleMap<address, u256>,
        /// total_tap
        total_tap: u256,
        /// total_mined
        total_mined: u256,
        /// basic mining amount
        basic_mining_amount: u256,
        /// invite reward bps
        invite_reward_rate: u256
    }

    /// The info of a miner
    struct MineInfo has key {
        /// how many coin your mine
        mined: u256,

        /// energy for mining
        hunger: u64,

        /// last update time
        last_update: u64,

        /// Boost NFT in here
        boost_nft: option::Option<Object<boost_nft::BoostNFT>>,

        /// inviter
        inviter: option::Option<address>,

        /// auto miner
        auto_miner: bool
    }

    //events
    struct NewPlayerEvent has copy, drop {
        invite: address,
        player: address,
        mined: u256
    }

    struct MineEvent has copy, drop {
        player: address,
        mined: u256,
        total_mined: u256
    }

    /// inetnal
    fun init(_user: &signer) {
        let gold_miner = GoldMiner {
            invite_info: simple_map::new(),
            invite_reward: simple_map::new(),
            total_tap: 0,
            total_mined: 0,
            basic_mining_amount: 1_000_000,
            invite_reward_rate: 1500
        };
        object::to_shared(object::new_named_object(gold_miner))
    }

    fun create_invite(
        gold_miner: &mut GoldMiner, inviter: address, invitee: address
    ) {
        if (!simple_map::contains_key(&gold_miner.invite_info, &inviter)) {
            simple_map::add(
                &mut gold_miner.invite_info, inviter, table_vec::new<address>()
            );
        };
        let invitees = simple_map::borrow_mut(&mut gold_miner.invite_info, &inviter);
        let i = 0;
        let len = table_vec::length(invitees);
        while (i < len) {
            assert!(table_vec::borrow(invitees, i) != &invitee, 1); // "Invitee already invited"
            i = i + 1;
        };
        table_vec::push_back(invitees, invitee);
    }

    //entry
    entry fun start(
        user: &signer,
        gold_miner_obj: &mut Object<GoldMiner>,
        treasury_obj: &mut Object<gold::Treasury>,
        invite: address
    ) {
        let player_address = address_of(user);
        assert!(player_address != invite, 1); //"You can't invite yourself");

        //Check if user already has a miner object
        let object_id = account_named_object_id<MineInfo>(player_address);
        assert!(object::exists_object_with_type<MineInfo>(object_id), 2); //alerady start

        let gold_miner = object::borrow_mut(gold_miner_obj);

        let inviter = option::none<address>();
        if (invite != @0x0) {
            // create_invite
            create_invite(gold_miner, invite, player_address);
            inviter = option::some(invite);
        };

        // Mint 100 token
        let amount = 100 * gold::basic_mining_amount();

        let miner = MineInfo {
            mined: amount,
            hunger: 1000,
            last_update: timestamp::now_seconds(),
            boost_nft: option::none(),
            auto_miner: false,
            inviter
        };

        object::transfer_extend(object::new_named_object(miner), player_address);

        let treasury = object::borrow_mut(treasury_obj);
        let gold_mine = gold::mint(treasury, amount);
        account_coin_store::do_accept_coin<gold::Gold>(user);
        account_coin_store::deposit(address_of(user), gold_mine);

        emit(NewPlayerEvent { invite, player: player_address, mined: amount });
    }

    /// Calculate and update hunger (energy) for mining
    /// Returns the updated hunger value
    fun calculate_and_update_hunger(gold_miner: &mut MineInfo): u64 {
        let now = timestamp::now_seconds();

        // Calculate energy regeneration
        let time_passed = now - gold_miner.last_update;
        let hunger =
            if (gold_miner.hunger >= 1000) {
                gold_miner.hunger // Already at max
            } else {
                // Add 1 energy per second up to max
                u64::min(gold_miner.hunger + time_passed, 1000)
            };

        // Require at least 1 energy to mine
        assert!(hunger >= 1, 2); // "Not enough energy to mine"

        // Update miner object
        gold_miner.hunger = hunger - 1;
        gold_miner.last_update = now;

        hunger
    }

    ///mine $GOLD
    entry fun mine(
        user: &signer,
        treasury_obj: &mut Object<gold::Treasury>,
        miner_obj: &mut Object<MineInfo>
    ) {
        // Get player address
        let player_address = address_of(user);
        let gold_miner = object::borrow_mut(miner_obj);
        assert!(!gold_miner.auto_miner, 3); // "not in auto miner can tap"

        // Calculate and update hunger
        let _hunger = calculate_and_update_hunger(gold_miner);

        // Calculate base amount
        let base_amount = gold::basic_mining_amount();

        // Calculate multiplier based on staking status
        let multiplier: u256 = 10000;

        // handle btc stake
        if (grow_bitcoin::exists_stake_at_address(player_address)) {
            multiplier = multiplier + 20000;
        };

        // handle NFT stake
        if (option::is_some(&gold_miner.boost_nft)) {
            let nft_multiplier =
                boost_nft::get_multiplier(option::borrow_mut(&mut gold_miner.boost_nft));
            multiplier = multiplier + nft_multiplier; // Additional x for staked NFT
        };

        let amount = ((base_amount * multiplier / 10000) as u256);
        let miner = object::borrow_mut(miner_obj);
        miner.mined = miner.mined + amount;

        let treasury = object::borrow_mut(treasury_obj);
        let gold_mine = gold::mint(treasury, amount);
        account_coin_store::deposit(address_of(user), gold_mine);

        emit(
            MineEvent { player: address_of(user), mined: amount, total_mined: miner.mined }
        );
    }

    ///mine $GOLD
    entry fun mine_bbn(
        user: &signer,
        treasury_obj: &mut Object<gold::Treasury>,
        miner_obj: &mut Object<MineInfo>,
        bbn_obj: &Object<bbn::BBNStakeSeal>
    ) {
        // Get player address
        // let player_address = address_of(user);

        let gold_miner = object::borrow_mut(miner_obj);
        assert!(!gold_miner.auto_miner, 3); // "not in auto miner can tap"
        let bbn = object::borrow(bbn_obj);
        assert!(bbn::is_expired(bbn), 4); // "BBN stake expired"

        // Calculate and update hunger
        let _hunger = calculate_and_update_hunger(gold_miner);

        // Calculate base amount
        let base_amount = gold::basic_mining_amount();

        // Calculate multiplier based on staking status
        let multiplier = 10000;

        // handle btc stake
        multiplier = multiplier + 20000;

        // handle NFT stake
        if (option::is_some(&gold_miner.boost_nft)) {
            let nft_multiplier =
                boost_nft::get_multiplier(option::borrow_mut(&mut gold_miner.boost_nft));
            multiplier = multiplier + nft_multiplier; // Additional x for staked NFT
        };

        let amount = ((base_amount * multiplier / 10000) as u256);
        let miner = object::borrow_mut(miner_obj);
        miner.mined = miner.mined + amount;

        let treasury = object::borrow_mut(treasury_obj);
        let gold_mine = gold::mint(treasury, amount);
        account_coin_store::deposit(address_of(user), gold_mine);

        emit(
            MineEvent { player: address_of(user), mined: amount, total_mined: miner.mined }
        );
    }

    // internal function
    public(friend) fun mine_internal(
        user: &signer,
        treasury_obj: &mut Object<gold::Treasury>,
        miner_obj: &mut Object<MineInfo>,
        base_amount: u256
    ): u256 {
        let player_address = address_of(user);

        let gold_miner = object::borrow_mut(miner_obj);
        assert!(gold_miner.auto_miner, 3); // "Not auto miner"

        // Calculate base amount by rewrite with decimal
        let base_amount = base_amount * gold::basic_mining_amount();

        // Calculate multiplier based on staking status
        let multiplier = 10000; // Base 1x multiplier

        // handle btc stake
        if (grow_bitcoin::exists_stake_at_address(player_address)) {
            multiplier = multiplier + 20000;
        };

        // handle NFT stake
        if (option::is_some(&gold_miner.boost_nft)) {
            let nft_multiplier =
                boost_nft::get_multiplier(option::borrow_mut(&mut gold_miner.boost_nft));
            multiplier = multiplier + nft_multiplier;
        };

        let amount = base_amount * ((multiplier as u256) / 10000);
        let miner = object::borrow_mut(miner_obj);
        miner.mined = miner.mined + amount;

        let treasury = object::borrow_mut(treasury_obj);
        let gold_mine = gold::mint(treasury, amount);
        account_coin_store::deposit(address_of(user), gold_mine);

        emit(
            MineEvent { player: address_of(user), mined: amount, total_mined: miner.mined }
        );

        amount
    }

    //TODO: auto mine haverst with bbn stake
    // internal function
    public(friend) fun mine_internal_bbn(
        user: &signer,
        treasury_obj: &mut Object<gold::Treasury>,
        miner_obj: &mut Object<MineInfo>,
        bbn_obj: &Object<bbn::BBNStakeSeal>,
        base_amount: u256
    ): u256 {
        let gold_miner = object::borrow_mut(miner_obj);
        assert!(gold_miner.auto_miner, 3); // "Not auto miner"

        let bbn = object::borrow(bbn_obj);
        assert!(bbn::is_expired(bbn), 4); // "BBN stake expired"

        // Calculate base amount by rewrite with decimal
        let base_amount = base_amount * gold::basic_mining_amount();

        // Calculate multiplier based on staking status
        let multiplier = 10000; // Base 1x multiplier

        // handle btc stake
        multiplier = multiplier + 20000;

        // handle NFT stake
        if (option::is_some(&gold_miner.boost_nft)) {
            let nft_multiplier =
                boost_nft::get_multiplier(option::borrow_mut(&mut gold_miner.boost_nft));
            multiplier = multiplier + nft_multiplier;
        };

        let amount = base_amount * ((multiplier as u256) / 10000);
        let miner = object::borrow_mut(miner_obj);
        miner.mined = miner.mined + amount;

        let treasury = object::borrow_mut(treasury_obj);
        let gold_mine = gold::mint(treasury, amount);
        account_coin_store::deposit(address_of(user), gold_mine);

        emit(
            MineEvent { player: address_of(user), mined: amount, total_mined: miner.mined }
        );

        amount
    }

}
