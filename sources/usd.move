// SPDX-License-Identifier: MIT

module lending_protocol::usd {
    use std::object::{Self, ExtendRef, Object};
    use std::string;
    use std::primary_fungible_store;
    use std::option::{Self, Option};
    use std::fungible_asset::{Self, FungibleAsset, FungibleStore, Metadata, BurnRef, MintRef, TransferRef};

    friend lending_protocol::pool;

    const APP_OBJECT_SEED: vector<u8> = b"USD";    


     struct USDCaps has key {
        metadata_address: address,
        mint_ref: MintRef,
        burn_ref: BurnRef,
    }

   fun init_module(deployer: &signer) {
        let constructor_ref = &object::create_named_object(deployer, APP_OBJECT_SEED, false);
        //TODO
          primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(),
            string::utf8(b"USD"), 
            string::utf8(b"USD"), 
            6, 
            string::utf8(b"https://i.ibb.co/xzz1KK2/TLP.png"), 
            string::utf8(b"")); 
        let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);
        let metadata_address = object::object_address<Metadata>(fungible_asset::mint_ref_metadata(&mint_ref));
        let app_signer = &object::generate_signer(constructor_ref); 
        move_to(app_signer,
                USDCaps{ 
                    metadata_address,
                    mint_ref, 
                    burn_ref});
   }


    public (friend)  fun mint_to(to: Object<FungibleStore>, amount: u64) acquires USDCaps{
        let usd_signer_address = get_app_signer_address();
        let usd_caps = borrow_global<USDCaps>(usd_signer_address);
        fungible_asset::mint_to(&usd_caps.mint_ref, to, amount);
   }

    public (friend) fun burn_from(from: Object<FungibleStore>, amount: u64 ) acquires USDCaps {
        let usd_signer_address = get_app_signer_address();
        let usd_caps = borrow_global<USDCaps>(usd_signer_address);
        fungible_asset::burn_from(&usd_caps.burn_ref, from, amount);

    }
    
    #[view]
    public fun get_app_signer_address(): address {
        object::create_object_address(@lending_protocol, APP_OBJECT_SEED)
    }
    

    #[view]
    public fun get_usd_metadata(): Object<Metadata>  acquires USDCaps {
        let usd_signer_address = get_app_signer_address();
        let usd_caps = borrow_global<USDCaps>(usd_signer_address); 
        object::address_to_object(usd_caps.metadata_address)
    }
}   