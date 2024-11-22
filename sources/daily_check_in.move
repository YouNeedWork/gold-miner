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
        continue_days: u64, // for continue check in, if not check in, it will be reset to 0
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

    #[test_only]
    fun setup(user: &signer) {
        rooch_framework::genesis::init_for_test();
        //timestamp::fast_forward_seconds_for_test(10000);
        gold::test_init();
    }

    #[test(user = @0x42)]
    fun test_first_day_check_in(user: &signer) {
        setup(user);
        check_in(user);

        // Get the check-in record
        let record_obj =
            object::take_object_by_id(
                user,
                object::account_named_object_id<CheckInRecord>(
                    signer::address_of(user)
                )
            );
        let record = object::borrow(&record_obj);

        assert!(get_total_days(record) == 1, 0);
    }

    #[test(user = @0x42)]
    #[expected_failure(abort_code = 100001)]
    fun test_double_check_in_same_day(user: &signer) {
        setup(user);
        // First check-in should succeed
        check_in(user);

        // Second check-in should fail
        check_in(user);
    }

    #[test(user = @0x42)]
    fun test_regular_check_in(user: &signer) {
        setup(user);

        // First day check-in
        check_int(user);

        // Advance time by 1 day
        timestamp::set_now_seconds(86400000 + 10000);

        // Regular check-in
        check_in(user);

        let record = object::borrow(&record_obj);
        assert!(get_total_days(record) == 2, 0);

        // Verify reward received
        assert!(
            account_coin_store::balance<gold::GoldCoin>(signer::address_of(user))
                == 100 * 1_000_000,
            1
        );
    }

    #[test(user = @0x42)]
    fun test_seven_day_bonus(user: &signer) {
        setup(user);
        let treasury_obj = object::take_shared<Treasury>();

        // First day check-in
        daily_check_in::first_day_check_in(user, &mut treasury_obj);
        let record_obj =
            object::take_object_by_id(
                user,
                object::account_named_object_id<daily_check_in::CheckInRecord>(
                    signer::address_of(user)
                )
            );

        // Check in for 6 more days
        let i = 1;
        while (i < 7) {
            timestamp::set_now_seconds((i as u64) * 86400000 + 10000);
            daily_check_in::check_in(user, &mut record_obj, &mut treasury_obj);
            i = i + 1;
        };

        let record = object::borrow(&record_obj);
        assert!(daily_check_in::get_total_days(record) == 7, 0);

        // Verify total rewards (6 daily rewards + 7 day bonus)
        assert!(
            account_coin_store::balance<gold::GoldCoin>(signer::address_of(user))
                == (6 * 100 * 1_000_000) + (1000 * 1_000_000),
            1
        );

        object::to_shared(treasury_obj);
        object::to_shared(record_obj);
    }

    #[test(user = @0x42)]
    fun test_thirty_day_bonus(user: &signer) {
        setup(user);
        let treasury_obj = object::take_shared<Treasury>();

        // First day check-in
        first_day_check_in(user, &mut treasury_obj);
        let record_obj =
            object::take_object_by_id(
                user,
                object::account_named_object_id<daily_check_in::CheckInRecord>(
                    signer::address_of(user)
                )
            );

        // Check in for 29 more days
        let i = 1;
        while (i < 30) {
            timestamp::set_now_seconds((i as u64) * 86400000 + 10000);
            daily_check_in::check_in(user, &mut record_obj, &mut treasury_obj);
            i = i + 1;
        };

        let record = object::borrow(&record_obj);
        assert!(get_total_days(record) == 30, 0);

        // Verify total rewards (29 daily rewards + 7 day bonus + 30 day bonus)
        assert!(
            account_coin_store::balance<gold::GoldCoin>(signer::address_of(user))
                == (29 * 100 * 1_000_000) + (1000 * 1_000_000) + (10000 * 1_000_000),
            1
        );
    }
}
