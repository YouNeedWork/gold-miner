module gold_miner::admin {
    use std::signer::address_of;
    use moveos_std::object;
    #[test_only]
    use moveos_std::object::Object;

    struct AdminCap has key, store {}

    fun init(user: &signer) {
        object::transfer(object::new_named_object(AdminCap {}), address_of(user));
    }

    #[test_only]
    public fun test_create(): Object<AdminCap> {
        object::new_named_object(AdminCap {})
    }
}
