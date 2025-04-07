#[test_only]
module gold_miner::merkle_proof_tests {
    use std::vector;
    // Assuming you have a merkle_proof module with these functions
    use gold_miner::merkle_proof;
    use moveos_std::bcs;
    use moveos_std::signer::address_of;
    use std::debug::print;
    use moveos_std::hash;


    #[test(user = @0x42)]
    fun test_verify(user: &signer) {
        let proof = vector::empty<vector<u8>>();
        vector::push_back(&mut proof, x"3e23e8160039594a33894f6564e1b1348bbd7a0088d42c4acb73eeaed59c009d");
        vector::push_back(&mut proof, x"2e7d2c03a9507ae265ecf5b5356885a53393a2029d241394997265a1a25aefc6");
        let root = x"aea2dd4249dcecf97ca6a1556db7f21ebd6a40bbec0243ca61b717146a08c347";
        let leaf = x"ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb";
        assert!(merkle_proof::verify(&proof, root, leaf), 0);
    }

    #[test(user = @0x42)]
    fun test_verify_real(user: &signer) {
        let proof = vector::empty<vector<u8>>();
        vector::push_back(&mut proof, x"cf8354bf04c015f36aed7382460e3cece2beadf6e707a199c84b4b48eb29a12c");
        vector::push_back(&mut proof, x"057986bfe4d24fdbe628e0deb49a527972e861fb0865553f004b74a13825f615");
        vector::push_back(&mut proof, x"fb87673e6a1f60e056cf08f12b2c7dc8bbdd42dc5a1a220d4aec206694c63592");
        vector::push_back(&mut proof, x"2e1f5ce99f9b89bd64a5ee11521c211d58a02e4585b454ecbf4710311613fab4");
        vector::push_back(&mut proof, x"d4cfe5789c8d7a180b737a6b9bc9cf09d713b82f275fd3df4c49e5752e85aee3");
        vector::push_back(&mut proof, x"15af7c049779b2b1f0ae6551ac6d0da7d5fe0022f0cb4e3aeba34a71850eb227");
        vector::push_back(&mut proof, x"ba3c4e4f78c4c1e41e0f3bbad27d8a8f606049eaf058917ea553c608522e9f7d");
        vector::push_back(&mut proof, x"60358a8c4d466fe4d2ff045e238e2cb38213b0b81763e324785aeda177ea3f23");
        vector::push_back(&mut proof, x"613db4c5bfd83baa89b8b9bd42d08913bea847111a82545e47ff46de68d40fff");
        vector::push_back(&mut proof, x"dc326b9037d10983af7b69eea027737546b1b2da240be56735e684f090b9a22a");

        let root = x"3fab0795e4cc4501767cb7da2f7709fc219c495cd8df6dc29c1245ebd16bc47f";

        let address = @0x6a0525362f8b922d6ef962f23b915984c5888df38f99fa9678fcd22ac959d7b1;
        let bytes_user = bcs::to_bytes(&address);
        let amount:u64 = 1;
        vector::append(&mut bytes_user, bcs::to_bytes(&amount));
        let leaf = hash::sha2_256(bytes_user);
        assert!(merkle_proof::verify(&proof, root, leaf), 0);
    }

    #[test]
    fun test_verify_bad_proof() {
        let proof = vector::empty<vector<u8>>();
        vector::push_back(&mut proof, x"3e23e8160039594a33894f6564e1b1349bbd7a0088d42c4acb73eeaed59c009d");
        vector::push_back(&mut proof, x"2e7d2c03a9507ae265ecf5b5356885a53393a2029d241394997265a1a25aefc6");
        let root = x"aea2dd4249dcecf97ca6a1556db7f21ebd6a40bbec0243ca61b717146a08c347";
        let leaf = x"ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb";
        assert!(!merkle_proof::verify(&proof, root, leaf), 0);
    }

    #[test]
    fun test_verify_bad_root() {
        let proof = vector::empty<vector<u8>>();
        vector::push_back(&mut proof, x"3e23e8160039594a33894f6564e1b1348bbd7a0088d42c4acb73eeaed59c009d");
        vector::push_back(&mut proof, x"2e7d2c03a9507ae265ecf5b5356885a53393a2029d241394997265a1a25aefc6");
        let root = x"aea9dd4249dcecf97ca6a1556db7f21ebd6a40bbec0243ca61b717146a08c347";
        let leaf = x"ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb";
        assert!(!merkle_proof::verify(&proof, root, leaf), 0);
    }

    #[test]
    fun test_verify_bad_leaf() {
        let proof = vector::empty<vector<u8>>();
        vector::push_back(&mut proof, x"3e23e8160039594a33894f6564e1b1348bbd7a0088d42c4acb73eeaed59c009d");
        vector::push_back(&mut proof, x"2e7d2c03a9507ae265ecf5b5356885a53393a2029d241394997265a1a25aefc6");
        let root = x"aea2dd4249dcecf97ca6a1556db7f21ebd6a40bbec0243ca61b717146a08c347";
        let leaf = x"ca978112ca1bbdc1fac231b39a23dc4da786eff8147c4e72b9807785afee48bb";
        assert!(!merkle_proof::verify(&proof, root, leaf), 0);
    }
}