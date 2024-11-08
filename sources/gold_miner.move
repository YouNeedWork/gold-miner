module gold_miner::gold_miner{
	use std::u256;
	use moveos_std::event::emit;
	use gold_miner::gold;
	use rooch_framework::coin;
	use moveos_std::signer::address_of;
	use moveos_std::object::{Self, Object};
	use rooch_framework::account_coin_store;

	//struct
	struct MineInfo has key,store {
		/// how many coin your mine
		mined:u256,
		/// boost
		boost: u64,
		/// staking boost,
		staking: u64,
	} 

	//event
	struct NewPlayerEvent has copy,drop {
		player:address,
		mined:u256,
	}

	//event
	struct MineEvent has copy,drop {
		player:address,
		mined:u256,
	}

	entry fun start(user:&signer,treasury_obj: &mut Object<gold::Treasury>,_ref:address) {
		// Mint 100 token
		let amount = 100 * 1_000_000;

		let miner = MineInfo {
			mined:amount,
			boost:0,
			staking:9,
		};

		object::transfer(object::new_named_object(miner),address_of(user));

		let treasury = object::borrow_mut(treasury_obj);
		let gold_mine = gold::mint(treasury, amount);
		account_coin_store::deposit(address_of(user), gold_mine);

		emit(NewPlayerEvent{
			player:address_of(user),
			mined:amount,
		});
	}

	///mine $GOLD
	entry fun mine(user:&signer, treasury_obj: &mut Object<gold::Treasury>,miner_obj:&mut Object<MineInfo>) {
		// Mint 1 token
		let amount = 1 * 1_000_000;

		let miner = object::borrow_mut(miner_obj);
		miner.mined = miner.mined+amount;


		let treasury = object::borrow_mut(treasury_obj);
		let gold_mine = gold::mint(treasury, amount);
		account_coin_store::deposit(address_of(user), gold_mine);

		emit(MineEvent{
			player:address_of(user),
			mined:amount,
		});
	}

}
