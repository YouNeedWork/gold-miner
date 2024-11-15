module gold_miner::stamina_potion {
    use std::string::utf8;
    use std::vector;
    use moveos_std::object;
    use moveos_std::event;
    use moveos_std::object::Object;
    use moveos_std::display;

    friend gold_miner::gold_miner;

    /// The StaminaPotion NFT type
    struct StaminaPotion has key, store {}

    /// Event emitted when a new StaminaPotion is minted
    struct MintStaminaPotionEvent has copy, drop {}

    /// Event emitted when a StaminaPotion NFT is burned
    struct BurnStaminaPotionEvent has copy, drop {}

    /// One-time witness for the module
    struct STAMINA_POTION has drop {}

    /// Initialize the module
    fun init() {
        let keys = vector[utf8(b"name"), utf8(b"description"), utf8(b"image_url")];

        let values = vector[
            utf8(b"Stamina Potion"),
            utf8(b"A magical potion that restores mining stamina"),
            utf8(b"") // placeholder URL
        ];

        let dis = display::display<StaminaPotion>();
        let key_len = vector::length(&keys);
        while (key_len > 0) {
            let key = vector::pop_back(&mut keys);
            let value = vector::pop_back(&mut values);
            display::set_value(dis, key, value);
            key_len = key_len - 1;
        }
    }

    /// Create a new StaminaPotion NFT
    public(friend) fun mint(): Object<StaminaPotion> {
        let stamina_potion = StaminaPotion {};

        event::emit(MintStaminaPotionEvent {});

        object::new_named_object(stamina_potion)
    }

    /// Burns a StaminaPotion NFT, destroying it permanently
    public(friend) fun burn(stamina_potion: Object<StaminaPotion>) {
        let StaminaPotion {} = object::remove(stamina_potion);

        event::emit(BurnStaminaPotionEvent {});
    }
}
