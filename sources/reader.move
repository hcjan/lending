module lending_protocol::reader {
    use lending_protocol::config;
    use lending_protocol::pool;
    use lending_protocol::utils;
    use lending_protocol::usd;
    use std::vector;
    use std::object;
    use std::fungible_asset::{Self, BurnRef, MintRef, TransferRef, FungibleAsset, FungibleStore, Metadata};    
    use oracle_service::pricefeed;


    #[view]
    public fun get_user_supply_total_usd(user: address):u256{
        let whitelist_tokens = config::get_all_whitelist_tokens();
        let tokens_length = vector::length(&whitelist_tokens);
        let usd_value = 0;
        for (i in 0..tokens_length) {
            let token_address_ref = vector::borrow(&whitelist_tokens, i);
            let user_token_supply = pool::get_user_token_supply(user, *token_address_ref);
            let price = get_token_price(*token_address_ref);

            let token_decimals = config::get_token_decimals(*token_address_ref);            
            usd_value = usd_value + user_token_supply * price / utils::pow_u256(10,  token_decimals );
        };
        return usd_value
    }

    #[view]
    public fun get_user_borrow_total_usd(user: address): u256{
        let user_token_borrow = pool::get_user_total_borrow(user);
        let usd_metadata = usd::get_usd_metadata();
        let usd_decimals = fungible_asset::decimals(usd_metadata);
        let system_price_decimals = config::get_price_precision_decimal();
        return user_token_borrow * utils::pow_u256(10, system_price_decimals) / utils::pow_u256(10, ( usd_decimals as u256))
    }
    
    #[view]
    public fun get_user_collateral_ratio(user: address): u256{
        let precision_decimals = config::get_precision();
        let precision = utils::pow_u256(10, precision_decimals);

        return get_user_supply_total_usd(user) * precision / get_user_borrow_total_usd(user)
    }

    #[view]
    public fun get_token_price(token_type: address): u256{
        let (price, decimals) = pricefeed::lastest_round_data(token_type); 
        let system_decimals = config::get_price_precision_decimal();
        if(system_decimals > (decimals as u256)){
            price = price * utils::pow_u256(10, system_decimals - (decimals as u256));
        }else{
            price = price / utils::pow_u256(10, (decimals as u256)- system_decimals);
        };
        return price 
    }

    #[view]
    public fun get_token_max_withdrawable(user: address, token_metadata_address: address): u256{
        let borrow_usd = get_user_borrow_total_usd(user);
        let mcr = config::get_mcr();
        let precision_decimals = config::get_precision();
        let precision = utils::pow_u256(10, precision_decimals);
        let min_collateral_usd_value =  mcr * borrow_usd / precision;
        let token_price = get_token_price(token_metadata_address);
        let token_decimals = config::get_token_decimals(token_metadata_address);                            
        let min_collateral_amount = min_collateral_usd_value * utils::pow_u256(10, token_decimals) / token_price;
        let user_supply_amount = pool::get_user_token_supply(user, token_metadata_address);
        if(min_collateral_amount > user_supply_amount){
            return 0
        };
        return user_supply_amount - min_collateral_amount
    }

}