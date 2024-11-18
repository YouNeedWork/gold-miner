module gold_miner::tasks {
    use std::signer::address_of;
    use std::vector;
    use moveos_std::event;
    use moveos_std::object::{Self};
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
        oracle_address: address
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

    /// Initialize the task config
    fun init(admin: &signer) {
        let config = Config { oracle_address: address_of(admin) };

        account::move_resource_to(admin, config);
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
                config.oracle_address,
                player_address,
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

    /// View function to check if a task has been completed
    #[view]
    public fun is_task_completed(player: address, task_id: u64): bool {
        let task_record = account::borrow_resource<TaskRecord>(player);
        vector::contains(&task_record.completed_tasks, &task_id)
    }

    /// Internal function to verify oracle signature
    fun verify_signature(
        oracle: address,
        tenant: address,
        task_id: u64,
        reward: u256,
        signature: vector<u8>
    ): bool {
        //TODO: Implement signature verification
        true
    }
}
