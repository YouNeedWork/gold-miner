#[test_only]
module gold_miner::test_gold_miner {

    use std::option;
    use std::signer;
    use std::signer::address_of;
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
    #[expected_failure]
    fun test_start_twice(user: &signer) {
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
    }
}
