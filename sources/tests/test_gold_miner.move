#[test_only]
module gold_miner::test_gold_miner {

    use std::option;
    use std::signer;
    use rooch_framework::coin;
    use rooch_framework::coin_store;
    use moveos_std::object::{Self, Object};
    use moveos_std::account;
    use rooch_framework::account_coin_store;
    use gold_miner::gold::{Self, Gold, Treasury};
    use gold_miner::gold_miner::{Self, GoldMiner, MineInfo};
    use moveos_std::simple_map::{Self, SimpleMap};

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

    /*
    #[test]
    fun test_mine() {
        let user = account::create_account_for_test(@0x42);
        let treasury_id = object::named_object_id<Treasury>();
        let treasury_obj = object::new_named_object_from_guid(Treasury { coin_info: object::empty() });
        object::transfer_extend(treasury_obj, @0x42);

        // Initialize gold miner game state
        let gold_miner = gold_miner::GoldMiner {
            invite_info: simple_map::create(),
            invite_reward: simple_map::create(),
            total_tap: 0,
            total_mined: 0,
            basic_mining_amount: gold::basic_mining_amount(),
            invite_reward_rate: 1000 // 10% in bps
        };
        let gold_miner_obj = object::new_named_object(gold_miner);
        object::transfer_extend(gold_miner_obj, @0x42);

        // Create mine info for user
        let mine_info = MineInfo {
            mined: 0,
            hunger: 100,
            last_update: 0,
            boost_nft: option::none(),
            inviter: option::none(),
            auto_miner: false
        };
        let mine_info_obj = object::new_named_object(mine_info);
        object::transfer_extend(mine_info_obj, @0x42);

        // Test mining
        let treasury_obj = object::take_object<Treasury>(@0x42, treasury_id);
        let mine_info_obj = object::take_object<MineInfo>(@0x42, object::named_object_id<MineInfo>());

        let amount = gold_miner::mine(&user, &mut treasury_obj, &mut mine_info_obj);
        assert!(amount > 0, 0);

        // Verify mined amount was added to user's balance
        let balance = account_coin_store::balance<Gold>(signer::address_of(&user));
        assert!(balance == amount, 1);

        // Clean up
        object::transfer(treasury_obj, @0x42);
        object::transfer(mine_info_obj, @0x42);
    }
    */
}
