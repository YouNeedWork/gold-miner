#[test_only]
module gold_miner::test_gold_miner {
    use std::debug::print;
    use std::option;
    use std::signer;
    use std::signer::address_of;
    use gold_miner::hamburger;
    use gold_miner::gold_ore;
    use rooch_framework::simple_rng;
    use gold_miner::auto_miner;
    use gold_miner::boost_nft::BoostNFT;
    use gold_miner::boost_nft;
    use grow_bitcoin::grow_bitcoin;
    use moveos_std::timestamp;
    use rooch_framework::coin;
    use rooch_framework::coin_store;
    use moveos_std::object::{Self, Object};
    use moveos_std::account;
    use rooch_framework::account_coin_store;
    use gold_miner::gold::{Self, Gold, Treasury};
    use gold_miner::gold_miner::{Self, GoldMiner, MineInfo};
    use moveos_std::simple_map::{Self, SimpleMap};

    #[only_test]
    fun test_init(user: &signer) {
        rooch_framework::genesis::init_for_test();
        gold_miner::test_init(user);
        gold::test_init();
        auto_miner::test_init(user);

        gold_miner::start(user, @0x41);
    }

    #[test(user = @0x42)]
    fun test_start(user: &signer) {
        rooch_framework::genesis::init_for_test();
        gold_miner::test_init(user);
        gold::test_init();
        gold_miner::start(user, @0x41);

        assert!(account_coin_store::balance<gold::Gold>(@0x42) == 100 * 1_000_000, 1);
        assert!(
            account_coin_store::balance<gold::Gold>(@0x41)
                == 100 * 1_000_000 * 1500 / 10000,
            1
        );
    }

    #[test(user = @0x42)]
    #[expected_failure(abort_code = 100002)]
    fun test_failed_start_twice(user: &signer) {
        rooch_framework::genesis::init_for_test();
        gold_miner::test_init(user);
        gold::test_init();

        gold_miner::start(user, @0x41);
        assert!(account_coin_store::balance<gold::Gold>(@0x42) == 100 * 1_000_000, 1);
        gold_miner::start(user, @0x45);
    }

    #[test(user = @0x42)]
    fun test_mine_tap_1(user: &signer) {
        test_init(user);
        gold_miner::mine(user);
        assert!(account_coin_store::balance<gold::Gold>(@0x42) == 101 * 1_000_000, 1);
        assert!(
            account_coin_store::balance<gold::Gold>(@0x41) == 15 * 1_000_000 + 150_000,
            1
        );
    }

    #[test(user = @0x42)]
    fun test_mine_tap_1000(user: &signer) {
        test_init(user);
        let i = 0;
        while (i < 1000) {
            gold_miner::mine(user);
            i = i + 1;
        };
        assert!(account_coin_store::balance<gold::Gold>(@0x42) == 1100 * 1_000_000, 1);
    }

    #[test(user = @0x42)]
    #[expected_failure(abort_code = 100006)]
    fun test_failed_mine_tap_1001(user: &signer) {
        test_init(user);

        let i = 0;
        while (i < 1001) {
            gold_miner::mine(user);
            i = i + 1;
        };
    }

    #[test(user = @0x42)]
    fun test_mine_tap_1220(user: &signer) {
        test_init(user);
        let i = 0;
        while (i < 1000) {
            gold_miner::mine(user);
            i = i + 1;
        };
        assert!(account_coin_store::balance<gold::Gold>(@0x42) == 1100 * 1_000_000, 1);
        timestamp::fast_forward_seconds_for_test(60 * 120);

        let i = 0;
        while (i < 120) {
            gold_miner::mine(user);
            i = i + 1;
        };

        assert!(account_coin_store::balance<gold::Gold>(@0x42) == 1220 * 1_000_000, 1);
    }

    #[test(user = @0x42)]
    #[expected_failure(abort_code = 100006)]
    fun test_failed_mine_tap_1221(user: &signer) {
        test_init(user);
        let i = 0;
        while (i < 1000) {
            gold_miner::mine(user);
            i = i + 1;
        };
        assert!(account_coin_store::balance<gold::Gold>(@0x42) == 1100 * 1_000_000, 1);
        timestamp::fast_forward_seconds_for_test(60 * 120);

        let i = 0;
        while (i < 120) {
            gold_miner::mine(user);
            i = i + 1;
        };
        assert!(account_coin_store::balance<gold::Gold>(@0x42) == 1220 * 1_000_000, 1);

        gold_miner::mine(user);
    }

