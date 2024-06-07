// SPDX-License-Identifier: MIT

module lending_protocol::lend {

    use lending_protocol::config;
    use lending_protocol::pool;
    use lending_protocol::reader;
    use std::event;
    use std::signer;
    use std::vector;
    use std::object::{Self, ExtendRef, Object};


    const APP_OBJECT_SEED: vector<u8> = b"Lend";    


    const ENotWhiteListToken: u64 =  1000;
    const ELowerThanMCR: u64 =  1001;
    const ELiquidated: u64 =  1002;
    const ELargerThanMCR: u64 = 1003;


    struct LiquidateState has key {
        liquidate_lists: vector<LiquidateInfo>,
        liquidated: vector<address>
    }

    struct LiquidateInfo has store, copy, drop{
        src: address,
        dest: address
    }

    #[event]
    struct IncreaseSupplyEvent has store, drop {
        account: address,
        token_type: address,
        amount: u256
    }

     #[event]
    struct IncreaseBorrowEvent has store, drop {
        account: address,
        amount: u256
    }

     #[event]
    struct RepayEvent has store, drop {
        account: address,
        amount: u256
    }


     #[event]
    struct LiquidateEvent has store, drop {
        liquidator: address,
        liquidated_user: address,
        repay_amount: u256
    }

    fun init_module(deployer: &signer) {
        let constructor_ref = &object::create_named_object(deployer, APP_OBJECT_SEED, false);
        let app_signer = &object::generate_signer(constructor_ref); 
        move_to(app_signer,
                LiquidateState{
                     liquidate_lists: vector::empty(),
                     liquidated: vector::empty(),
                }
        );
               
      }
    

   public entry fun borrow(account: &signer, amount: u256) acquires LiquidateState{
        let signer_address = get_app_signer_address();
        let liquidate_state = borrow_global_mut<LiquidateState>(signer_address); 
        assert!(!vector::contains(& liquidate_state.liquidated, &signer::address_of(account)), ELiquidated);
        pool::borrow_usd(account, amount);
        let user_collateral_ratio = reader::get_user_collateral_ratio(signer::address_of(account));
        let system_mcr = config::get_mcr();
        assert!(user_collateral_ratio > system_mcr, ELowerThanMCR);
        event::emit<IncreaseBorrowEvent>(IncreaseBorrowEvent{
              account: signer::address_of(account),
              amount});  
    }

    public entry fun repay(account: &signer, amount: u256){
          pool::repay_usd(account, signer::address_of(account), amount);
          event::emit<RepayEvent>(RepayEvent{
              account: signer::address_of(account),
              amount});  
    }


    public entry fun liquidate(account: &signer, liquidated_user: address) acquires LiquidateState{

        let signer_address = get_app_signer_address();
        let liquidate_state = borrow_global_mut<LiquidateState>(signer_address); 
        assert!(!vector::contains(& liquidate_state.liquidated, &liquidated_user), ELiquidated);


         let user_collateral_ratio = reader::get_user_collateral_ratio(signer::address_of(account));
         let system_liquidate_rate = config::get_liquidate_rate();
         assert!(system_liquidate_rate >= user_collateral_ratio, ELargerThanMCR);


         let repay_amount = pool::get_user_total_borrow(liquidated_user);
         pool::repay_usd(account, liquidated_user, repay_amount);

         //add to liquidate state
         let liquidate_info = LiquidateInfo{
               src: liquidated_user,
               dest: signer::address_of(account)
            };

         vector::push_back(&mut liquidate_state.liquidate_lists,liquidate_info);
         vector::push_back(&mut liquidate_state.liquidated, liquidated_user);
         

         event::emit<LiquidateEvent>(LiquidateEvent{
              liquidator: signer::address_of(account),
              liquidated_user,
              repay_amount
              });  
        
    }


    public entry fun erase_liquidate_infos() acquires LiquidateState{
        //TODO add auth
        let signer_address = get_app_signer_address();
        let liquidate_state = borrow_global_mut<LiquidateState>(signer_address); 
        liquidate_state.liquidate_lists = vector::empty();
        liquidate_state.liquidated = vector::empty();
    }

   

     #[view]
    public fun get_app_signer_address(): address {
        object::create_object_address(@lending_protocol, APP_OBJECT_SEED)
    }   

      #[view]
    public fun get_liquidate_info(): vector<LiquidateInfo> acquires LiquidateState{
         let signer_address = get_app_signer_address();
         let liquidate_state = borrow_global<LiquidateState>(signer_address); 
         return liquidate_state.liquidate_lists
    }

}   