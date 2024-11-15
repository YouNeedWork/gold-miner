module gold_miner::gold_ore {
    use std::string::utf8;
    use std::vector;
    use moveos_std::object;
    use moveos_std::event;
    use moveos_std::object::Object;
    use moveos_std::display;

    friend gold_miner::gold_miner;

    /// The GoldOre NFT type
    struct GoldOre has key, store {
        rarity: u8 // 1-5 representing common to legendary
    }

    /// Event emitted when a new GoldOre is minted
    struct MintGoldOreEvent has copy, drop {
        rarity: u8
    }

    /// Event emitted when a GoldOre NFT is burned
    struct BurnGoldOreEvent has copy, drop {
        rarity: u8
    }

    /// One-time witness for the module
    struct GOLD_ORE has drop {}

    /// Initialize the module
    fun init() {
        let keys = vector[utf8(b"name"), utf8(b"description"), utf8(b"image_url")];

        let values = vector[
            utf8(b"Gold Ore {rarity}"),
            utf8(b"A mystical ore that boosts gold mining efficiency"),
            utf8(b"") // placeholder URL
        ];

        let dis = display::display<GoldOre>();
        let key_len = vector::length(&keys);
        while (key_len > 0) {
            let key = vector::pop_back(&mut keys);
            let value = vector::pop_back(&mut values);
            display::set_value(dis, key, value);
            key_len = key_len - 1;
        }
    }

    /// Create a new GoldOre NFT
    public(friend) fun mint(rarity: u8): Object<GoldOre> {
        assert!(rarity >= 1 && rarity <= 5, 0); // Invalid rarity

        let gold_ore = GoldOre { rarity };

        event::emit(MintGoldOreEvent { rarity });

        object::new_named_object(gold_ore)
    }

    /// Burns a GoldOre NFT, destroying it permanently
    public(friend) fun burn(gold_ore: Object<GoldOre>) {
        let GoldOre { rarity } = object::remove(gold_ore);

        event::emit(BurnGoldOreEvent { rarity });
    }
}