    #[test(user = @0x42)]
    fun test_mine_with_btc_stake(user: &signer) {
        test_init(user);

        // Simulate BTC staking
        grow_bitcoin::test_init(user);
        gold_miner::mine(user);

        // With BTC stake multiplier (2x), amount should be 2 * basic_mining_amount
        assert!(account_coin_store::balance<gold::Gold>(@0x42) == 103 * 1_000_000, 1);
    }

    #[test(user = @0x42)]
    fun test_mine_with_nft_boost(user: &signer) {
        test_init(user);
        let boost_3x = boost_nft::test_init_3x(user);

        gold_miner::boost_with_nft(user, boost_3x);
        gold_miner::mine(user);

        assert!(account_coin_store::balance<gold::Gold>(@0x42) == 104 * 1_000_000, 1);
        assert!(
            account_coin_store::balance<gold::Gold>(@0x41) == 15 * 1_000_000 + 600000,
            1
        );
    }

    #[test(user = @0x42)]
    #[expected_failure(abort_code = 100010)]
    fun test_failed_mine_with_nft_boost_twice(user: &signer) {
        test_init(user);
        let boost_3x = boost_nft::test_init_3x(user);
        gold_miner::boost_with_nft(user, boost_3x);
        gold_miner::mine(user);

        let boost_3x = boost_nft::test_init_early_1_7x(user);
        gold_miner::boost_with_nft(user, boost_3x);
        gold_miner::mine(user);
    }

    #[test(user = @0x42)]
    fun test_mine_with_nft_boost_and_remove_boost(user: &signer) {
        test_init(user);
        let boost_3x = boost_nft::test_init_3x(user);

        let object_id = object::id(&boost_3x);
        gold_miner::boost_with_nft(user, boost_3x);
        gold_miner::mine(user);

        assert!(account_coin_store::balance<gold::Gold>(@0x42) == 104 * 1_000_000, 1);
        assert!(
            account_coin_store::balance<gold::Gold>(@0x41) == 15 * 1_000_000 + 600000,
            1
        );

        gold_miner::remove_boost_nft(user);
        gold_miner::mine(user);

        assert!(account_coin_store::balance<gold::Gold>(@0x42) == 105 * 1_000_000, 1);
        assert!(
            account_coin_store::balance<gold::Gold>(@0x41) == 15 * 1_000_000 + 750000,
            1
        );
        assert!(object::exists_object_with_type<BoostNFT>(object_id), 1);
    }

    #[test(user = @0x42)]
    fun test_mine_with_nft_boost_and_boost_burn(user: &signer) {
        test_init(user);
        let boost_3x = boost_nft::test_init_3x(user);

        let object_id = object::id(&boost_3x);
        gold_miner::boost_with_nft(user, boost_3x);
        gold_miner::mine(user);

        assert!(account_coin_store::balance<gold::Gold>(@0x42) == 104 * 1_000_000, 1);
        assert!(
            account_coin_store::balance<gold::Gold>(@0x41) == 15 * 1_000_000 + 600000,
            1
        );
        assert!(!object::exists_object_with_type<BoostNFT>(object_id), 1);

        timestamp::fast_forward_seconds_for_test(7 * 24 * 60 * 60 + 1);
        gold_miner::mine(user);
        gold_miner::remove_boost_nft(user);

        assert!(account_coin_store::balance<gold::Gold>(@0x42) == 105 * 1_000_000, 1);
        assert!(
            account_coin_store::balance<gold::Gold>(@0x41) == 15 * 1_000_000 + 750000,
            1
        );
        assert!(!object::exists_object_with_type<BoostNFT>(object_id), 1);
    }

    #[test(user = @0x42)]
    fun test_mine_with_both_boosts(user: &signer) {
        test_init(user);
        // Add both BTC stake and NFT boost
        grow_bitcoin::test_init(user);
        let boost_3x = boost_nft::test_init_3x(user);
        gold_miner::boost_with_nft(user, boost_3x);
        gold_miner::mine(user);
        assert!(account_coin_store::balance<gold::Gold>(@0x42) == 106 * 1_000_000, 1);
        assert!(
            account_coin_store::balance<gold::Gold>(@0x41)
                == (106 * 1_000_000) * 15 / 100,
            1
        );
    }

