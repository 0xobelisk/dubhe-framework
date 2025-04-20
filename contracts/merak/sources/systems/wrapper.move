module merak::merak_wrapper_system {
    use std::ascii::String;
    use std::ascii::string;
    use std::u64;
    use merak::merak_assets_functions;
    use sui::balance;
    use sui::balance::Balance;
    use sui::coin;
    use sui::coin::{Coin, CoinMetadata};
    use merak::custom_schema::WrapperCoin;
    use merak::custom_schema;
    use merak::merak_schema::Schema;
    use std::type_name;
    use merak::merak_errors::{overflows_error, no_permission_error};
    use merak::merak_asset_type;

    public entry fun force_register<T>(schema: &mut Schema, name: String, symbol: String, description: String, decimals: u8, url: String, info: String, ctx: &mut TxContext) {
        no_permission_error(schema.dapp__admin()[] == ctx.sender());
        let asset_id = merak_assets_functions::do_create(schema, false, false, true, merak_asset_type::new_wrapped(),@0x0, name, symbol, description, decimals, url, info);
        custom_schema::wrapper_assets(schema).add<WrapperCoin<T>, u256>(custom_schema::new(), asset_id);
        let coin_type = type_name::get<T>().into_string();
        dubhe::storage_event::emit_set_record<String, String, u256>(string(b"wrapper_assets"), option::some(coin_type), option::none(), option::some(asset_id));
        custom_schema::wrapper_pools(schema).add<u256, Balance<T>>(asset_id, balance::zero<T>());
        dubhe::storage_event::emit_set_record<u256, u256, u64>(string(b"wrapper_pools"), option::some(asset_id), option::none(), option::some(0));
    }

    public entry fun register<T>(schema: &mut Schema, metadata: &CoinMetadata<T>): u256 {
        let name = metadata.get_name().to_ascii();
        let decimals = metadata.get_decimals();
        let symbol = metadata.get_symbol();
        let description = metadata.get_description().to_ascii();
        let icon_url = if (metadata.get_icon_url().is_some()) {
            metadata.get_icon_url().borrow().inner_url()
        } else {
            string(b"")
        };
        let asset_id = merak_assets_functions::do_create(schema, false, false, true, merak_asset_type::new_wrapped(), @0x0, name, symbol, description, decimals, icon_url, string(b""));
        custom_schema::wrapper_assets(schema).add<WrapperCoin<T>, u256>(custom_schema::new(), asset_id);
        let coin_type = type_name::get<T>().into_string();
        dubhe::storage_event::emit_set_record<String, String, u256>(string(b"wrapper_assets"), option::some(coin_type), option::none(), option::some(asset_id));
        custom_schema::wrapper_pools(schema).add<u256, Balance<T>>(asset_id, balance::zero<T>());
        dubhe::storage_event::emit_set_record<u256, u256, u64>(string(b"wrapper_pools"), option::some(asset_id), option::none(), option::some(0));
        asset_id
    }

    public entry fun wrap<T>(schema: &mut Schema, coin: Coin<T>, beneficiary: address): u256 {
        let wrapper_coin = custom_schema::new<T>();
        assert!(custom_schema::wrapper_assets(schema).contains(wrapper_coin), 0);
        let asset_id = *custom_schema::wrapper_assets(schema).borrow<WrapperCoin<T>, u256>(wrapper_coin);
        let amount = coin.value();
        let pool_balance = custom_schema::wrapper_pools(schema).borrow_mut<u256, Balance<T>>(asset_id);
        pool_balance.join(coin.into_balance());
        dubhe::storage_event::emit_set_record<u256, u256, u64>(string(b"wrapper_pools"), option::some(asset_id), option::none(), option::some(pool_balance.value()));
        merak_assets_functions::do_mint(schema, asset_id, beneficiary, amount as u256);
        amount as u256
    }

    public entry fun unwrap<T>(schema: &mut Schema, amount: u256, beneficiary: address, ctx: &mut TxContext) {
        let coin =  do_unwrap<T>(schema, amount, ctx);
        transfer::public_transfer(coin, beneficiary);
    }

    public(package) fun do_register<T>(schema: &mut Schema, name: String, symbol: String, description: String, decimals: u8, url: String, info: String): u256 {
        let asset_id = merak_assets_functions::do_create(schema, false, false, true, merak_asset_type::new_wrapped(),@0x0, name, symbol, description, decimals, url, info);
        custom_schema::wrapper_assets(schema).add<WrapperCoin<T>, u256>(custom_schema::new(), asset_id);
        let coin_type = type_name::get<T>().into_string();
        dubhe::storage_event::emit_set_record<String, String, u256>(string(b"wrapper_assets"), option::some(coin_type), option::none(), option::some(asset_id));
        custom_schema::wrapper_pools(schema).add<u256, Balance<T>>(asset_id, balance::zero<T>());
        dubhe::storage_event::emit_set_record<u256, u256, u64>(string(b"wrapper_pools"), option::some(asset_id), option::none(), option::some(0));
        asset_id
    }

    public(package) fun do_unwrap<T>(schema: &mut Schema, amount: u256, ctx: &mut TxContext): Coin<T> {
        overflows_error(amount <= u64::max_value!() as u256);
        let wrapper_coin = custom_schema::new<T>();
        assert!(custom_schema::wrapper_assets(schema).contains(wrapper_coin), 0);
        let asset_id = *custom_schema::wrapper_assets(schema).borrow<WrapperCoin<T>, u256>(wrapper_coin);
        merak_assets_functions::do_burn(schema, asset_id, ctx.sender(), amount);
        let pool_balance = custom_schema::wrapper_pools(schema).borrow_mut<u256, Balance<T>>(asset_id);
        let balance = pool_balance.split(amount as u64);
        dubhe::storage_event::emit_set_record<u256, u256, u64>(string(b"wrapper_pools"), option::some(asset_id), option::none(), option::some(pool_balance.value()));
        coin::from_balance<T>(balance, ctx)
    }
}