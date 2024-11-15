module gold_miner::silver_ore {
    use std::string::utf8;
    use std::vector;
    use moveos_std::object;
    use moveos_std::event;
    use moveos_std::object::Object;
    use moveos_std::display;

    friend gold_miner::gold_miner;



    /// The SilverOre NFT type
    struct SilverOre has key, store {
        rarity: u8,  // 1-5 representing common to legendary
    }

    /// Event emitted when a new SilverOre is minted
    struct MintSilverOreEvent has copy, drop {
        rarity: u8,
    }

    /// Event emitted when a SilverOre NFT is burned
    struct BurnSilverOreEvent has copy, drop {
        rarity: u8
    }

    /// One-time witness for the module
    struct SILVER_ORE has drop {}

    /// Initialize the module
    fun init() {
        let keys = vector[
            utf8(b"name"),
            utf8(b"description"),
            utf8(b"image_url"),
        ];
        
        let values = vector[
            utf8(b"Silver Ore {rarity}"),
            utf8(b"A valuable ore that provides enhanced mining bonuses"),
            utf8(b""), // placeholder URL
        ];

        let dis = display::display<SilverOre>();
        let key_len = vector::length(&keys);
        while (key_len > 0) {
            let key = vector::pop_back(&mut keys);
            let value = vector::pop_back(&mut values);
            display::set_value(dis, key, value);
            key_len = key_len - 1;
        }
    }

    /// Create a new SilverOre NFT
    public(friend) fun mint(
        rarity: u8,
    ): Object<SilverOre> {
        assert!(rarity >= 1 && rarity <= 5, 0); // Invalid rarity
        
        let silver_ore = SilverOre {
            rarity,
        };

        event::emit(MintSilverOreEvent {
            rarity,
        });

        object::new_named_object(silver_ore)
    }

    /// Burns a SilverOre NFT, destroying it permanently
    public(friend) fun burn(silver_ore: Object<SilverOre>) {
        let SilverOre {
            rarity,
        } = object::remove(silver_ore);

        event::emit(BurnSilverOreEvent {
            rarity
        });
    }
}
