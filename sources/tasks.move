module gold_miner::tasks {
    /*
    use std::signer::address_of;
    use moveos_std::object::Object;

    use gold_miner::gold_miner::{Self};
    use gold_miner::auto_miner::{Self};
    use gold_miner::gold;

    struct HarvestEvent has copy, drop {
        player: address,
        amount: u256,
        auto_miner: bool,
        stake: bool
    }

    /// With auto miner, hunger is not consumed
    public fun auto_mine_harvest(
        user: &signer
    ) {
        let harvest_amount = auto_miner::get_harvest_amount(auto_miner_obj);
        let harvest_amount =
            gold_miner::mine_internal(
                user,
                treasury_obj,
                miner_obj,
                (harvest_amount as u256)
            );

        moveos_std::event::emit(
            HarvestEvent {
                player: address_of(user),
                amount: harvest_amount,
                auto_miner: true,
                stake: false
            }
        );
    }
    */
}
