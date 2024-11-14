module grow_bitcoin::grow_bitcoin {
    use std::string::String;
    use moveos_std::object::ObjectID;
    use moveos_std::table::Table;
    use moveos_std::account;

    /// To store user's asset token
    struct Stake has key, store {
        asset_type: String,
        asset_weight: u64,
        last_harvest_index: u128,
        gain: u128
    }

    struct UserStake has key {
        /// utxo ==> stake
        stake: Table<ObjectID, Stake>
    }

    public fun exists_stake_at_address(account: address): bool {
        account::exists_resource<UserStake>(account)
    }
}
