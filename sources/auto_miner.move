module gold_miner::auto_miner {
    use std::signer::address_of;
    use bitcoin_move::bbn;
    use gold_miner::gold_miner;
    use gold_miner::gold_miner::MineInfo;
    use gold_miner::gold::Gold;
    use moveos_std::object::{Object};
    use moveos_std::object;
    use moveos_std::timestamp;
    use moveos_std::event;
    use gold_miner::gold;
    use rooch_framework::account_coin_store;

    friend gold_miner::harvest;

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

    struct AutoMiner has key {
        owner: address,
        miner_type: u8,
        mining_power: u64,
        start_time: u64,
        duration: u64,
        last_claim: u64,
        total_mined: u64
    }

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

    public fun purchase_miner(
        user: &signer,
        treasury_obj: &mut Object<gold::Treasury>,
        miner_type: u8,
        duration: u64
    ) {
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
        let treasury = object::borrow_mut(treasury_obj);
        let cost_coin = account_coin_store::withdraw<Gold>(user, (cost as u256));
        gold::burn(treasury, cost_coin);

        event::emit(
            MinerPurchaseEvent { owner: address_of(user), miner_type, duration, cost }
        );

        object::transfer_extend(object::new_named_object(auto_miner), address_of(user));
    }

    fun calculate_cost(miner_type: u8, duration: u64): u64 {
        let base_cost =
            if (miner_type == MANUAL_MINER) {
                100_000 // 10w
            } else if (miner_type == HYDRO_MINER) {
                200_000 // 20w
            } else {
                350_000 // 35w
            };

        let duration_multiplier =
            if (duration == THREE_DAYS) { 1 }
            else if (duration == SEVEN_DAYS) { 2 }
            else { 5 };

        base_cost * duration_multiplier * 1_000_000
    }

    fun get_mining_power(miner_type: u8): u64 {
        if (miner_type == MANUAL_MINER) {
            3 // 3 clicks per second
        } else if (miner_type == HYDRO_MINER) {
            10 // 10 clicks per second
        } else {
            30 // 30 clicks per second
        }
    }

    public(friend) fun get_harvest_amount(miner: &mut Object<AutoMiner>): u64 {
        let now = timestamp::now_seconds();
        let auto_miner = object::borrow_mut(miner);
        // Check if miner has expired
        assert!(now <= auto_miner.start_time + auto_miner.duration, 1); // "Auto miner expired"
        // Calculate rewards
        let time_since_last_claim = now - auto_miner.last_claim;
        let rewards = time_since_last_claim * auto_miner.mining_power;
        auto_miner.last_claim = now;

        rewards
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
}
