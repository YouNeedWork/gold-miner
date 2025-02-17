module gold_miner::gold_miner {
    use std::option;
    use std::u256;
    use std::u64;
    use gold_miner::hamburger::{Hamburger};
    use gold_miner::boost_nft::BoostNFT;
    use moveos_std::account;
    use gold_miner::boost_nft;
    use moveos_std::timestamp;
    use moveos_std::table_vec;
    use moveos_std::table_vec::TableVec;
    use moveos_std::simple_map::{Self, SimpleMap};
    use moveos_std::event::emit;
    use moveos_std::signer::address_of;
    use moveos_std::object::{Self, Object, borrow_mut_object_shared};
    use rooch_framework::account_coin_store;
    use rooch_framework::simple_rng;

    use gold_miner::gold_ore;
    use gold_miner::silver_ore;
    use gold_miner::copper_ore;
    use gold_miner::iron_ore;
    use gold_miner::refining_potion;
    use gold_miner::hamburger;
    use gold_miner::gold;
    use gold_miner::auto_miner;

    use grow_bitcoin::grow_bitcoin;

    /// constants
    const BPS: u256 = 10000;
    /// Equipment types
    const EQUIPMENT_TYPE_REFINING_POTION: u8 = 1;
    const EQUIPMENT_TYPE_HAMBUGER: u8 = 2;
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
    const EERROR_ALREADY_BOOSTED: u64 = 100010; // Already have boost NFT

    /// The logic for gold miner Game
    struct GoldMiner has key, store {
        team_address: address,
        /// invite info
        invite_info: SimpleMap<address, TableVec<address>>,
        /// invite info
        invite_reward: SimpleMap<address, u256>,
        /// total_users
        total_user: u256,
        /// total_tap
        total_tap: u256,
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
        boost_nft: option::Option<boost_nft::BoostNFT>,

        /// inviter
        inviter: option::Option<address>,

        /// auto miner
        auto_miner: option::Option<auto_miner::AutoMiner>
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

    struct PurchaseMinerEvent has copy, drop {
        buyer: address,
        miner_type: u8,
        duration: u64,
        cost: u64
    }

    struct EatHambugerEvent has copy, drop {
        player: address,
        recover: u64,
        total_hunger: u64
    }

    /// inetnal
    fun init(admin: &signer) {
        let gold_miner = GoldMiner {
            team_address: address_of(admin),
            invite_info: simple_map::new(),
            invite_reward: simple_map::new(),
            total_user: 0,
            total_tap: 0,
            basic_mining_amount: 1_000_000,
            invite_reward_rate: 1500
        };
        object::to_shared(object::new_named_object(gold_miner))
    }

    //entry
    public entry fun start(user: &signer, invite: address) {
        let player_address = address_of(user);
        assert!(player_address != invite, EERROR_SELF_INVITE); //"You can't invite yourself");
        // Check if user already has a miner object
        assert!(
            !account::exists_resource<MineInfo>(player_address),
            EERROR_ALREADY_STARTED
        ); //alerady start

        let gold_miner_obj_id = object::named_object_id<GoldMiner>();
        let gold_miner_obj = borrow_mut_object_shared<GoldMiner>(gold_miner_obj_id);
        let gold_miner = object::borrow_mut(gold_miner_obj);

        // update total user
        gold_miner.total_user = gold_miner.total_user + 1;

        let team_address = gold_miner.team_address;
        let inviter = option::some<address>(gold_miner.team_address);



        // Mint 100 token
        let amount = 100 * gold_miner.basic_mining_amount;

        let miner = MineInfo {
            mined: amount,
            hunger: 1000,
            last_update: timestamp::now_seconds(),
            boost_nft: option::none(),
            auto_miner: option::none(),
            inviter
        };

        let treasury_obj_id = object::named_object_id<gold::Treasury>();
        let treasury_obj = borrow_mut_object_shared<gold::Treasury>(treasury_obj_id);
        let treasury = object::borrow_mut(treasury_obj);

        let gold_mine = gold::mint(treasury, amount);
        account_coin_store::do_accept_coin<gold::Gold>(user);
        account_coin_store::deposit(address_of(user), gold_mine);


        if (invite != @0x0) {
            // create_invite
            create_invite(gold_miner, invite, player_address);
            inviter = option::some(invite);

            let gold_mine = gold::mint(treasury, amount);
            account_coin_store::deposit(invite, gold_mine);
        } else {
            create_invite(gold_miner, team_address, player_address);

            let gold_mine = gold::mint(treasury, amount);
            account_coin_store::deposit(team_address, gold_mine);
        };


        // Handle inviter rewards if exists
        handle_inviter_reward(user, treasury_obj, &mut miner, amount);

        account::move_resource_to(user, miner);

        emit(NewPlayerEvent { invite, player: player_address, mined: amount });
    }

    public entry fun purchase_miner(
        user: &signer, miner_type: u8, duration: u64
    ) {
        let player_address = address_of(user);
        assert!(account::exists_resource<MineInfo>(player_address), EERROR_NOT_STARTED); // "Not started mining"
        let gold_miner = account::borrow_mut_resource<MineInfo>(player_address);
        assert!(option::is_none(&gold_miner.auto_miner), EERROR_IS_AUTO_MINER); // "not in auto miner can buyer"
        let (miner_nft, cost) = auto_miner::purchase_miner(user, miner_type, duration);
        gold_miner.auto_miner = option::some(miner_nft);

        emit(
            PurchaseMinerEvent { buyer: player_address, miner_type, duration, cost }
        );
    }

    public entry fun boost_with_nft(
        user: &signer, nft_obj: Object<BoostNFT>
    ) {
        let player_address = address_of(user);
        assert!(account::exists_resource<MineInfo>(player_address), EERROR_NOT_STARTED); // "Not started mining"
        let gold_miner = account::borrow_mut_resource<MineInfo>(player_address);
        // check if already have boost nft
        assert!(option::is_none(&gold_miner.boost_nft), EERROR_ALREADY_BOOSTED); // "Already have boost NFT"

        boost_nft::activate_boost(user, &mut nft_obj);
        let nft = boost_nft::remove_object(nft_obj);
        gold_miner.boost_nft = option::some(nft);
    }

    public entry fun remove_boost_nft(user: &signer) {
        let player_address = address_of(user);
        assert!(account::exists_resource<MineInfo>(player_address), EERROR_NOT_STARTED); // "Not started mining"
        let gold_miner = account::borrow_mut_resource<MineInfo>(player_address);
        assert!(option::is_some(&gold_miner.boost_nft), 1); // "No boost NFT to remove"
        let nft_obj = option::extract(&mut gold_miner.boost_nft);
        assert!(boost_nft::is_active(&nft_obj), 1); // "Boost NFT is not active"
        if (boost_nft::is_expired(&nft_obj)) {
            boost_nft::deactivate_boost(&mut nft_obj);
            boost_nft::burn_boost(nft_obj, player_address);
        } else {
            boost_nft::deactivate_boost(&mut nft_obj);
            object::transfer(boost_nft::new_object(nft_obj), player_address);
        }
    }

    public entry fun mine(user: &signer) {

        // Get player address
        let player_address = address_of(user);
        assert!(account::exists_resource<MineInfo>(player_address), EERROR_NOT_STARTED); // "Not started mining"
        let gold_miner = account::borrow_mut_resource<MineInfo>(player_address);

        // Calculate and update hunger
        let _hunger = calculate_and_update_hunger(gold_miner);

        // Calculate base amount
        let gold_miner_obj_id = object::named_object_id<GoldMiner>();
        let gold_miner_obj = borrow_mut_object_shared<GoldMiner>(gold_miner_obj_id);
        let gold_miner_state = object::borrow_mut(gold_miner_obj);
        gold_miner_state.total_tap = gold_miner_state.total_tap + 1;

        let base_amount = 100 * gold_miner_state.basic_mining_amount;

        // Calculate multiplier based on staking status
        let multiplier: u256 = 10000;

        // handle btc stake
        if (grow_bitcoin::exists_stake_at_address(player_address)) {
            multiplier = multiplier + 20000;
        };

        // handle NFT stake
        if (option::is_some(&gold_miner.boost_nft)
            && !boost_nft::is_expired(option::borrow(&gold_miner.boost_nft))) {
            let nft_multiplier =
                boost_nft::get_multiplier(option::borrow(&gold_miner.boost_nft));
            multiplier = multiplier + nft_multiplier; // Additional x for staked NFT
        };

        let amount = u256::multiple_and_divide(base_amount, multiplier, BPS);
        gold_miner.mined = gold_miner.mined + amount;
        let total_mined = gold_miner.mined;

        // mint gold
        let treasury_obj_id = object::named_object_id<gold::Treasury>();
        let treasury_obj = borrow_mut_object_shared<gold::Treasury>(treasury_obj_id);
        let treasury = object::borrow_mut(treasury_obj);
        let gold_mine = gold::mint(treasury, amount);
        account_coin_store::deposit(address_of(user), gold_mine);

        // Handle inviter rewards if exists
        handle_inviter_reward(user, treasury_obj, gold_miner, amount);

        // Handle random equipment
        random_equipment(player_address);

        emit(MineEvent { player: address_of(user), mined: amount, total_mined });

        if (option::is_some(&gold_miner.boost_nft)
            && boost_nft::is_expired(option::borrow(&gold_miner.boost_nft))) {
            remove_boost_nft(user);
        }
    }

    public entry fun auto_mine(user: &signer) {
        // Get player address
        let player_address = address_of(user);
        assert!(account::exists_resource<MineInfo>(player_address), EERROR_NOT_STARTED); // "Not started mining"
        let gold_miner = account::borrow_mut_resource<MineInfo>(player_address);
        assert!(option::is_some(&gold_miner.auto_miner), EERROR_NOT_AUTO_MINER); // "Not auto miner"

        // Get auto miner object
        let auto_miner = option::borrow_mut(&mut gold_miner.auto_miner);
        // Get claim amount for per minute
        let base_amount = (auto_miner::get_harvest_amount(auto_miner) as u256);

        if (auto_miner::is_expired(auto_miner)) {
            //delete auto miner
            let boost = option::extract(&mut gold_miner.auto_miner);
            auto_miner::burn(boost);
        };

        // Get GoldMiner object to access basic_mining_amount
        let gold_miner_obj_id = object::named_object_id<GoldMiner>();
        let gold_miner_obj = borrow_mut_object_shared<GoldMiner>(gold_miner_obj_id);
        let gold_miner_state = object::borrow(gold_miner_obj);

        // Calculate base amount by rewrite with decimal
        let base_amount = base_amount * gold_miner_state.basic_mining_amount;

        // Calculate multiplier based on staking status
        let multiplier = 10000; // Base 1x multiplier

        /*
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
        */

        let amount = u256::multiple_and_divide(base_amount, multiplier, BPS);
        gold_miner.mined = gold_miner.mined + amount;
        let total_mined = gold_miner.mined;

        let treasury_obj = gold::get_treasury();
        let treasury = object::borrow_mut(treasury_obj);
        let gold_mine = gold::mint(treasury, amount);
        account_coin_store::deposit(address_of(user), gold_mine);

        // Handle inviter rewards if exists
        handle_inviter_reward(user, treasury_obj, gold_miner, amount);

        emit(MineEvent { player: address_of(user), mined: amount, total_mined });
    }

    public entry fun eat_hambuger(
        user: &signer, hambuger: Object<Hamburger>
    ) {
        // Get player address
        let player_address = address_of(user);
        assert!(account::exists_resource<MineInfo>(player_address), EERROR_NOT_STARTED); // "Not started mining"
        let gold_miner = account::borrow_mut_resource<MineInfo>(player_address);

        hamburger::burn(&player_address, hambuger);
        // Calculate and update hunger
        let hunger = calculate_and_update_hunger(gold_miner);
        //We add 301 energy for eating hambuger because it's decurase 1 energy by call calculate_and_update_hunger
        gold_miner.hunger = u64::min(hunger + 301, 1000);

        emit(
            EatHambugerEvent {
                player: player_address,
                recover: 300,
                total_hunger: gold_miner.hunger
            }
        );
    }

    // internal function
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
        let gold_miner = object::borrow_mut(gold_miner_obj);

        let inviter = *option::borrow(&miner.inviter);
        if (!simple_map::contains_key(&gold_miner.invite_reward, &inviter)) {
            simple_map::add(
                &mut gold_miner.invite_reward, inviter, 0
            );
        };

        let reward_amount =
            u256::multiple_and_divide(amount, gold_miner.invite_reward_rate, 10000);

        let invite_reward = simple_map::borrow_mut(&mut gold_miner.invite_reward, &inviter);
        *invite_reward = *invite_reward+reward_amount;

        // Mint reward tokens for inviter
        let treasury = object::borrow_mut(treasury_obj);
        let reward = gold::mint(treasury, reward_amount);
        account_coin_store::deposit(inviter, reward);

        emit(
            InviterRewardEvent { player: address_of(user), inviter, amount: reward_amount }
        );
    }

    /// Calculate and update hunger (energy) for mining
    /// Returns the updated hunger value
    fun calculate_and_update_hunger(gold_miner: &mut MineInfo): u64 {
        let now = timestamp::now_seconds();

        // Calculate energy regeneration
        let time_passed = (now - gold_miner.last_update) / 60; // 1 energy per minute

        // Add 1 energy per second up to max
        let hunger = u64::min(gold_miner.hunger + time_passed, 1000);

        // Require at least 1 energy to mine
        assert!(hunger >= 1, EERROR_NOT_ENOUGH_ENERGY); // "Not enough energy to mine"

        // Update miner object
        gold_miner.hunger = hunger - 1;
        gold_miner.last_update = now;

        hunger
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
            let hambuger = hamburger::mint(&player);
            object::transfer(hambuger, player);
            emit(EquipmentMintEvent { player, equipment_type: EQUIPMENT_TYPE_HAMBUGER });
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


    fun boost_rate(player_address:address,base:u256) :u256 {
       let rate = get_boost_rate(player_address);

        base * rate
    }

    public fun get_boost_rate(player_address:address):u256 {
        assert!(account::exists_resource<MineInfo>(player_address), EERROR_NOT_STARTED); // "Not started mining"
        let gold_miner = account::borrow_resource<MineInfo>(player_address);

        // Calculate multiplier based on staking status
        let multiplier = 10000; // Base 1x multiplier

        // handle btc stake
        if (grow_bitcoin::exists_stake_at_address(player_address)) {
            multiplier = multiplier + 20000;
        };

        // handle NFT stake
        if (option::is_some(&gold_miner.boost_nft)) {
            let nft_multiplier =
                boost_nft::get_multiplier(option::borrow(&gold_miner.boost_nft));
            multiplier = multiplier + nft_multiplier;
        };

        multiplier / BPS
    }

    #[view]
    public fun get_hunger_through_times(player_address: address): u64 {
        let gold_miner = account::borrow_resource<MineInfo>(player_address);
        let now = timestamp::now_seconds();
        let time_passed = (now - gold_miner.last_update) / 60; // 1 energy per minute

        u64::min(gold_miner.hunger + time_passed, 1000)
    }

    public fun get_auto_mine_harvest_amount(player_address: address): u256 {
        assert!(account::exists_resource<MineInfo>(player_address), EERROR_NOT_STARTED); // "Not started mining"
        let gold_miner = account::borrow_resource<MineInfo>(player_address);
        assert!(option::is_some(&gold_miner.auto_miner), EERROR_NOT_AUTO_MINER); // "Not auto miner"

        // Get auto miner object
        let auto_miner = option::borrow(&gold_miner.auto_miner);
        // Get claim amount for per minute
        let base_amount = (auto_miner::harvest_amount(auto_miner) as u256);

        // Get GoldMiner object to access basic_mining_amount
        let gold_miner_obj_id = object::named_object_id<GoldMiner>();
        let gold_miner_obj = borrow_mut_object_shared<GoldMiner>(gold_miner_obj_id);
        let gold_miner_state = object::borrow(gold_miner_obj);

        // Calculate base amount by rewrite with decimal
        let base_amount = base_amount * gold_miner_state.basic_mining_amount;

        // Calculate multiplier based on staking status
        let multiplier = 10000; // Base 1x multiplier

        /*
        // handle btc stake
        if (grow_bitcoin::exists_stake_at_address(player_address)) {
            multiplier = multiplier + 20000;
        };

        // handle NFT stake
        if (option::is_some(&gold_miner.boost_nft)) {
            let nft_multiplier =
                boost_nft::get_multiplier(option::borrow(&gold_miner.boost_nft));
            multiplier = multiplier + nft_multiplier;
        };
        */

        let amount = u256::multiple_and_divide(base_amount, multiplier, BPS);

        amount
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
    public fun get_inviter(miner_obj: &Object<MineInfo>): &option::Option<address> {
        let miner = object::borrow(miner_obj);
        &miner.inviter
    }

    #[view]
    public fun get_total_users(): u256 {
        let gold_miner_obj_id = object::named_object_id<GoldMiner>();
        let gold_miner_obj = object::borrow_object<GoldMiner>(gold_miner_obj_id);
        let gold_miner = object::borrow<GoldMiner>(gold_miner_obj);

        gold_miner.total_user
    }

    #[view]
    public fun get_total_tap(): u256 {
        let gold_miner_obj_id = object::named_object_id<GoldMiner>();
        let gold_miner_obj = object::borrow_object<GoldMiner>(gold_miner_obj_id);
        let gold_miner = object::borrow<GoldMiner>(gold_miner_obj);

        gold_miner.total_tap
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
    public fun get_invite_reward(user: address): u256 {
        let gold_miner_obj_id = object::named_object_id<GoldMiner>();
        let gold_miner_obj = object::borrow_object<GoldMiner>(gold_miner_obj_id);
        let gold_miner = object::borrow<GoldMiner>(gold_miner_obj);

        *simple_map::borrow(&gold_miner.invite_reward, &user)
    }

    #[test_only]
    public fun test_init(user: &signer) {
        init(user);
    }
}
