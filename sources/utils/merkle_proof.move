module gold_miner::merkle_proof {
    use std::vector;
    use std::hash;

    const EINVALID_LENGTH: u64 = 0;

    public fun verify(
        proof: &vector<vector<u8>>,
        root: vector<u8>,
        leaf: vector<u8>
    ): bool {
        process_proof(proof, leaf) == root
    }

    fun process_proof(proof: &vector<vector<u8>>, leaf: vector<u8>): vector<u8> {
        let computed_hash = leaf;
        let proof_length = vector::length(proof);
        let i = 0;

        while (i < proof_length) {
            computed_hash = hash_pair(computed_hash, *vector::borrow(proof, i));
            i = i + 1;
        };

        computed_hash
    }

    fun lt(a: &vector<u8>, b: &vector<u8>): bool {
        let i = 0;
        let len = vector::length(a);
        assert!(len == vector::length(b), EINVALID_LENGTH);

        while (i < len) {
            let aa = *vector::borrow(a, i);
            let bb = *vector::borrow(b, i);
            if (aa < bb) return true;
            if (aa > bb) return false;
            i = i + 1;
        };

        false
    }

    fun hash_pair(a: vector<u8>, b: vector<u8>): vector<u8> {
        if (lt(&a, &b)) efficient_hash(a, b) else efficient_hash(b, a)
    }

    fun efficient_hash(a: vector<u8>, b: vector<u8>): vector<u8> {
        vector::append(&mut a, b);
        hash::sha2_256(a)
    }
}
