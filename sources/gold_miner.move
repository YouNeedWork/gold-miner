module gold_miner::gold_miner {
    use std::u64;
    use moveos_std::timestamp;
    use moveos_std::table_vec;
    use moveos_std::table_vec::TableVec;
    use moveos_std::simple_map::{Self, SimpleMap};
    use moveos_std::event::emit;
    use gold_miner::gold;
    use moveos_std::signer::address_of;
    use moveos_std::object::{Self, Object, account_named_object_id};
    use rooch_framework::account_coin_store;

    //struct
    /// The logic for gold miner Game
    struct GoldMiner has key, store {
        /// invite info
        invite_info: SimpleMap<address, TableVec<address>>
    }

    /// The info of a miner
    struct MineInfo has key {
        /// how many coin your mine
        mined: u256,

        /// energy for mining
		hunger: u64,

        /// last update time
        last_update: u64
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
        let gold_miner = GoldMiner { invite_info: simple_map::new() };
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
        if (invite != @0x0) {
            // create_invite
            create_invite(gold_miner, invite, player_address);
        };

        // Mint 100 token
        let amount = 100 * 1_000_000;
        let miner = MineInfo {
            mined: amount,
            hunger: 1000,
            last_update: timestamp::now_seconds()
        };
        object::transfer_extend(object::new_named_object(miner), player_address);

        let treasury = object::borrow_mut(treasury_obj);
        let gold_mine = gold::mint(treasury, amount);
        account_coin_store::do_accept_coin<gold::Gold>(user);
        account_coin_store::deposit(address_of(user), gold_mine);

        emit(NewPlayerEvent { invite, player: player_address, mined: amount });
    }

    ///mine $GOLD
    entry fun mine(
        user: &signer,
        treasury_obj: &mut Object<gold::Treasury>,
        miner_obj: &mut Object<MineInfo>
    ) {
        // Get current timestamp in seconds
        let now = timestamp::now_seconds();

        // Get player address
        let player_address = address_of(user);
        let gold_miner = object::borrow_mut(miner_obj);

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

        // Calculate base amount
        let base_amount = 1 * 1_000_000;

        // Calculate multiplier based on staking status
        let multiplier = 1;

        /*
        TODO:
        if (has_staked_tokens(user)) {
            multiplier = multiplier + 1; // 2x for staked tokens
        };

        if (has_staked_nft(user)) {
            multiplier = multiplier + 2; // Additional 2x for staked NFT
        };
        */

        let amount = base_amount * multiplier;

        let miner = object::borrow_mut(miner_obj);
        miner.mined = miner.mined + amount;

        let treasury = object::borrow_mut(treasury_obj);
        let gold_mine = gold::mint(treasury, amount);
        account_coin_store::deposit(address_of(user), gold_mine);

        emit(
            MineEvent { player: address_of(user), mined: amount, total_mined: miner.mined }
        );
    }
}
