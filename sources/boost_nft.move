module gold_miner::boost_nft {
    use std::signer;

    use moveos_std::timestamp;
    use moveos_std::event;
    use moveos_std::object::{Self, Object, ObjectID};

    friend gold_miner::gold_miner;

    // Error codes
    const EBoostAlreadyActive: u64 = 0;
    const EBoostExpired: u64 = 1;
    const ENotAuthorized: u64 = 2;

    // Boost multipliers bps
    const BOOST_3X: u64 = 30000; // 3.0x represented as basis points
    const BOOST_2X: u64 = 20000; // 2.0x for OG
    const BOOST_1_7X: u64 = 17000; // 1.7x for early participants

    // Time constants (in seconds)
    const SEVEN_DAYS: u64 = 7 * 24 * 60 * 60;
    const THIRTY_DAYS: u64 = 30 * 24 * 60 * 60;

    struct BoostNFT has key, store, drop {
        multiplier: u64,
        expiry: u64, // Timestamp in seconds, 0 for permanent boosts
        active: bool
    }

    struct BoostActivated has copy, drop {
        multiplier: u64,
        owner: address
    }

    public entry fun mint_3x_boost_nft(account: &signer, duration: u64) {
        let nft_obj = mint_3x_boost(account, duration);
        object::transfer(nft_obj, signer::address_of(account));
    }

    public entry fun mint_og_boost_nft(account: &signer, duration: u64) {
        let nft_obj = mint_og_boost(account);
        object::transfer(nft_obj, signer::address_of(account));
    }

    public entry fun mint_early_boost_nft(account: &signer, duration: u64) {
        let nft_obj = mint_early_boost(account);
        object::transfer(nft_obj, signer::address_of(account));
    }

    // Create a 3x boost NFT with specified duration
    public fun mint_3x_boost(account: &signer, duration: u64): Object<BoostNFT> {
        assert!(duration == SEVEN_DAYS || duration == THIRTY_DAYS, 0);

        let nft = BoostNFT {
            multiplier: BOOST_3X,
            expiry: timestamp::now_seconds() + duration,
            active: false
        };

        object::new_named_object(nft)
    }

    // Create an OG 2x boost NFT (permanent)
    public fun mint_og_boost(account: &signer): Object<BoostNFT> {
        let nft = BoostNFT { multiplier: BOOST_2X, expiry: 0, active: false };

        object::new_named_object(nft)
    }

    // Create an early participant 1.7x boost NFT (permanent)
    public fun mint_early_boost(account: &signer): Object<BoostNFT> {
        let nft = BoostNFT { multiplier: BOOST_1_7X, expiry: 0, active: false };
        object::new_named_object(nft)
    }

    // Activate a boost NFT
    public fun activate_boost(
        account: &signer, nft_obj: &mut Object<BoostNFT>
    ) {
        let nft = object::borrow_mut(nft_obj);

        // Check if boost is not expired for time-limited boosts
        if (nft.expiry != 0) {
            assert!(timestamp::now_seconds() < nft.expiry, EBoostExpired);
        };

        assert!(!nft.active, EBoostAlreadyActive);
        nft.active = true;

        event::emit(
            BoostActivated {
                multiplier: nft.multiplier,
                owner: signer::address_of(account)
            }
        );
    }

    public(friend) fun take_object_by_id(user: &signer, nft_obj: ObjectID): Object<BoostNFT> {
        object::take_object<BoostNFT>(user, nft_obj)
    }

    public(friend) fun remove_object(nft_obj: Object<BoostNFT>): BoostNFT {
        object::remove<BoostNFT>(nft_obj)
    }

    public(friend) fun new_object(nft_obj: BoostNFT): Object<BoostNFT> {
        object::new_named_object<BoostNFT>(nft_obj)
    }

    // Deactivate a boost NFT
    public fun deactivate_boost(account: &signer, nft: &mut BoostNFT) {
        nft.active = false;
    }

    // Get the current multiplier of a boost NFT
    public fun get_multiplier(nft: &BoostNFT): u256 {
        (nft.multiplier as u256)
    }

    // Check if a boost NFT is active
    public fun is_active(nft: &BoostNFT): bool {
        nft.active
    }

    // Check if a boost NFT has expired
    public fun is_expired(nft: &BoostNFT): bool {
        nft.expiry != 0 && timestamp::now_seconds() >= nft.expiry
    }

    // burn a boost NFT
    public fun burn_boost(account: &signer, nft: BoostNFT) {

        let BoostNFT { multiplier: _, expiry: _, active: _ } = nft;

        //TODO: lack event emit
    }

    #[test_only]
    public fun test_init_3x(user: &signer): Object<BoostNFT> {
        mint_3x_boost(user, SEVEN_DAYS)
    }

    #[test_only]
    public fun test_init_og_2x(user: &signer): Object<BoostNFT> {
        mint_og_boost(user)
    }

    #[test_only]
    public fun test_init_early_1_7x(user: &signer): Object<BoostNFT> {
        mint_early_boost(user)
    }
}
