module gold_miner::gold_miner {
    use std::debug::print;
    use std::option;
    use std::u256;
    use std::u64;
    use std::vector;
    use moveos_std::account;
    use bitcoin_move::bbn;
    use gold_miner::boost_nft;
    use moveos_std::timestamp;
    use moveos_std::table_vec;
    use moveos_std::table_vec::TableVec;
    use moveos_std::simple_map::{Self, SimpleMap};
    use moveos_std::event::emit;
    use moveos_std::signer::address_of;
    use moveos_std::object::{
        Self,
        Object,
        borrow_mut_object_shared
    };
    use rooch_framework::account_coin_store;
    use rooch_framework::simple_rng;

    use gold_miner::gold_ore;
    use gold_miner::silver_ore;
    use gold_miner::copper_ore;
    use gold_miner::iron_ore;
    use gold_miner::refining_potion;
    use gold_miner::stamina_potion;
    use gold_miner::gold;

    use grow_bitcoin::grow_bitcoin;

    friend gold_miner::harvest;

    /// constants
    const BPS: u256 = 10000;
    /// Equipment types
    const EQUIPMENT_TYPE_REFINING_POTION: u8 = 1;
    const EQUIPMENT_TYPE_STAMINA_POTION: u8 = 2;
    const EQUIPMENT_TYPE_GOLD_ORE: u8 = 3;
    const EQUIPMENT_TYPE_SILVER_ORE: u8 = 4;
    const EQUIPMENT_TYPE_COPPER_ORE: u8 = 5;
    const EQUIPMENT_TYPE_IRON_ORE: u8 = 6;

    /// Error codes
    const EERROR_SELF_INVITE: u64 = 100001; // Can't invite yourself
    const EERROR_ALREADY_STARTED: u64 = 100002; // User already started mining
    const EERROR_AUTO_MINER_ACTIVE: u64 = 100003; // Auto miner is active
    const EERROR_BBN_EXPIRED: u64 = 100004; // BBN stake has expired
    const EERROR_ALREADY_INVITED: u64 = 100005; // Invitee was already invited
    const EERROR_NOT_ENOUGH_ENERGY: u64 = 100006; // Not enough energy to mine
    const EERROR_NOT_AUTO_MINER: u64 = 100007; // Not auto miner
    const EERROR_IS_AUTO_MINER: u64 = 100008; // Is auto miner
    const EERROR_NOT_STARTED: u64 = 100009; // Not started mining

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

    struct EquipmentMintEvent has copy, drop {
        player: address,
        equipment_type: u8
    }

    struct InviterRewardEvent has copy, drop {
        player: address,
        inviter: address,
        amount: u256
    }

