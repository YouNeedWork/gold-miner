module gold_miner::gold {
    use std::string;
    use std::option;
    use moveos_std::object::{Self, Object};
    use rooch_framework::coin::{Self, CoinInfo, Coin};

    friend gold_miner::gold_miner;

    const TOTAL_SUPPLY: u256 =
        115792089237316195423570985008687907853269984665640564039457584007913129639935;
    const DECIMALS: u8 = 6u8;

    struct Gold has key, store {}

    struct Treasury has key {
        coin_info: Object<CoinInfo<Gold>>
    }

    fun init() {
        let coin_info_obj =
            coin::register_extend<Gold>(
                string::utf8(b"Rooch Gold Miner Game"),
                string::utf8(b"Gold"),
                option::none(),
                DECIMALS
            );

        let treasury_obj = object::new_named_object(Treasury { coin_info: coin_info_obj });
        object::to_shared(treasury_obj);
    }

    public(friend) fun mint(treasury: &mut Treasury, amount: u256): Coin<Gold> {
        coin::mint(&mut treasury.coin_info, amount)
    }

    public(friend) fun burn(treasury: &mut Treasury, c: Coin<Gold>) {
        coin::burn(&mut treasury.coin_info, c)
    }
}
