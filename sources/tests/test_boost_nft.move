#[test_only]
module gold_miner::test_boost_nft {
    use std::signer;
    use std::signer::address_of;
    use std::vector;
    use rooch_framework::gas_coin::RGas;
    use rooch_framework::account_coin_store;
    use rooch_framework::gas_coin;
    use rooch_framework::coin_store_test;
    use moveos_std::object::{Self, Object};
    use moveos_std::timestamp;
    use moveos_std::account;
    use gold_miner::boost_nft::{Self, BoostNFT};
    use gold_miner::admin;

    fun test_init(user: &signer) {
        rooch_framework::genesis::init_for_test();
        boost_nft::test_init(user);
    }

    #[test(user = @0x42)]
    fun test_mint_3x_boost(user: &signer) {
        test_init(user);
        let objects = boost_nft::test_init_3x(user); // 7 days
        let nft = object::borrow(&objects);
        assert!(boost_nft::get_multiplier(nft) == 30000, 1); // 3x
        assert!(!boost_nft::is_active(nft), 1);
        assert!(!boost_nft::is_expired(nft), 1);
        object::to_shared(objects);
    }

    #[test(user = @0x42)]
    fun test_activate_and_deactivate_boost(user: &signer) {
        test_init(user);
        let nft_obj = boost_nft::test_init_3x(user); // 7 days

        // Activate boost
        boost_nft::activate_boost(user, &mut nft_obj);
        assert!(boost_nft::is_active(object::borrow(&nft_obj)), 1);

        // Deactivate boost
        let nft = object::borrow_mut(&mut nft_obj);
        boost_nft::deactivate_boost(user, nft);
        assert!(!boost_nft::is_active(nft), 1);

        object::to_shared(nft_obj);
    }

    #[test(user = @0x42)]
    #[expected_failure(abort_code = 100000)]
    fun test_activate_already_active_boost(user: &signer) {
        test_init(user);
        let nft_obj = boost_nft::test_init_3x(user); // 7 days
        // First activation should succeed
        boost_nft::activate_boost(user, &mut nft_obj);
        // Second activation should fail
        boost_nft::activate_boost(user, &mut nft_obj);

        object::to_shared(nft_obj);
    }

    #[test(user = @gold_miner)]
    fun test_update_config(user: &signer) {
        test_init(user);
        let admin_cap = admin::test_create();

        let new_price_7_days = 20_000_000_000;
        let new_price_30_days = 50_000_000_000;
        let new_owner = @0x123;
        let new_og_root = vector[1, 2, 3];
        let new_early_root = vector[4, 5, 6];

        boost_nft::update_config(
            user,
            &admin_cap,
            new_price_7_days,
            new_price_30_days,
            new_owner,
            new_og_root,
            new_early_root
        );


        object::to_shared(admin_cap);
    }

    #[test_only]
    fun test_for_change_owner(user:&signer) {
        let admin_cap = admin::test_create();

        let new_price_7_days = 10_000_000_000;
        let new_price_30_days = 30_000_000_000;
        let new_owner = @0x41;
        let new_og_root = vector[1, 2, 3];
        let new_early_root = vector[4, 5, 6];

        boost_nft::update_config(
            user,
            &admin_cap,
            new_price_7_days,
            new_price_30_days,
            new_owner,
            new_og_root,
            new_early_root
        );


        object::to_shared(admin_cap);
    }


    #[test(user = @gold_miner)]
    fun test_mint_3x(user: &signer) {
        test_init(user);
        test_for_change_owner(user);
        let coin = gas_coin::mint_for_test(10_000_000_000);
        account_coin_store::deposit(address_of(user),coin);
        boost_nft::mint_3x_boost(user, 7*24*60*60);

        assert!(account_coin_store::balance<RGas>(@0x41) == 10_000_000_000,1);
    }

    //TODO: handle merkle tree verify for og early
}