    /// inetnal
    fun init() {
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
    public entry fun start(user: &signer, invite: address) {
        let player_address = address_of(user);
        assert!(player_address != invite, EERROR_SELF_INVITE); //"You can't invite yourself");
        //Check if user already has a miner object

        //FIXME: Why this check is no working?
        assert!(
            !account::exists_resource<MineInfo>(player_address),
            EERROR_ALREADY_STARTED
        ); //alerady start

        let gold_miner_obj_id = object::named_object_id<GoldMiner>();
        let gold_miner_obj = borrow_mut_object_shared<GoldMiner>(gold_miner_obj_id);
        let gold_miner = object::borrow_mut(gold_miner_obj);

        let inviter = option::none<address>();
        if (invite != @0x0) {
            // create_invite
            create_invite(gold_miner, invite, player_address);
            inviter = option::some(invite);
        };

        // Mint 100 token
        let amount = 100 * gold_miner.basic_mining_amount;

        let miner = MineInfo {
            mined: amount,
            hunger: 1000,
            last_update: timestamp::now_seconds(),
            boost_nft: option::none(),
            auto_miner: false,
            inviter
        };

        let treasury_obj_id = object::named_object_id<gold::Treasury>();
        let treasury_obj = borrow_mut_object_shared<gold::Treasury>(treasury_obj_id);
        let treasury = object::borrow_mut(treasury_obj);

        let gold_mine = gold::mint(treasury, amount);
        account_coin_store::do_accept_coin<gold::Gold>(user);
        account_coin_store::deposit(address_of(user), gold_mine);

        // Handle inviter rewards if exists
        handle_inviter_reward(user, treasury_obj, &mut miner, amount);

        account::move_resource_to(user,miner);
        
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
        assert!(hunger >= 1, EERROR_NOT_ENOUGH_ENERGY); // "Not enough energy to mine"

        // Update miner object
        gold_miner.hunger = hunger - 1;
        gold_miner.last_update = now;

        hunger
    }

    ///mine $GOLD
    public entry fun mine(
        user: &signer
    ) {
        // Get player address
        let player_address = address_of(user);
        assert!(account::exists_resource<MineInfo>(player_address), EERROR_NOT_STARTED); // "Not started mining"
        let gold_miner = account::borrow_mut_resource<MineInfo>(player_address);

        assert!(!gold_miner.auto_miner, EERROR_NOT_AUTO_MINER); // "not in auto miner can tap"

        // Calculate and update hunger
        let _hunger = calculate_and_update_hunger(gold_miner);

        // Calculate base amount
        let gold_miner_obj_id = object::named_object_id<GoldMiner>();
        let gold_miner_obj = borrow_mut_object_shared<GoldMiner>(gold_miner_obj_id);
        let gold_miner_state = object::borrow(gold_miner_obj);
        let base_amount = gold_miner_state.basic_mining_amount;

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

        let amount = u256::multiple_and_divide(base_amount,multiplier, BPS);
        gold_miner.mined = gold_miner.mined + amount;
        let total_mined = gold_miner.mined;

        // mint gold
        let treasury_obj_id = object::named_object_id<gold::Treasury>();
        let treasury_obj = borrow_mut_object_shared<gold::Treasury>(treasury_obj_id);
        let treasury = object::borrow_mut(treasury_obj);
        let gold_mine = gold::mint(treasury, amount);
        account_coin_store::deposit(address_of(user), gold_mine);

        emit(
            MineEvent { player: address_of(user), mined: amount, total_mined}
        );
    }

    ///mine $GOLD
    entry fun mine_bbn(
        user: &signer,
        miner_obj: &mut Object<MineInfo>,
        bbn_obj: &Object<bbn::BBNStakeSeal>
    ) {
        // Get player address
        // let player_address = address_of(user);

        let gold_miner = object::borrow_mut(miner_obj);
        assert!(!gold_miner.auto_miner, EERROR_NOT_AUTO_MINER); // "not in auto miner can tap"
        let bbn = object::borrow(bbn_obj);
        assert!(bbn::is_expired(bbn), EERROR_BBN_EXPIRED); // "BBN stake expired"

        // Calculate and update hunger
        let _hunger = calculate_and_update_hunger(gold_miner);

        // Calculate base amount
        let gold_miner_obj_id = object::named_object_id<GoldMiner>();
        let gold_miner_obj = borrow_mut_object_shared<GoldMiner>(gold_miner_obj_id);
        let gold_miner_state = object::borrow(gold_miner_obj);
        let base_amount = gold_miner_state.basic_mining_amount;

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

        let treasury_obj_id = object::named_object_id<gold::Treasury>();
        let treasury_obj = borrow_mut_object_shared<gold::Treasury>(treasury_obj_id);
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
        assert!(gold_miner.auto_miner, EERROR_NOT_AUTO_MINER); // "Not auto miner"

        // Get GoldMiner object to access basic_mining_amount
        let gold_miner_obj_id = object::named_object_id<GoldMiner>();
        let gold_miner_obj = borrow_mut_object_shared<GoldMiner>(gold_miner_obj_id);
        let gold_miner_state = object::borrow(gold_miner_obj);

        // Calculate base amount by rewrite with decimal
        let base_amount = base_amount * gold_miner_state.basic_mining_amount;

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

    // auto mine haverst with bbn stake
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
        assert!(bbn::is_expired(bbn), EERROR_BBN_EXPIRED); // "BBN stake expired"

        // Get GoldMiner object to access basic_mining_amount
        let gold_miner_obj_id = object::named_object_id<GoldMiner>();
        let gold_miner_obj = borrow_mut_object_shared<GoldMiner>(gold_miner_obj_id);
        let gold_miner_state = object::borrow(gold_miner_obj);

        // Calculate base amount by rewrite with decimal
        let base_amount = base_amount * gold_miner_state.basic_mining_amount;

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

        let amount = u256::multiple_and_divide(base_amount, multiplier, BPS);
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

    fun handle_inviter_reward(
        user: &signer,
        treasury_obj: &mut Object<gold::Treasury>,
        miner: &mut MineInfo,
        amount: u256
    ) {
        if (option::is_none(&miner.inviter)) { return };

        // Get GoldMiner object to access invite_reward_rate
        let gold_miner_obj_id = object::named_object_id<GoldMiner>();
        let gold_miner_obj = borrow_mut_object_shared<GoldMiner>(gold_miner_obj_id);
        let gold_miner_state = object::borrow(gold_miner_obj);

        let inviter = *option::borrow(&miner.inviter);
        let reward_amount =
            u256::multiple_and_divide(amount, gold_miner_state.invite_reward_rate, 10000);

        // Mint reward tokens for inviter
        let treasury = object::borrow_mut(treasury_obj);
        let reward = gold::mint(treasury, reward_amount);
        account_coin_store::deposit(inviter, reward);

        emit(
            InviterRewardEvent { player: address_of(user), inviter, amount: reward_amount }
        );
    }

    fun random_equipment(player: address) {
        // Get random number from timestamp
        let number = simple_rng::rand_u64_range(0, 10000);
        // Calculate probabilities (in parts per 1000):
        // Gold Ore: 0.05% = 0.5/1000
        // Silver Ore: 0.07% = 0.75/1000
        // Copper Ore: 0.1% = 1/1000
        // Iron Ore: 0.12% = 1.2/1000
        // Refining Potion: 0.01% = 0.1/1000
        // Stamina Potion: 0.02% = 0.2/1000

        if (number < 1) {
            //Refining Potion
            let potion = refining_potion::mint();
            object::transfer(potion, player);
            emit(
                EquipmentMintEvent {
                    player,
                    equipment_type: EQUIPMENT_TYPE_REFINING_POTION
                }
            );
        } else if (number < 3) {
            //Stamina Potion
            let potion = stamina_potion::mint();
            object::transfer(potion, player);
            emit(
                EquipmentMintEvent { player, equipment_type: EQUIPMENT_TYPE_STAMINA_POTION }
            );
        } else if (number < 8) {
            //Gold Ore
            let ore = gold_ore::mint(1);
            object::transfer(ore, player);
            emit(EquipmentMintEvent { player, equipment_type: EQUIPMENT_TYPE_GOLD_ORE });
        } else if (number < 16) {
            //Silver Ore
            let ore = silver_ore::mint(1);
            object::transfer(ore, player);
            emit(EquipmentMintEvent { player, equipment_type: EQUIPMENT_TYPE_SILVER_ORE });
        } else if (number < 24) {
            //Copper Ore
            let ore = copper_ore::mint(1);
            object::transfer(ore, player);
            emit(EquipmentMintEvent { player, equipment_type: EQUIPMENT_TYPE_COPPER_ORE });
        } else if (number < 36) {
            //Iron Ore
            let ore = iron_ore::mint(1);
            object::transfer(ore, player);
            emit(EquipmentMintEvent { player, equipment_type: EQUIPMENT_TYPE_IRON_ORE });
        }
    }


    // views function
    #[view]
    public fun get_mined(miner_obj: &Object<MineInfo>): u256 {
        let miner = object::borrow(miner_obj);
        miner.mined
    }

    #[view]
    public fun get_hunger(miner_obj: &Object<MineInfo>): u64 {
        let miner = object::borrow(miner_obj);
        miner.hunger
    }

    #[view]
    public fun get_last_update(miner_obj: &Object<MineInfo>): u64 {
        let miner = object::borrow(miner_obj);
        miner.last_update
    }

    #[view]
    public fun get_boost_nft(miner_obj: &Object<MineInfo>): &option::Option<Object<boost_nft::BoostNFT>> {
        let miner = object::borrow(miner_obj);
        &miner.boost_nft
    }

    #[view]
    public fun get_inviter(miner_obj: &Object<MineInfo>): &option::Option<address> {
        let miner = object::borrow(miner_obj);
        &miner.inviter
    }

    #[view]
    public fun get_auto_miner(miner_obj: &Object<MineInfo>): bool {
        let miner = object::borrow(miner_obj);
        miner.auto_miner
    }

    #[view]
    public fun get_total_tap(): u256 {
        let gold_miner_obj_id = object::named_object_id<GoldMiner>();
        let gold_miner_obj = object::borrow_object<GoldMiner>(gold_miner_obj_id);
        let gold_miner = object::borrow<GoldMiner>(gold_miner_obj);

        gold_miner.total_tap
    }

    #[view]
    public fun get_total_mined(): u256 {
        let gold_miner_obj_id = object::named_object_id<GoldMiner>();
        let gold_miner_obj = object::borrow_object<GoldMiner>(gold_miner_obj_id);
        let gold_miner = object::borrow<GoldMiner>(gold_miner_obj);

        gold_miner.total_mined
    }

    #[view]
    public fun get_basic_mining_amount(): u256 {
        let gold_miner_obj_id = object::named_object_id<GoldMiner>();
        let gold_miner_obj = object::borrow_object<GoldMiner>(gold_miner_obj_id);
        let gold_miner = object::borrow<GoldMiner>(gold_miner_obj);

        gold_miner.basic_mining_amount
    }

    #[view]
    public fun get_invite_reward_rate(): u256 {
        let gold_miner_obj_id = object::named_object_id<GoldMiner>();
        let gold_miner_obj = object::borrow_object<GoldMiner>(gold_miner_obj_id);
        let gold_miner = object::borrow<GoldMiner>(gold_miner_obj);

        gold_miner.invite_reward_rate
    }

    #[view]
    public fun get_invite_info(user:&address): &TableVec<address> {
        let gold_miner_obj_id = object::named_object_id<GoldMiner>();
        let gold_miner_obj = object::borrow_object<GoldMiner>(gold_miner_obj_id);
        let gold_miner = object::borrow<GoldMiner>(gold_miner_obj);

        simple_map::borrow(&gold_miner.invite_info, user)
    }

    #[view]
    public fun get_invite_reward(user:&address): u256 {
        let gold_miner_obj_id = object::named_object_id<GoldMiner>();
        let gold_miner_obj = object::borrow_object<GoldMiner>(gold_miner_obj_id);
        let gold_miner = object::borrow<GoldMiner>(gold_miner_obj);

        *simple_map::borrow(&gold_miner.invite_reward, user)
    }


    #[test_only]
    public fun test_init() {
        init();
    }
}