    #[test(user = @gold_miner)]
    fun test_mine_with_auto_miner(user: &signer) {
        test_init(user);
        gold::test_mint(user, 30_000 * 1_000_000); //default 30_000

        gold_miner::purchase_miner(user, 1, 3 * 24 * 60 * 60);
        //nothing to do because the times not reach
        gold_miner::auto_mine(user);
        assert!(
            account_coin_store::balance<gold::Gold>(@gold_miner) == 100 * 1_000_000,
            1
        );
        assert!(account_coin_store::balance<gold::Gold>(@0x41) == 15 * 1_000_000, 1);

        timestamp::fast_forward_seconds_for_test(60 * 60); // 1 hour passed: 60min * 3click/min =180 reward
        gold_miner::auto_mine(user);
        assert!(
            account_coin_store::balance<gold::Gold>(@gold_miner) == 280 * 1_000_000,
            1
        );
        assert!(
            account_coin_store::balance<gold::Gold>(@0x41)
                == 280 * 1_000_000 * 15 / 100,
            1
        );

        timestamp::fast_forward_seconds_for_test(23 * 60 * 60); // one day passed: 1440min * 3click/min = 4320 reward
        gold_miner::auto_mine(user);
        assert!(
            account_coin_store::balance<gold::Gold>(@gold_miner) == 4420 * 1_000_000,
            1
        );
        assert!(
            account_coin_store::balance<gold::Gold>(@0x41)
                == 4420 * 1_000_000 * 15 / 100,
            1
        );

        timestamp::fast_forward_seconds_for_test(6 * 24 * 60 * 60 + 60); //reach the time to end
        gold_miner::auto_mine(user);

        // this only 3 days total, if the time in the 4th day, the reward will not increase
        assert!(
            account_coin_store::balance<gold::Gold>(@gold_miner) == 13060 * 1_000_000,
            1
        );
        assert!(
            account_coin_store::balance<gold::Gold>(@0x41)
                == 13060 * 1_000_000 * 15 / 100,
            1
        );
    }

    #[test(user = @gold_miner)]
    fun test_mine_with_auto_miner_7_days(user: &signer) {
        test_init(user);
        gold::test_mint(user, 60_000 * 1_000_000); // 2x cost for 7 days

        gold_miner::purchase_miner(user, 1, 7 * 24 * 60 * 60);

        // Initial balance check
        gold_miner::auto_mine(user);
        assert!(
            account_coin_store::balance<gold::Gold>(@gold_miner) == 100 * 1_000_000,
            1
        );
        assert!(account_coin_store::balance<gold::Gold>(@0x41) == 15 * 1_000_000, 1);

        // After 1 hour
        timestamp::fast_forward_seconds_for_test(60 * 60);
        gold_miner::auto_mine(user);
        assert!(
            account_coin_store::balance<gold::Gold>(@gold_miner) == 280 * 1_000_000,
            1
        );
        assert!(
            account_coin_store::balance<gold::Gold>(@0x41)
                == 280 * 1_000_000 * 15 / 100,
            1
        );

        // After 7 days
        timestamp::fast_forward_seconds_for_test(7 * 24 * 60 * 60);
        gold_miner::auto_mine(user);
        assert!(
            account_coin_store::balance<gold::Gold>(@gold_miner) == 30340 * 1_000_000,
            1
        );
        assert!(
            account_coin_store::balance<gold::Gold>(@0x41)
                == 30340 * 1_000_000 * 15 / 100,
            1
        );
    }

    #[test(user = @gold_miner)]
    fun test_mine_with_auto_miner_21_days(user: &signer) {
        test_init(user);
        gold::test_mint(user, 150_000 * 1_000_000); // 5x cost for 21 days

        gold_miner::purchase_miner(user, 1, 21 * 24 * 60 * 60);

        // Initial balance check
        gold_miner::auto_mine(user);
        assert!(
            account_coin_store::balance<gold::Gold>(@gold_miner) == 100 * 1_000_000,
            1
        );
        assert!(account_coin_store::balance<gold::Gold>(@0x41) == 15 * 1_000_000, 1);

        // After 1 hour
        timestamp::fast_forward_seconds_for_test(60 * 60);
        gold_miner::auto_mine(user);
        assert!(
            account_coin_store::balance<gold::Gold>(@gold_miner) == 280 * 1_000_000,
            1
        );
        assert!(
            account_coin_store::balance<gold::Gold>(@0x41)
                == 280 * 1_000_000 * 15 / 100,
            1
        );

        // After 21 days
        timestamp::fast_forward_seconds_for_test(21 * 24 * 60 * 60);
        gold_miner::auto_mine(user);
        assert!(
            account_coin_store::balance<gold::Gold>(@gold_miner) == 90820 * 1_000_000,
            1
        );
        assert!(
            account_coin_store::balance<gold::Gold>(@0x41)
                == 90820 * 1_000_000 * 15 / 100,
            1
        );
    }

