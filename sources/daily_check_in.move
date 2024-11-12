module gold_miner::daily_check_in {

    use std::signer::address_of;
    use moveos_std::event;
    use moveos_std::object::{account_named_object_id, ObjectID, Object};
    use moveos_std::object;
    use moveos_std::timestamp::now_seconds;

    const E_ALREADY_CHECKED_IN: u64 = 1;
    const E_NOT_ENOUGH_DAYS: u64 = 2;

    struct CheckInRecord has key {
        owner: address,
        last_check_in: u64,
        total_days: u64
    }

    struct CheckInEvent has copy, drop {
        user: address,
        timestamp: u64,
        total_days: u64
    }

    public fun first_day_check_in(user: &mut signer) {
        let user_address = address_of(user);
        let object_id = account_named_object_id<CheckInRecord>(user_address);
        assert!(
            object::exists_object_with_type<CheckInRecord>(object_id), E_ALREADY_CHECKED_IN
        );

        let record = CheckInRecord {
            owner: address_of(user),
            last_check_in: now_seconds(),
            total_days: 1
        };

        event::emit(
            CheckInEvent {
                user: address_of(user),
                timestamp: now_seconds(),
                total_days: record.total_days
            }
        );

        object::transfer_extend(object::new_named_object(record), address_of(user));
    }

    public fun check_in(
        user: &mut signer, record: &mut Object<CheckInRecord>
    ) {
        let current_time = now_seconds();
        let today_start = current_time - (current_time % 86400000);

        let record = object::borrow_mut(record);

        assert!(record.last_check_in < today_start, E_ALREADY_CHECKED_IN);

        record.last_check_in = current_time;
        record.total_days = record.total_days + 1;

        event::emit(
            CheckInEvent {
                user: address_of(user),
                timestamp: current_time,
                total_days: record.total_days
            }
        );

        if (record.total_days == 7) {
        } else if (record.total_days == 30) {}
    }

    #[view]
    public fun get_total_days(record: &CheckInRecord): u64 {
        record.total_days
    }
}
