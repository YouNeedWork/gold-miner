module gold_miner::copper_ore {
    use std::string::utf8;
    use std::vector;
    use moveos_std::object;
    use moveos_std::event;
    use moveos_std::object::Object;
    use moveos_std::display;

    friend gold_miner::gold_miner;

    /// The CopperOre NFT type
    struct CopperOre has key, store {
        rarity: u8 // 1-5 representing common to legendary
    }

    /// Event emitted when a new CopperOre is minted
    struct MintCopperOreEvent has copy, drop {
        rarity: u8
    }

    /// Event emitted when a CopperOre NFT is burned
    struct BurnCopperOreEvent has copy, drop {
        rarity: u8
    }

    /// One-time witness for the module
    struct COPPER_ORE has drop {}

    /// Initialize the module
    fun init() {
        let keys = vector[utf8(b"name"), utf8(b"description"), utf8(b"image_url")];

        let values = vector[
            utf8(b"Copper Ore {rarity}"),
            utf8(b"A basic ore that provides modest mining bonuses"),
            utf8(b"") // placeholder URL
        ];

        let dis = display::display<CopperOre>();
        let key_len = vector::length(&keys);
        while (key_len > 0) {
            let key = vector::pop_back(&mut keys);
            let value = vector::pop_back(&mut values);
            display::set_value(dis, key, value);
            key_len = key_len - 1;
        }
    }

    /// Create a new CopperOre NFT
    public(friend) fun mint(rarity: u8): Object<CopperOre> {
        assert!(rarity >= 1 && rarity <= 5, 0); // Invalid rarity

        let copper_ore = CopperOre { rarity };

        event::emit(MintCopperOreEvent { rarity });

        object::new_named_object(copper_ore)
    }

    /// Burns a CopperOre NFT, destroying it permanently
    public(friend) fun burn(copper_ore: Object<CopperOre>) {
        let CopperOre { rarity } = object::remove(copper_ore);

        event::emit(BurnCopperOreEvent { rarity });
    }
}
