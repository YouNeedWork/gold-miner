module gold_miner::boost_nft {
    use std::signer;

    use moveos_std::timestamp;
    use moveos_std::event;
    use moveos_std::object::{Self, Object, ObjectID};

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

    struct BoostNFT has key, store {
        owner: address,
        multiplier: u64,
        expiry: u64, // Timestamp in seconds, 0 for permanent boosts
        active: bool
    }

    struct BoostActivated has copy, drop {
        multiplier: u64,
        owner: address
    }

    // Create a 3x boost NFT with specified duration
    public fun mint_3x_boost(account: &signer, duration: u64) {
        assert!(duration == SEVEN_DAYS || duration == THIRTY_DAYS, 0);

        let nft = BoostNFT {
            owner: signer::address_of(account),
            multiplier: BOOST_3X,
            expiry: timestamp::now_seconds() + duration,
            active: false
        };

        let nft_obj = object::new(nft);
        object::transfer(nft_obj, signer::address_of(account));
    }

    // Create an OG 2x boost NFT (permanent)
    public fun mint_og_boost(account: &signer) {
        let nft = BoostNFT {
            owner: signer::address_of(account),
            multiplier: BOOST_2X,
            expiry: 0,
            active: false
        };
        let nft_obj = object::new(nft);
        object::transfer(nft_obj, signer::address_of(account));
    }

    // Create an early participant 1.7x boost NFT (permanent)
    public fun mint_early_boost(account: &signer) {
        let nft = BoostNFT {
            owner: signer::address_of(account),
            multiplier: BOOST_1_7X,
            expiry: 0,
            active: false
        };
        let nft_obj = object::new(nft);
        object::transfer(nft_obj, signer::address_of(account));
    }

    // Activate a boost NFT
    public fun activate_boost(
        account: &signer, nft_obj: &mut Object<BoostNFT>
    ) {
        let nft = object::borrow_mut(nft_obj);

        // Verify ownership
        assert!(nft.owner == signer::address_of(account), ENotAuthorized);

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

    // Deactivate a boost NFT
    public fun deactivate_boost(
        account: &signer, nft_obj: &mut Object<BoostNFT>
    ) {
        let nft = object::borrow_mut(nft_obj);
        assert!(nft.owner == signer::address_of(account), ENotAuthorized);
        nft.active = false;
    }

    // Get the current multiplier of a boost NFT
    public fun get_multiplier(nft_obj: &Object<BoostNFT>): u256 {
        let nft = object::borrow(nft_obj);
        (nft.multiplier as u256)
    }

    // Check if a boost NFT is active
    public fun is_active(nft_obj: &Object<BoostNFT>): bool {
        let nft = object::borrow(nft_obj);
        nft.active
    }

    // Check if a boost NFT has expired
    public fun is_expired(nft_obj: &Object<BoostNFT>): bool {
        let nft = object::borrow<BoostNFT>(nft_obj);
        nft.expiry != 0 && timestamp::now_seconds() >= nft.expiry
    }

    // burn a boost NFT
    public fun burn_boost(account: &signer, obj_id: ObjectID) {
        let obj = object::take_object<BoostNFT>(account,obj_id);
        //assert!(is_expired(&obj), EBoostExpired);

        let BoostNFT{
            owner: _,
            multiplier: _,
            expiry: _,
            active: _
        } =  object::remove(obj);

        //TODO: lack event emit
    }
}
