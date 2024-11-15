module gold_miner::iron_ore {
    use std::string::utf8;
    use std::vector;
    use moveos_std::object;
    use moveos_std::event;
    use moveos_std::object::Object;
    use moveos_std::display;


    friend gold_miner::gold_miner;

    /// The IronOre NFT type
    struct IronOre has key, store {
        rarity: u8,  // 1-5 representing common to legendary
    }

    /// Event emitted when a new IronOre is minted
    struct MintIronOreEvent has copy, drop {
        rarity: u8,
    }

    /// Event emitted when a IronOre NFT is burned
    struct BurnIronOreEvent has copy, drop {
        rarity: u8
    }

    /// One-time witness for the module
    struct IRON_ORE has drop {}

    /// Initialize the module
    fun init() {
        let keys = vector[
            utf8(b"name"),
            utf8(b"description"), 
            utf8(b"image_url"),
        ];
        
        let values = vector[
            utf8(b"Iron Ore {rarity}"),
            utf8(b"A common ore that provides basic mining bonuses"),
            utf8(b""), // placeholder URL
        ];

        let dis = display::display<IronOre>();
        let key_len = vector::length(&keys);
        while (key_len > 0) {
            let key = vector::pop_back(&mut keys);
            let value = vector::pop_back(&mut values);
            display::set_value(dis, key, value);
            key_len = key_len - 1;
        }
    }

    /// Create a new IronOre NFT
    public(friend) fun mint(
        rarity: u8,
    ): Object<IronOre> {
        assert!(rarity >= 1 && rarity <= 5, 0); // Invalid rarity
        
        let iron_ore = IronOre {
            rarity,
        };

        event::emit(MintIronOreEvent {
            rarity,
        });

        object::new_named_object(iron_ore)
    }

    /// Burns a IronOre NFT, destroying it permanently
    public(friend) fun burn(iron_ore: Object<IronOre>) {
        let IronOre {
            rarity,
        } = object::remove(iron_ore);

        event::emit(BurnIronOreEvent {
            rarity
        });
    }
}
