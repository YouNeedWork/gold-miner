#[test_only]
module gold_miner::test_daily_check_in {
    use std::signer;
    use moveos_std::object::{Self, Object};
    use moveos_std::timestamp;
    use gold_miner::daily_check_in;
    use gold_miner::gold::{Self, Treasury};
    use rooch_framework::account_coin_store;
    use rooch_framework::coin_store_test;

    #[test_only]
    fun setup(user: &signer) {
        rooch_framework::genesis::init_for_test();
        //timestamp::fast_forward_seconds_for_test(10000);
        gold::test_init();
    }

    #[test(user = @0x42)]
    fun test_first_day_check_in(user: &signer) {
        setup(user);
        daily_check_in::first_day_check_in(user);

        // Get the check-in record
        let record_obj =
            object::take_object_by_id(
                user,
                object::account_named_object_id<daily_check_in::CheckInRecord>(
                    signer::address_of(user)
                )
            );
        let record = object::borrow(&record_obj);

        assert!(daily_check_in::get_total_days(record) == 1, 0);

        object::to_shared(treasury_obj);
        object::to_shared(record_obj);
    }

    #[test(user = @0x42)]
    #[expected_failure(abort_code = 100001)]
    fun test_double_first_day_check_in(user: &signer) {
        setup(user);
        let treasury_obj = object::take_shared<Treasury>();

        // First check-in should succeed
        daily_check_in::first_day_check_in(user, &mut treasury_obj);

        // Second check-in should fail
        daily_check_in::first_day_check_in(user, &mut treasury_obj);

        object::to_shared(treasury_obj);
    }

    #[test(user = @0x42)]
    fun test_regular_check_in(user: &signer) {
        setup(user);
        let treasury_obj = object::take_shared<Treasury>();

        // First day check-in
        daily_check_in::first_day_check_in(user, &mut treasury_obj);

        // Advance time by 1 day
        timestamp::set_now_seconds(86400000 + 10000);

        // Regular check-in
        let record_obj =
            object::take_object_by_id(
                user,
                object::account_named_object_id<daily_check_in::CheckInRecord>(
                    signer::address_of(user)
                )
            );
        daily_check_in::check_in(user, &mut record_obj, &mut treasury_obj);

        let record = object::borrow(&record_obj);
        assert!(daily_check_in::get_total_days(record) == 2, 0);

        // Verify reward received
        assert!(
            account_coin_store::balance<gold::GoldCoin>(signer::address_of(user))
                == 100 * 1_000_000,
            1
        );

        object::to_shared(treasury_obj);
        object::to_shared(record_obj);
    }

    #[test(user = @0x42)]
    #[expected_failure(abort_code = 100001)]
    fun test_double_check_in_same_day(user: &signer) {
        setup(user);
        let treasury_obj = object::take_shared<Treasury>();

        // First day check-in
        daily_check_in::first_day_check_in(user, &mut treasury_obj);

        // Try to check in again same day
        let record_obj =
            object::take_object_by_id(
                user,
                object::account_named_object_id<daily_check_in::CheckInRecord>(
                    signer::address_of(user)
                )
            );
        daily_check_in::check_in(user, &mut record_obj, &mut treasury_obj);

        object::to_shared(treasury_obj);
        object::to_shared(record_obj);
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
        daily_check_in::first_day_check_in(user, &mut treasury_obj);
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
        assert!(daily_check_in::get_total_days(record) == 30, 0);

        // Verify total rewards (29 daily rewards + 7 day bonus + 30 day bonus)
        assert!(
            account_coin_store::balance<gold::GoldCoin>(signer::address_of(user))
                == (29 * 100 * 1_000_000) + (1000 * 1_000_000) + (10000 * 1_000_000),
            1
        );

        object::to_shared(treasury_obj);
        object::to_shared(record_obj);
    }
}
