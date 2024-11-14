module gold_miner::daily_check_in {
    use std::signer::address_of;
    use moveos_std::event;
    use moveos_std::object::{account_named_object_id, Object};
    use moveos_std::object;
    use moveos_std::timestamp::now_seconds;
    use rooch_framework::account_coin_store;
    use gold_miner::gold;

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

    public fun first_day_check_in(
        user: &mut signer, _treasury_obj: &mut Object<gold::Treasury>
    ) {
        let user_address = address_of(user);
        let object_id = account_named_object_id<CheckInRecord>(user_address);
        assert!(
            object::exists_object_with_type<CheckInRecord>(object_id),
            E_ALREADY_CHECKED_IN
        );

        //let treasury = object::borrow(treasury_obj);

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
        user: &mut signer,
        record: &mut Object<CheckInRecord>,
        treasury_obj: &mut Object<gold::Treasury>
    ) {
        let current_time = now_seconds();
        let today_start = current_time - (current_time % 86400000);

        let record = object::borrow_mut(record);

        assert!(record.last_check_in < today_start, E_ALREADY_CHECKED_IN);

        record.last_check_in = current_time;
        record.total_days = record.total_days + 1;

        let treasury = object::borrow_mut(treasury_obj);

        let amount = 100 * 1_000_000;
        let gold_mine = gold::mint(treasury, amount);
        account_coin_store::deposit(address_of(user), gold_mine);

        event::emit(
            CheckInEvent {
                user: address_of(user),
                timestamp: current_time,
                total_days: record.total_days
            }
        );

        if (record.total_days == 7) {
            //TODO: lack event emit
            let amount = 1000 * 1_000_000;
            let gold_mine = gold::mint(treasury, amount);
            account_coin_store::deposit(address_of(user), gold_mine);
        } else if (record.total_days == 30) {
            //TODO: lack event emit
            let amount = 10000 * 1_000_000;
            let gold_mine = gold::mint(treasury, amount);
            account_coin_store::deposit(address_of(user), gold_mine);
        }
    }

    #[view]
    public fun get_total_days(record: &CheckInRecord): u64 {
        record.total_days
    }
}
