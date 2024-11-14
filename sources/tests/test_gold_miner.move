#[test_only]
module gold_miner::test_gold_miner {
    use rooch_framework::chain_id;

    #[test]
    fun test_get_chain_id() {
        rooch_framework::genesis::init_for_test();
        let _id = chain_id::chain_id();
    }
}
