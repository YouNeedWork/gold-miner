#[test_only]
module gold_miner::test_gold_miner {
    use std::option;
    use std::signer;
    use std::signer::address_of;
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
    fun test_init(user:&signer) {
        rooch_framework::genesis::init_for_test();
        gold_miner::test_init();
        gold::test_init();
        gold_miner::start(user, @0x41);
    }

    #[test(user = @0x42)]
    fun test_start(user: &signer) {
        rooch_framework::genesis::init_for_test();
        gold_miner::test_init();
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
        gold_miner::test_init();
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
        assert!(account_coin_store::balance<gold::Gold>(@0x41) == 15 * 1_000_000 + 150_000, 1);
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
        timestamp::fast_forward_seconds_for_test(120);

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
        timestamp::fast_forward_seconds_for_test(120);

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
        //gold_miner::get_boost_nft(user, boost_3x);

        gold_miner::mine(user);
        // With NFT boost multiplier (2x), amount should be 2 * basic_mining_amount
        //assert!(account_coin_store::balance<gold::Gold>(@0x42) == 2 * 1_000_000, 1);

        object::transfer(boost_3x, address_of(user));
    }

    /*
        #[test(user = @0x42)]
        fun test_mine_with_both_boosts(user: &signer) {
            test_init(user);
            // Add both BTC stake and NFT boost
            grow_bitcoin::test_init_stake(user);
            boost_nft::test_init_nft(user);

            gold_miner::mine(user);
            // With both multipliers (5x total), amount should be 5 * basic_mining_amount
            assert!(account_coin_store::balance<gold::Gold>(@0x42) == 5 * 1_000_000, 1);
        }

        #[test(user = @0x42)]
        #[expected_failure(abort_code = 100006)]
        fun test_mine_without_energy(user: &signer) {
            test_init(user);
            let i = 0;
            while (i < 1000) {
                gold_miner::mine(user);
                i = i + 1;
            };
            // Try to mine without waiting for energy regeneration
            gold_miner::mine(user);
        }

        #[test(user = @0x42)]
        fun test_energy_regeneration(user: &signer) {
            test_init(user);
            // Use up some energy
            let i = 0;
            while (i < 500) {
                gold_miner::mine(user);
                i = i + 1;
            };

            // Wait for full energy regeneration
            timestamp::fast_forward_seconds_for_test(1000);

            // Should be able to mine 1000 times again
            let i = 0;
            while (i < 1000) {
                gold_miner::mine(user);
                i = i + 1;
            };
        }
        */
}
