// SPDX-License-Identifier: MIT

module lending_protocol::config {

    use lending_protocol::usd;
    use std::signer;
    use std::vector;
    use std::primary_fungible_store;
    use std::fungible_asset::{Metadata};
    use std::simple_map::{Self, SimpleMap, borrow, borrow_mut, contains_key};
    use std::object::{Self, ExtendRef, Object};
    use std::capability::{Self, Cap};


    const MAX_COLLATERAL_RATIO:u256 = 10000;
    const PRECISION_DECIMALS: u256 = 6;
    const APP_OBJECT_SEED: vector<u8> = b"CONFIG";    




    const ECollateralAlreadyExist: u64 = 2000;
    const ENotCollateral: u64 = 2001;

    struct Config has key {
        collateral_tokens: vector<address>,
        token_decimals: SimpleMap<address, u256>,
        mcr: u256,
        liquidation_rate: u256

    }

    struct ADMIN has drop {}
    

   

    fun init_module(deployer: &signer) {
        let constructor_ref = &object::create_named_object(deployer, APP_OBJECT_SEED, false);
        let app_signer = &object::generate_signer(constructor_ref); 
        move_to(app_signer,
                Config{
                     collateral_tokens: vector::empty(),
                     mcr: 1200000,
                     token_decimals: simple_map::create(),
                     liquidation_rate:  1100000
                }
        );
        capability::create<ADMIN>(deployer, &ADMIN{});
               
      }


    public entry fun add_collateral(account: &signer, token_type: address, decimals: u256) acquires Config {
        acquire_admin_cap(account);
        let signer_address = get_app_signer_address();
        let config = borrow_global_mut<Config>(signer_address); 
        let is_whitelisted = vector::contains(&config.collateral_tokens, &token_type);
        assert!(!is_whitelisted, ECollateralAlreadyExist);
        vector::push_back(&mut config.collateral_tokens, token_type);
        simple_map::add(&mut config.token_decimals, token_type, decimals);
        
    }


     public entry fun disable_collateral(account: &signer, token_type: address) acquires Config {
        acquire_admin_cap(account);
        let signer_address = get_app_signer_address();
        let config = borrow_global_mut<Config>(signer_address); 
        let is_whitelisted = vector::contains(&config.collateral_tokens, &token_type);
        assert!(is_whitelisted, ENotCollateral); 
        let (_, index) = vector::index_of(& config.collateral_tokens, &token_type);
        vector::remove(&mut config.collateral_tokens, index);
        simple_map::remove(&mut config.token_decimals, &token_type);
        
    }

    public entry fun set_mcr(account: &signer, mcr: u256) acquires Config{
        acquire_admin_cap(account);
        let signer_address = get_app_signer_address();
        let config = borrow_global_mut<Config>(signer_address); 
         *&mut config.mcr = mcr;

    }

    public entry fun set_liquidate_rate(account: &signer, liquidation_rate: u256) acquires Config{
        acquire_admin_cap(account);
        let signer_address = get_app_signer_address();
        let config = borrow_global_mut<Config>(signer_address); 
         *&mut config.liquidation_rate = liquidation_rate;

    }


   


    #[view]
    public fun get_token_decimals(token_meta_data_address: address): u256 acquires Config {
        let signer_address = get_app_signer_address();
        let config = borrow_global<Config>(signer_address);
        let decimals = borrow(&config.token_decimals, &token_meta_data_address);
        return *decimals
    }

    #[view]
    public fun is_whitelist_token(token_type: address): bool acquires Config{
        let signer_address = get_app_signer_address();
        let config = borrow_global<Config>(signer_address);
        return vector::contains(&config.collateral_tokens, &token_type)
    }

    #[view]
    public fun get_all_whitelist_tokens():vector<address> acquires Config{
        let signer_address = get_app_signer_address();
        let config = borrow_global<Config>(signer_address);
        return config.collateral_tokens
    }


     #[view]
    public fun get_app_signer_address(): address {
        object::create_object_address(@lending_protocol, APP_OBJECT_SEED)
    }

    #[view]
    public fun get_price_precision_decimal(): u256{
        return PRECISION_DECIMALS
    }

     #[view]
     public fun get_mcr(): u256 acquires Config{
        let signer_address = get_app_signer_address();
        let config = borrow_global<Config>(signer_address);
        return config.mcr
     }

      #[view]
     public fun get_liquidate_rate(): u256 acquires Config{
        let signer_address = get_app_signer_address();
        let config = borrow_global<Config>(signer_address);
        return config.liquidation_rate
     }

    
    #[view]
    public fun get_precision(): u256{
        return PRECISION_DECIMALS
    }

     fun acquire_admin_cap(account: &signer): Cap<ADMIN> {
        capability::acquire<ADMIN>(account, &ADMIN{})
    }


    
}   