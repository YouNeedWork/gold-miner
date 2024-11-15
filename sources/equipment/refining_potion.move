module gold_miner::refining_potion {
    use std::string::utf8;
    use std::vector;
    use moveos_std::object;
    use moveos_std::event;
    use moveos_std::object::Object;
    use moveos_std::display;

    friend gold_miner::gold_miner;

    /// The RefiningPotion NFT type
    struct RefiningPotion has key, store {}

    /// Event emitted when a new RefiningPotion is minted
    struct MintRefiningPotionEvent has copy, drop {}

    /// Event emitted when a RefiningPotion NFT is burned
    struct BurnRefiningPotionEvent has copy, drop {}

    /// One-time witness for the module
    struct REFINING_POTION has drop {}

    /// Initialize the module
    fun init() {
        let keys = vector[utf8(b"name"), utf8(b"description"), utf8(b"image_url")];

        let values = vector[
            utf8(b"Refining Potion"),
            utf8(b"A magical potion that enhances ore refining"),
            utf8(b"") // placeholder URL
        ];

        let dis = display::display<RefiningPotion>();
        let key_len = vector::length(&keys);
        while (key_len > 0) {
            let key = vector::pop_back(&mut keys);
            let value = vector::pop_back(&mut values);
            display::set_value(dis, key, value);
            key_len = key_len - 1;
        }
    }

    /// Create a new RefiningPotion NFT
    public(friend) fun mint(): Object<RefiningPotion> {
        let refining_potion = RefiningPotion {};

        event::emit(MintRefiningPotionEvent {});

        object::new_named_object(refining_potion)
    }

    /// Burns a RefiningPotion NFT, destroying it permanently
    public(friend) fun burn(refining_potion: Object<RefiningPotion>) {
        let RefiningPotion {} = object::remove(refining_potion);

        event::emit(BurnRefiningPotionEvent {});
    }
}
