module gold_miner::daily_check_in {
    use std::signer::address_of;
    use moveos_std::timestamp;
    use moveos_std::account;
    use moveos_std::event;
    use moveos_std::object;
    use moveos_std::timestamp::now_seconds;
    use rooch_framework::account_coin_store;
    use gold_miner::gold;

    const E_ALREADY_CHECKED_IN: u64 = 100001;
    const E_NOT_ENOUGH_DAYS: u64 = 100002;

    struct CheckInRecord has key {
        owner: address,
        last_check_in: u64,
        continue_days: u64,// for continue check in, if not check in, it will be reset to 0
        total_days: u64
    }

    struct CheckInEvent has copy, drop {
        user: address,
        timestamp: u64,
        total_days: u64
    }

    struct BonusRewardEvent has copy, drop {
        user: address,
        timestamp: u64,
        amount: u256,
        milestone_days: u64
    }

    fun init_check_in_record(user: &signer) {
        if (!account::exists_resource<CheckInRecord>(address_of(user))) {
            let record = CheckInRecord {
                owner: address_of(user),
                last_check_in: timestamp::now_seconds(),
                continue_days: 0,
                total_days: 0
            };
            account::move_resource_to(user, record);
        }
    }

    public entry fun check_in(user: &signer) {
        init_check_in_record(user);

        let user_address = address_of(user);
        let current_time = now_seconds();
        let today_start = current_time - (current_time % 86400000);

        let record = account::borrow_mut_resource<CheckInRecord>(user_address);

        assert!(record.last_check_in < today_start, E_ALREADY_CHECKED_IN);

        record.last_check_in = current_time;
        record.total_days = record.total_days + 1;

        let treasury = gold::get_treasury();
        let treasury = object::borrow_mut(treasury);

        // TODO add a config for the amount
        let amount = 100 * 1_000_000;

        let gold_mine = gold::mint(treasury, amount);
        account_coin_store::deposit(address_of(user), gold_mine);

        event::emit(
            CheckInEvent {
                user: address_of(user),
                timestamp: current_time,
                total_days: record.total_days
            }
        );

        if (record.total_days == 7) {
            let amount = 1000 * 1_000_000;
            let gold_mine = gold::mint(treasury, amount);
            account_coin_store::deposit(address_of(user), gold_mine);

            event::emit(
                BonusRewardEvent {
                    user: address_of(user),
                    timestamp: current_time,
                    amount,
                    milestone_days: 7
                }
            );
        } else if (record.total_days == 30) {
            let amount = 10000 * 1_000_000;
            let gold_mine = gold::mint(treasury, amount);
            account_coin_store::deposit(address_of(user), gold_mine);

            event::emit(
                BonusRewardEvent {
                    user: address_of(user),
                    timestamp: current_time,
                    amount,
                    milestone_days: 30
                }
            );
        }
    }

    #[view]
    public fun get_total_days(record: &CheckInRecord): u64 {
        record.total_days
    }
}
