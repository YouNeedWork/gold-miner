module gold_miner::hamburger {
    use std::string::utf8;
    use std::vector;
    use moveos_std::object;
    use moveos_std::event;
    use moveos_std::object::Object;
    use moveos_std::display;
    #[test_only]
    use std::signer::address_of;

    friend gold_miner::gold_miner;

    /// The Hambuger NFT type
    struct Hambuger has key, store {}

    /// Event emitted when a new Hambuger is minted
    struct MintHambugerEvent has copy, drop {
        user: address
    }

    /// Event emitted when a Hambuger NFT is burned
    struct BurnHambugerEvent has copy, drop {
        user: address
    }

    /// Initialize the module
    fun init() {
        let keys = vector[utf8(b"name"), utf8(b"description"), utf8(b"image_url")];

        let values = vector[
            utf8(b"Hambuger"),
            utf8(b"A magical hambuger that restores health"),
            utf8(b"https://app.goldminer.life/nft/hambuger.png") // placeholder URL
        ];

        let dis = display::display<Hambuger>();
        let key_len = vector::length(&keys);
        while (key_len > 0) {
            let key = vector::pop_back(&mut keys);
            let value = vector::pop_back(&mut values);
            display::set_value(dis, key, value);
            key_len = key_len - 1;
        }
    }

    /// Create a new Hambuger NFT
    public(friend) fun mint(user: &address): Object<Hambuger> {
        let hambuger = Hambuger {};

        event::emit(MintHambugerEvent { user: *user });
        object::new_named_object(hambuger)
    }

    /// Burns a Hambuger NFT, destroying it permanently
    public(friend) fun burn(user: &address, hambuger: Object<Hambuger>) {
        let Hambuger {} = object::remove(hambuger);
        event::emit(BurnHambugerEvent { user: *user });
    }

    #[test_only]
    public fun test_mint(user: &signer): Object<Hambuger> {
        mint(&address_of(user))
    }
}