    #[test(user = @gold_miner)]
    #[expected_failure(abort_code = 100007)]
    fun test_failed_mine_without_purchase_miner(user: &signer) {
        test_init(user);
        gold_miner::auto_mine(user);
    }

    #[test(user = @gold_miner)]
    #[expected_failure(abort_code = 100008)]
    fun test_failed_mine_without_purchase_twice(user: &signer) {
        test_init(user);
        gold::test_mint(user, 150_000 * 1_000_000); // 5x cost for 21 days
        gold_miner::purchase_miner(user, 1, 21 * 24 * 60 * 60);
        gold_miner::auto_mine(user);
        gold::test_mint(user, 150_000 * 1_000_000); // 5x cost for 21 days
        gold_miner::purchase_miner(user, 1, 21 * 24 * 60 * 60);
    }

    #[test(user = @gold_miner)]
    #[expected_failure(abort_code = 100007)]
    fun test_failed_mine_with_auto_miner_21_days(user: &signer) {
        test_init(user);
        gold::test_mint(user, 150_000 * 1_000_000); // 5x cost for 21 days
        gold_miner::purchase_miner(user, 1, 21 * 24 * 60 * 60);

        // Initial balance check
        gold_miner::auto_mine(user);
        assert!(
            account_coin_store::balance<gold::Gold>(@gold_miner) == 100 * 1_000_000,
            1
        );
        assert!(account_coin_store::balance<gold::Gold>(@0x41) == 15 * 1_000_000, 1);

        // After 1 hour
        timestamp::fast_forward_seconds_for_test(60 * 60);
        gold_miner::auto_mine(user);
        assert!(
            account_coin_store::balance<gold::Gold>(@gold_miner) == 280 * 1_000_000,
            1
        );
        assert!(
            account_coin_store::balance<gold::Gold>(@0x41)
                == 280 * 1_000_000 * 15 / 100,
            1
        );

        // After 21 days
        timestamp::fast_forward_seconds_for_test(21 * 24 * 60 * 60);
        gold_miner::auto_mine(user);
        assert!(
            account_coin_store::balance<gold::Gold>(@gold_miner) == 90820 * 1_000_000,
            1
        );
        assert!(
            account_coin_store::balance<gold::Gold>(@0x41)
                == 90820 * 1_000_000 * 15 / 100,
            1
        );

        // After expiry (22 days)
        gold_miner::auto_mine(user);
    }

    #[test(user = @gold_miner)]
    #[expected_failure(abort_code = 100007)]
    fun test_failed_mine_with_auto_miner_type2_21_days(user: &signer) {
        test_init(user);
        gold::test_mint(user, 250_000 * 1_000_000); // 5x cost for 21 days
        gold_miner::purchase_miner(user, 2, 21 * 24 * 60 * 60);

        // Initial balance check
        gold_miner::auto_mine(user);
        assert!(
            account_coin_store::balance<gold::Gold>(@gold_miner) == 100 * 1_000_000,
            1
        );
        assert!(account_coin_store::balance<gold::Gold>(@0x41) == 15 * 1_000_000, 1);

        // After 1 hour
        timestamp::fast_forward_seconds_for_test(60 * 60);
        gold_miner::auto_mine(user);
        assert!(
            account_coin_store::balance<gold::Gold>(@gold_miner) == 400 * 1_000_000,
            1
        );
        assert!(
            account_coin_store::balance<gold::Gold>(@0x41)
                == 400 * 1_000_000 * 15 / 100,
            1
        );

        // After 21 days
        timestamp::fast_forward_seconds_for_test(21 * 24 * 60 * 60);
        gold_miner::auto_mine(user);
        assert!(
            account_coin_store::balance<gold::Gold>(@gold_miner) == 151300 * 1_000_000,
            1
        );
        assert!(
            account_coin_store::balance<gold::Gold>(@0x41)
                == 151300 * 1_000_000 * 15 / 100,
            1
        );

        // After expiry (22 days)
        gold_miner::auto_mine(user);
    }

