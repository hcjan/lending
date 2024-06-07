// SPDX-License-Identifier: MIT

module lending_protocol::pool {

    use lending_protocol::usd;
    use lending_protocol::config;
    use std::signer;
    use std::primary_fungible_store;
    use std::fungible_asset::{Self, Metadata};
    use std::simple_map::{Self,  borrow, borrow_mut, contains_key};
    use std::object::{Self, ExtendRef};
    friend lending_protocol::lend;

    const APP_OBJECT_SEED: vector<u8> = b"LEND";



    //error
    const ENotWhiteListToken: u64 = 3000;        
    const EExceedBorrowAmount: u64 = 3001;
    const EExceedSupplyAmount: u64 = 3002;

    struct PoolController has key, store{
         app_extend_ref: ExtendRef
    }

    

    struct BorrowPool has store {
        user_borrow: simple_map::SimpleMap<address, u256>,
        total_borrow: u256,
    }

    struct ProtocolPool has key {
        borrow_pool:  BorrowPool
    }

    fun init_module(deployer: &signer) {

        let constructor_ref = &object::create_named_object(deployer, APP_OBJECT_SEED, false);
        let extend_ref = object::generate_extend_ref(constructor_ref);
        let app_signer = &object::generate_signer(constructor_ref); 
        move_to(app_signer,
                ProtocolPool{ 
                    borrow_pool: BorrowPool{
                         user_borrow: simple_map::create(),
                         total_borrow: 0,
                    }
                });
        move_to(app_signer, 
                PoolController {
                    app_extend_ref: extend_ref,
        });
                
   }


   


    public (friend) fun borrow_usd(account: &signer, amount: u256) acquires ProtocolPool {
        let usd_metadata = usd::get_usd_metadata();
        primary_fungible_store::ensure_primary_store_exists<Metadata>(signer::address_of(account), usd_metadata);
        let receiving_store = primary_fungible_store::primary_store(signer::address_of(account), usd_metadata);
        
        
        // transfer usd to user
        usd::mint_to(receiving_store, (amount as u64));


        let signer_address = get_app_signer_address();
        let protocol_pool = borrow_global_mut<ProtocolPool>(signer_address);
        let borrow_pool = &mut protocol_pool.borrow_pool;
        let user_address = signer::address_of(account);
        //add user borrow
        if(!contains_key(& borrow_pool.user_borrow, &user_address)){
            simple_map::add(&mut borrow_pool.user_borrow, user_address, amount); 
        }else{
            let user_borrow_value = borrow_mut(&mut borrow_pool.user_borrow, &user_address);
            *user_borrow_value = *user_borrow_value + amount;
        };   

        //add total borrow
        borrow_pool.total_borrow = borrow_pool.total_borrow + amount;

    }

    public (friend) fun repay_usd(repayer: &signer, repaid_user: address, amount: u256) acquires ProtocolPool {
        let signer_address = get_app_signer_address();
        let protocol_pool = borrow_global_mut<ProtocolPool>(signer_address);
        let borrow_pool = &mut protocol_pool.borrow_pool;



        let repaid_user_borrow_value = borrow_mut(&mut borrow_pool.user_borrow, &repaid_user);
        assert!(*repaid_user_borrow_value >= amount, EExceedBorrowAmount);
        *repaid_user_borrow_value = *repaid_user_borrow_value - amount;

        
        let usd_metadata = usd::get_usd_metadata();
        let fungible_store = primary_fungible_store::primary_store(signer::address_of(repayer), usd_metadata);
        usd::burn_from(fungible_store, (amount as u64));   
    }


       
    #[view]
    public fun get_app_signer_address(): address {
        object::create_object_address(@lending_protocol, APP_OBJECT_SEED)
    }

     #[view]
    public fun get_user_token_supply(user: address, token_type: address): u256 {
        let signer_address = get_app_signer_address();
        let is_whitelist_token = config::is_whitelist_token(token_type);
        assert!(is_whitelist_token, ENotWhiteListToken);

  
        //TODO
       
        return 10000
    }

     #[view]
     public fun get_user_total_borrow(user: address): u256 acquires ProtocolPool{
        let signer_address = get_app_signer_address();
        let protocol_pool = borrow_global_mut<ProtocolPool>(signer_address);
        let borrow_pool = &protocol_pool.borrow_pool;
         if(!contains_key(&borrow_pool.user_borrow, &user)){
            return 0
        };
        let user_borrow = borrow(&borrow_pool.user_borrow, &user);
        return *user_borrow
     }



    fun get_app_signer(app_signer_address: address): signer acquires PoolController {
        object::generate_signer_for_extending(&borrow_global<PoolController>(app_signer_address).app_extend_ref)
    }
    
    
}   