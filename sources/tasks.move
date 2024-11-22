module gold_miner::tasks {
    use std::bcs;
    use std::signer::address_of;
    use std::vector;
    use moveos_std::event::emit;
    use gold_miner::admin::AdminCap;
    use moveos_std::hash;
    use rooch_framework::ecdsa_k1;
    use moveos_std::event;
    use moveos_std::object::{Self, Object};
    use moveos_std::account;
    use gold_miner::gold::{Self};
    use rooch_framework::account_coin_store;

    /// Error codes
    const EERROR_INVALID_SIGNATURE: u64 = 300001;
    const EERROR_TASK_ALREADY_CLAIMED: u64 = 300002;
    const EERROR_TENANT_NOT_REGISTERED: u64 = 300003;
    const EERROR_NOT_AUTHORIZED: u64 = 300004;

    /// Tenant configuration
    struct Config has key, store {
        /// Tenant specific oracle address
        oracle_address: vector<u8>
    }

    /// Task record for a specific user under a specific tenant
    struct TaskRecord has key {
        completed_tasks: vector<u64>
    }

    /// Event emitted when a task is completed
    struct TaskCompletedEvent has copy, drop {
        player: address,
        task_id: u64,
        reward: u256
    }

    struct OracleAddressChangedEvent has copy, drop {
        oracle_address: vector<u8>
    }

    /// Initialize the task config
    fun init(admin: &signer) {
        let config = Config { oracle_address: bcs::to_bytes(admin) };

        account::move_resource_to(admin, config);
    }

    /// change the oracle address
    public entry fun change_oracle_address(
        _: &mut Object<AdminCap>, oracle_address: vector<u8>
    ) {
        let config = account::borrow_mut_resource<Config>(@gold_miner);
        config.oracle_address = oracle_address;

        emit(OracleAddressChangedEvent { oracle_address });
    }

    /// Claim reward for completing a task
    public entry fun claim_task_reward(
        user: &signer,
        task_id: u64,
        reward: u256,
        signature: vector<u8>
    ) {
        // Verify tenant exists and is active
        let config = account::borrow_resource<Config>(@gold_miner);
        let player_address = address_of(user);

        // Verify task record exists and task hasn't been claimed
        let task_record = account::borrow_mut_resource<TaskRecord>(player_address);
        assert!(
            !vector::contains(&task_record.completed_tasks, &task_id),
            EERROR_TASK_ALREADY_CLAIMED
        );

        // Verify signature from tenant's oracle
        assert!(
            verify_signature(
                player_address,
                config.oracle_address,
                task_id,
                reward,
                signature
            ),
            EERROR_INVALID_SIGNATURE
        );

        // Mark task as completed
        vector::push_back(&mut task_record.completed_tasks, task_id);

        // Mint and transfer reward
        let treasury_obj = gold::get_treasury();
        let treasury = object::borrow_mut(treasury_obj);
        let reward_coins = gold::mint(treasury, reward);
        account_coin_store::deposit(player_address, reward_coins);

        // Emit completion event
        event::emit(TaskCompletedEvent { player: player_address, task_id, reward });
    }

    #[view]
    /// View function to check if a task has been completed
    public fun is_task_completed(player: address, task_id: u64): bool {
        let task_record = account::borrow_resource<TaskRecord>(player);
        vector::contains(&task_record.completed_tasks, &task_id)
    }

    /// Internal function to verify oracle signature
    fun verify_signature(
        user: address,
        oracle: vector<u8>,
        task_id: u64,
        reward: u256,
        signature: vector<u8>
    ): bool {
        let sign_bytes = bcs::to_bytes(&user);
        vector::append(&mut sign_bytes, bcs::to_bytes(&task_id));
        vector::append(&mut sign_bytes, bcs::to_bytes(&reward));

        oracle == ecrecover_to_address(signature, sign_bytes)
    }

    fun ecrecover_to_address(signature: vector<u8>, msg: vector<u8>): vector<u8> {
        // Normalize the last byte of the signature to be 0 or 1.
        let v = vector::borrow_mut(&mut signature, 64);
        if (*v == 27) {
            *v = 0;
        } else if (*v == 28) {
            *v = 1;
        } else if (*v > 35) {
            *v = (*v - 1) % 2;
        };

        // Ethereum signature is produced with Keccak256 hash of the message, so the last param is 0.
        let pubkey = ecdsa_k1::ecrecover(&signature, &msg, 0);
        let uncompressed = ecdsa_k1::decompress_pubkey(&pubkey);

        // Take the last 64 bytes of the uncompressed pubkey.
        let uncompressed_64 = vector::empty<u8>();
        let i = 1;
        while (i < 65) {
            let value = vector::borrow(&uncompressed, i);
            vector::push_back(&mut uncompressed_64, *value);
            i = i + 1;
        };

        // Take the last 20 bytes of the hash of the 64-bytes uncompressed pubkey.
        let hashed = hash::keccak256(&uncompressed_64);
        let addr_bytes = vector::empty<u8>();
        let i = 0;
        while (i < 32) {
            if (i > 11) {
                let value = vector::borrow(&hashed, i);
                vector::push_back(&mut addr_bytes, *value);
            };
            i = i + 1;
        };

        addr_bytes
    }

    #[test]
    fun test_ecrecover_to_address() {
        let msg = b"Hello";
        let signature =
            x"cee56d70230696268e77b9b21eed4a455f3b6cc67cd30f33739d16226c996169282f0296ccb6bbf06b517f649abf7a7a12d08cef85ef282890f1d445b8e7c16f00";
        let addr = ecrecover_to_address(signature, msg);
        assert!(addr == x"105d8b0c9a03f506f85796789561142cf335280e", 1);
    }
}
