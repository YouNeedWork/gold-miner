module gold_miner::harvest {
    use std::signer::address_of;
    use moveos_std::object::Object;
    use bitcoin_move::bbn;

    use gold_miner::gold_miner::{Self, MineInfo};
    use gold_miner::auto_miner::{Self, AutoMiner};
    use gold_miner::gold;

    struct HarvestEvent has copy, drop {
        player: address,
        amount: u256,
        auto_miner: bool,
        bbn_stake: bool
    }

    /// With auto miner, hunger is not consumed
    public fun auto_mine_harvest(
        user: &signer,
        treasury_obj: &mut Object<gold::Treasury>,
        miner_obj: &mut Object<gold_miner::MineInfo>,
        auto_miner_obj: &mut Object<auto_miner::AutoMiner>
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
                bbn_stake: false
            }
        );
    }

    /// With auto miner, hunger is not consumed
    public fun auto_mine_harvest_bbn(
        user: &signer,
        treasury_obj: &mut Object<gold::Treasury>,
        miner_obj: &mut Object<MineInfo>,
        bbn_obj: &Object<bbn::BBNStakeSeal>,
        auto_miner_obj: &mut Object<auto_miner::AutoMiner>
    ) {
        let harvest_amount = auto_miner::get_harvest_amount(auto_miner_obj);

        let harvest_amount =
            gold_miner::mine_internal_bbn(
                user,
                treasury_obj,
                miner_obj,
                bbn_obj,
                (harvest_amount as u256)
            );

        moveos_std::event::emit(
            HarvestEvent {
                player: address_of(user),
                amount: harvest_amount,
                auto_miner: true,
                bbn_stake: true
            }
        );
    }
}
