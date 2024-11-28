module gold_miner::boost_nft {
    use std::signer;
    use std::string;
    use std::string::{String, utf8};
    use std::vector;
    use moveos_std::display;
    use rooch_framework::gas_coin::RGas;
    use rooch_framework::account_coin_store;
    use moveos_std::signer::address_of;
    use moveos_std::bcs;
    use moveos_std::hash;
    use gold_miner::merkle_proof;
    use moveos_std::account;
    use gold_miner::admin::AdminCap;

    use moveos_std::timestamp;
    use moveos_std::event;
    use moveos_std::object::{Self, Object, ObjectID};

    friend gold_miner::gold_miner;

    // Error codes
    const EBoostAlreadyActive: u64 = 100000;
    const EBoostExpired: u64 = 100001;
    const ENotAuthorized: u64 = 100002;
    const EERROR_INVALID_PROOF: u64 = 100003;

    // Boost multipliers bps
    const BOOST_3X: u64 = 30000; // 3.0x represented as basis points
    const BOOST_2_5X: u64 = 25000; // 2.5x for OG
    const BOOST_1_7X: u64 = 17000; // 1.7x for early participants

    // Time constants (in seconds)
    const SEVEN_DAYS: u64 = 7 * 24 * 60 * 60;
    const THIRTY_DAYS: u64 = 30 * 24 * 60 * 60;

    /// Config for boost NFT prices and merkle roots
    struct Config has key {
        /// Price for 7-day 3x boost NFT in gold tokens
        price_7_days: u256,
        /// Price for 30-day 3x boost NFT in gold tokens
        price_30_days: u256,
        /// Owner address of the project
        owner_address: address,
        /// 7days price total
        total_7_days: u256,
        /// 30days price total
        total_30_days: u256,
        /// Merkle root for OG boost NFT whitelist
        og_merkle_root: vector<u8>,
        /// Merkle root for early participant boost NFT whitelist
        early_merkle_root: vector<u8>
    }

    /// Event emitted when config is updated
    struct ConfigUpdated has copy, drop {
        price_7_days: u256,
        price_30_days: u256,
        owner_address: address,
        og_merkle_root: vector<u8>,
        early_merkle_root: vector<u8>
    }

    struct BoostNFT has key, store, drop {
        name: String,
        multiplier: u64,
        expiry: u64, // Timestamp in seconds, 0 for permanent boosts
        active: bool
    }

    struct BoostActivated has copy, drop {
        multiplier: u64,
        owner: address
    }

    /// Track user's minting counts
    struct UserMintRecord has key {
        og_minted: u64,
        early_minted: u64
    }

    /// User mint info for merkle proof verification
    struct UserMintInfo has drop {
        user: address,
        og_limit: u64,
        early_limit: u64
    }

    struct BoostMinted has copy, drop {
        multiplier: u64,
        expiry: u64,
        owner: address,
        price_paid: u256
    }

    struct BoostBurned has copy, drop {
        name: String,
        multiplier: u64,
        owner: address
    }

    struct PaymentProcessed has copy, drop {
        from: address,
        to: address,
        amount: u256
    }

    /// Initialize config with default values
    fun init(admin: &signer) {
        let config = Config {
            price_7_days: 10_000_000_000, // 100 Gas tokens
            price_30_days: 30_000_000_000, // 300 Gas tokens
            owner_address: address_of(admin),
            total_7_days: 0,
            total_30_days: 0,
            og_merkle_root: vector[],
            early_merkle_root: vector[]
        };
        account::move_resource_to(admin, config);

        let keys = vector[utf8(b"name"), utf8(b"description"), utf8(b"image_url")];

        let values = vector[
            utf8(b"{name}"),
            utf8(b"A NFT that boosts your mining rewards"),
            utf8(b"https://app.goldminer.life/nft/boost_{name}.png") // placeholder URL
        ];

        let dis = display::display<BoostNFT>();
        let key_len = vector::length(&keys);
        while (key_len > 0) {
            let key = vector::pop_back(&mut keys);
            let value = vector::pop_back(&mut values);
            display::set_value(dis, key, value);
            key_len = key_len - 1;
        }
    }

    /// update config
    public fun update_config(
        _: &mut Object<AdminCap>,
        price_7_days: u256,
        price_30_days: u256,
        owner_address: address,
        og_merkle_root: vector<u8>,
        early_merkle_root: vector<u8>
    ) {
        let config = account::borrow_mut_resource<Config>(@gold_miner);
        assert!(price_7_days > 0 && price_30_days > 0, 0);

        config.price_7_days = price_7_days;
        config.price_30_days = price_30_days;
        config.og_merkle_root = og_merkle_root;
        config.early_merkle_root = early_merkle_root;
        config.owner_address = owner_address;

        event::emit(
            ConfigUpdated {
                price_7_days,
                price_30_days,
                og_merkle_root,
                early_merkle_root,
                owner_address
            }
        );
    }

    // Initialize user mint record if not exists
    fun ensure_user_mint_record(user: &signer) {
        if (!account::exists_resource<UserMintRecord>(address_of(user))) {
            account::move_resource_to(
                user,
                UserMintRecord { og_minted: 0, early_minted: 0 }
            );
        }
    }

    // Create a 3x boost NFT with specified duration
    public entry fun mint_3x_boost(account: &signer, duration: u64) {
        assert!(duration == SEVEN_DAYS || duration == THIRTY_DAYS, 0);

        let config = account::borrow_mut_resource<Config>(@gold_miner);
        let price =
            if (duration == SEVEN_DAYS) {
                charge_gas_token(account, config.price_7_days);
                config.total_7_days = config.total_7_days + config.price_7_days;
                config.price_7_days
            } else {
                charge_gas_token(account, config.price_30_days);
                config.total_30_days = config.total_30_days + config.price_30_days;

                config.price_30_days
            };

        let nft = BoostNFT {
            name: string::utf8(b"Boost"),
            multiplier: BOOST_3X,
            expiry: timestamp::now_seconds() + duration,
            active: false
        };
        event::emit(
            BoostMinted {
                multiplier: BOOST_3X,
                expiry: timestamp::now_seconds() + duration,
                owner: address_of(account),
                price_paid: price
            }
        );

        object::transfer(object::new_named_object(nft), address_of(account));
    }

    // Create an OG 2x boost NFT (permanent)
    entry fun mint_og_boost(
        account: &signer, proof: vector<vector<u8>>, amount: u64
    ) {
        ensure_user_mint_record(account);
        let user_record =
            account::borrow_mut_resource<UserMintRecord>(address_of(account));

        // Check if user has reached their personal mint limit
        assert!(user_record.og_minted < amount, 0);

        let config = account::borrow_mut_resource<Config>(@gold_miner);

        let bytes_user = bcs::to_bytes(&address_of(account));
        vector::append(&mut bytes_user, bcs::to_bytes(&amount));
        assert!(
            merkle_proof::verify(
                &proof,
                config.og_merkle_root,
                hash::sha2_256(bytes_user)
            ),
            EERROR_INVALID_PROOF
        );

        let can_mint = amount - user_record.og_minted;

        let i = 0;
        while (i < can_mint) {
            event::emit(
                BoostMinted {
                    multiplier: BOOST_2_5X,
                    expiry: 0,
                    owner: address_of(account),
                    price_paid: config.price_7_days
                }
            );

            config.total_7_days = config.total_7_days + config.price_7_days;
            let nft = BoostNFT {
                name: string::utf8(b"OG"),
                multiplier: BOOST_2_5X,
                expiry: 0,
                active: false
            };
            object::transfer(object::new_named_object(nft), address_of(account));
            i = i + 1;
        };

        user_record.og_minted = amount;
    }

    // Create an early participant 1.7x boost NFT (permanent)
    public entry fun mint_early_boost(
        account: &signer, proof: vector<vector<u8>>, amount: u64
    ) {
        ensure_user_mint_record(account);
        let user_record =
            account::borrow_mut_resource<UserMintRecord>(address_of(account));

        // Check if user has reached their personal mint limit
        assert!(user_record.early_minted < amount, 0);

        let bytes_user = bcs::to_bytes(&address_of(account));
        vector::append(&mut bytes_user, bcs::to_bytes(&amount));
        let config = account::borrow_mut_resource<Config>(@gold_miner);
        assert!(
            merkle_proof::verify(
                &proof,
                config.early_merkle_root,
                bytes_user
            ),
            EERROR_INVALID_PROOF
        );

        let can_mint = amount - user_record.og_minted;
        let i = 0;

        while (i < can_mint) {
            event::emit(
                BoostMinted {
                    multiplier: BOOST_1_7X,
                    expiry: 0,
                    owner: address_of(account),
                    price_paid: config.price_7_days
                }
            );

            let nft = BoostNFT {
                name: string::utf8(b"Early"),
                multiplier: BOOST_1_7X,
                expiry: 0,
                active: false
            };

            config.total_7_days = config.total_7_days + config.price_7_days;
            object::transfer(object::new_named_object(nft), address_of(account));
            i = i + 1;
        };

        user_record.early_minted = user_record.early_minted + amount;
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

    // internal
    fun charge_gas_token(account: &signer, amount: u256) {
        let config = account::borrow_resource<Config>(@gold_miner);
        account_coin_store::transfer<RGas>(account, config.owner_address, amount);
        event::emit(
            PaymentProcessed { from: address_of(account), to: config.owner_address, amount }
        );
    }

    //views
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
    public fun deactivate_boost(nft: &mut BoostNFT) {
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
    public fun burn_boost(nft: BoostNFT, owner: address) {
        let BoostNFT { name, multiplier, expiry: _, active: _ } = nft;

        event::emit(
            BoostBurned { name, multiplier, owner }
        );
    }

    #[test_only]
    public fun test_init_3x(user: &signer): Object<BoostNFT> {
        let nft = BoostNFT {
            name: string::utf8(b"Boost"),
            multiplier: BOOST_3X,
            expiry: timestamp::now_seconds() + SEVEN_DAYS,
            active: false
        };

        object::new_named_object(nft)
    }

    #[test_only]
    public fun test_init_og_2x(user: &signer): Object<BoostNFT> {
        let nft = BoostNFT {
            name: string::utf8(b"Boost"),
            multiplier: BOOST_2_5X,
            expiry: 0,
            active: false
        };
        object::new_named_object(nft)
    }

    #[test_only]
    public fun test_init_early_1_7x(user: &signer): Object<BoostNFT> {
        let nft = BoostNFT {
            name: string::utf8(b"Boost"),
            multiplier: BOOST_1_7X,
            expiry: 0,
            active: false
        };
        object::new_named_object(nft)
    }

    // Add view functions to check user's mint counts
    public fun get_user_mint_counts(user_addr: address): (u64, u64) {
        if (!account::exists_resource<UserMintRecord>(user_addr)) {
            return (0, 0)
        };
        let record = account::borrow_resource<UserMintRecord>(user_addr);
        (record.og_minted, record.early_minted)
    }

    #[test_only]
    public fun test_init(user: &signer) {
        init(user);
    }
}
