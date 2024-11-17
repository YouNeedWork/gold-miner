module gold_miner::auto_miner {
    use std::debug::print;
    use std::signer::address_of;
    use moveos_std::account;
    use gold_miner::gold::Gold;
    use moveos_std::object;
    use moveos_std::timestamp;
    use moveos_std::event;
    use gold_miner::gold;
    use rooch_framework::account_coin_store;

    friend gold_miner::gold_miner;

    // Error codes
    const E_INVALID_MINER_TYPE: u64 = 1;
    const E_MINER_EXPIRED: u64 = 2;
    const E_INSUFFICIENT_GOLD: u64 = 3;

    // Miner types
    const MANUAL_MINER: u8 = 1;
    const HYDRO_MINER: u8 = 2;
    const ELECTRIC_MINER: u8 = 3;

    // Duration in seconds
    const THREE_DAYS: u64 = 259200; // 3 * 24 * 60 * 60
    const SEVEN_DAYS: u64 = 604800; // 7 * 24 * 60 * 60
    const TWENTY_ONE_DAYS: u64 = 1814400; // 21 * 24 * 60 * 60

    struct Config has key {
        manual_miner_cost: u64,
        hydro_miner_cost: u64,
        electric_miner_cost: u64,
        manual_mining_power: u64,
        hydro_mining_power: u64,
        electric_mining_power: u64
    }

    struct AutoMiner has store,drop {
        owner: address,
        miner_type: u8,
        mining_power: u64,
        start_time: u64,
        duration: u64,
        last_claim: u64,
        total_mined: u64
    }

    //events
    struct MinerPurchaseEvent has copy, drop {
        owner: address,
        miner_type: u8,
        duration: u64,
        cost: u64
    }

    struct ClaimEvent has copy, drop {
        owner: address,
        amount: u64,
        total_mined: u64
    }

    fun init(user:&signer) {
        let config = Config {
            manual_miner_cost: 30_000,    //3w
            hydro_miner_cost: 50_000,     //5w
            electric_miner_cost: 100_000, //10w
            manual_mining_power: 3,
            hydro_mining_power: 5,
            electric_mining_power: 10
        };
        account::move_resource_to(user,config);
    }

    public(friend) fun purchase_miner(
        user: &signer,
        miner_type: u8,
        duration: u64
    ):AutoMiner {
        let cost = calculate_cost(miner_type, duration);
        let mining_power = get_mining_power(miner_type);

        // Verify valid miner type and duration
        assert!(
            miner_type >= MANUAL_MINER && miner_type <= ELECTRIC_MINER,
            E_INVALID_MINER_TYPE
        );
        assert!(
            duration == THREE_DAYS
                || duration == SEVEN_DAYS
                || duration == TWENTY_ONE_DAYS,
            E_INVALID_MINER_TYPE
        );

        // Create new miner
        let auto_miner = AutoMiner {
            owner: address_of(user),
            miner_type,
            mining_power,
            start_time: timestamp::now_seconds(),
            duration,
            last_claim: timestamp::now_seconds(),
            total_mined: 0
        };

        // Pay for miner
        let treasury_obj = gold::get_treasury();
        let treasury = object::borrow_mut(treasury_obj);
        let cost_coin = account_coin_store::withdraw<Gold>(user, (cost as u256));
        gold::burn(treasury, cost_coin);
        event::emit(
            MinerPurchaseEvent { owner: address_of(user), miner_type, duration, cost }
        );

        auto_miner
    }

    fun calculate_cost(miner_type: u8, duration: u64): u64 {
        let config = account::borrow_resource<Config>(@gold_miner);

        let base_cost =
            if (miner_type == MANUAL_MINER) {
                config.manual_miner_cost // 3w
            } else if (miner_type == HYDRO_MINER) {
                config.hydro_miner_cost // 5w
            } else {
                config.electric_miner_cost // 10w
            };

        let duration_multiplier =
            if (duration == THREE_DAYS) { 1 }
            else if (duration == SEVEN_DAYS) { 2 }
            else { 5 };

        base_cost * duration_multiplier * 1_000_000
    }

    fun get_mining_power(miner_type: u8): u64 {
        let config = account::borrow_resource<Config>(@gold_miner);

        if (miner_type == MANUAL_MINER) {
            config.manual_mining_power
        } else if (miner_type == HYDRO_MINER) {
            config.hydro_mining_power
        } else {
            config.electric_mining_power
        }
    }

    public fun is_expired(auto_miner: &AutoMiner): bool {
        let now = timestamp::now_seconds();
        now > auto_miner.start_time + auto_miner.duration
    }

    public(friend) fun get_harvest_amount(auto_miner: &mut AutoMiner): u64 {
        let now = timestamp::now_seconds();

        let now = if (now > auto_miner.start_time + auto_miner.duration) {
            auto_miner.start_time + auto_miner.duration
        } else {
            now
        };

        // Calculate rewards
        let time_since_last_claim = now - auto_miner.last_claim;
        let rewards = time_since_last_claim * auto_miner.mining_power / 60; //per minute
        auto_miner.last_claim = now;

        rewards
    }

    public(friend) fun burn(auto_miner: AutoMiner){
        let AutoMiner{
            owner: _,
            miner_type: _,
            mining_power: _,
            start_time: _,
            duration: _,
            last_claim: _,
            total_mined: _
        } = auto_miner;

        //TODO: lack event
    }

    #[view]
    public fun get_miner_info(miner: &AutoMiner): (address, u8, u64, u64, u64, u64, u64) {
        (
            miner.owner,
            miner.miner_type,
            miner.mining_power,
            miner.start_time,
            miner.duration,
            miner.last_claim,
            miner.total_mined
        )
    }


    #[view]
    public fun get_config(): (u64, u64, u64, u64, u64, u64) {
        let config = account::borrow_resource<Config>(@gold_miner);
        (
            config.manual_mining_power,
            config.hydro_mining_power, 
            config.electric_mining_power,
            config.manual_miner_cost,
            config.hydro_miner_cost,
            config.electric_miner_cost
        )
    }

    #[view]
    public fun get_manual_mining_power(): u64 {
        let config = account::borrow_resource<Config>(@gold_miner);
        config.manual_mining_power
    }

    #[view] 
    public fun get_hydro_mining_power(): u64 {
        let config = account::borrow_resource<Config>(@gold_miner);
        config.hydro_mining_power
    }

    #[view]
    public fun get_electric_mining_power(): u64 {
        let config = account::borrow_resource<Config>(@gold_miner);
        config.electric_mining_power
    }

    #[view]
    public fun get_manual_miner_cost(): u64 {
        let config = account::borrow_resource<Config>(@gold_miner);
        config.manual_miner_cost
    }

    #[view]
    public fun get_hydro_miner_cost(): u64 {
        let config = account::borrow_resource<Config>(@gold_miner);
        config.hydro_miner_cost
    }

    #[view]
    public fun get_electric_miner_cost(): u64 {
        let config = account::borrow_resource<Config>(@gold_miner);
        config.electric_miner_cost
    }


    #[test_only]
    public fun test_init(user:&signer) {
        init(user);
    }
}
