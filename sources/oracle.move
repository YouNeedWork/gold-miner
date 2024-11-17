module gold_miner::oracle {
    use std::signer::address_of;
    use moveos_std::event::emit;
    use gold_miner::admin::AdminCap;
    use moveos_std::object::Object;
    use moveos_std::account;

    /// Error codes
    const EERROR_NOT_AUTHORIZED: u64 = 200001;

    /// Oracle configuration
    struct OracleConfig has key {
        /// The oracle address that can update prices
        oracle_address: address
    }

    struct OracleAddressUpdated has copy, drop {
        old_oracle: address,
        new_oracle: address
    }

    /// Initialize the oracle module
    fun init(deployer: &signer) {
        let config = OracleConfig { oracle_address: address_of(deployer) };
        account::move_resource_to(deployer, config);
    }

    /// Get the oracle address
    #[view]
    public fun get_oracle_address(): address {
        let config = account::borrow_resource<OracleConfig>(@gold_miner);
        config.oracle_address
    }

    /// Update the oracle address. Only the current oracle can update.
    public fun update_oracle_address(
        user: &signer, _: &Object<AdminCap>, new_oracle: address
    ) {
        let config = account::borrow_mut_resource<OracleConfig>(@gold_miner);
        let old_oracle = config.oracle_address;
        config.oracle_address = new_oracle;
        emit(OracleAddressUpdated { old_oracle, new_oracle });
    }
}