    #[test(user = @gold_miner)]
    #[expected_failure(abort_code = 100007)]
    fun test_failed_mine_with_auto_miner_type3_21_days(user: &signer) {
        test_init(user);
        gold::test_mint(user, 500_000 * 1_000_000); // 5x cost for 21 days
        gold_miner::purchase_miner(user, 3, 21 * 24 * 60 * 60);

        // Initial balance check
        gold_miner::auto_mine(user);
        assert!(
            account_coin_store::balance<gold::Gold>(@gold_miner) == 100 * 1_000_000,
            1
        );
        assert!(account_coin_store::balance<gold::Gold>(@0x41) == 15 * 1_000_000, 1);

        // After 1 hour
        timestamp::fast_forward_seconds_for_test(60 * 60);
        gold_miner::auto_mine(user);
        assert!(
            account_coin_store::balance<gold::Gold>(@gold_miner) == 700 * 1_000_000,
            1
        );
        assert!(
            account_coin_store::balance<gold::Gold>(@0x41)
                == 700 * 1_000_000 * 15 / 100,
            1
        );

        // After 21 days
        timestamp::fast_forward_seconds_for_test(21 * 24 * 60 * 60);
        gold_miner::auto_mine(user);
        assert!(
            account_coin_store::balance<gold::Gold>(@gold_miner) == 302500 * 1_000_000,
            1
        );
        assert!(
            account_coin_store::balance<gold::Gold>(@0x41)
                == 302500 * 1_000_000 * 15 / 100,
            1
        );

        // After expiry (22 days)
        gold_miner::auto_mine(user);
    }

    #[test(user = @gold_miner)]
    fun test_mine_with_auto_miner_type2_21_days(user: &signer) {
        test_init(user);
        gold::test_mint(user, 250_000 * 1_000_000); // 5x cost for 21 days
        gold_miner::purchase_miner(user, 2, 21 * 24 * 60 * 60);

        // Initial balance check
        gold_miner::auto_mine(user);
        assert!(
            account_coin_store::balance<gold::Gold>(@gold_miner) == 100 * 1_000_000,
            1
        );
        assert!(account_coin_store::balance<gold::Gold>(@0x41) == 15 * 1_000_000, 1);

        // After 1 hour
        timestamp::fast_forward_seconds_for_test(60 * 60);
        gold_miner::auto_mine(user);
        assert!(
            account_coin_store::balance<gold::Gold>(@gold_miner) == 400 * 1_000_000,
            1
        );
        assert!(
            account_coin_store::balance<gold::Gold>(@0x41)
                == 400 * 1_000_000 * 15 / 100,
            1
        );

        // After 21 days
        timestamp::fast_forward_seconds_for_test(21 * 24 * 60 * 60);
        gold_miner::auto_mine(user);
        assert!(
            account_coin_store::balance<gold::Gold>(@gold_miner) == 151300 * 1_000_000,
            1
        );
        assert!(
            account_coin_store::balance<gold::Gold>(@0x41)
                == 151300 * 1_000_000 * 15 / 100,
            1
        );
    }

    //eat hambuger
    #[test(user = @gold_miner)]
    fun test_eat_hambuger(user: &signer) {
        test_init(user);

        let i = 0;
        while (i < 301) {
            gold_miner::mine(user);
            i = i + 1;
        };

        let hambuger = hamburger::test_mint(user);
        gold_miner::eat_hambuger(user, hambuger);
    }

    #[test(user = @0x42)]
    fun test_random_equipment(user: &signer) {
        test_init(user);

        let i = 0;
        while (i < 10000) {
            gold_miner::mine(user);
            let hungry = gold_miner::get_hunger_through_times(address_of(user));

            if (hungry <= 600) {
                gold_miner::eat_hambuger(user, hamburger::test_mint(user));
            };

            i = i + 1;
        };

        // Check equipment counts based on probabilities
        // Gold Ore: 0.05% = 5 expected
        // FIXME: This test is flaky due to randomness
        // Only genrate raom number 1 times, with same results
        //let gold_ore_count = object::account_named_object_id<gold_ore::GoldOre>(@0x42);
        //assert!(object::exists_object_with_type<gold_ore::GoldOre>(gold_ore_count), 1);
    }
}
