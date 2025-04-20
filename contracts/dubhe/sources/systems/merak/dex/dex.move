module dubhe::dubhe_dex_system {
    use std::ascii;
    use sui::coin::Coin;
    use dubhe::dubhe_pool;
    use dubhe::dubhe_dex_functions::{sort_assets};
    use dubhe::dubhe_assets_functions;
    use dubhe::dubhe_wrapper_system;
    use dubhe::dubhe_assets_system;
    use dubhe::dubhe_dex_functions;
    use dubhe::dubhe_math_system;
    use dubhe::dubhe_schema::Schema;
    use dubhe::dubhe_asset_type;
    use dubhe::dubhe_events::{pool_created_event, liquidity_added_event, liquidity_removed_event};
    use dubhe::dubhe_errors:: {
        asset_not_found_error, pool_already_exists_error, below_min_amount_error, overflows_error, below_min_liquidity_error
    };

    const LP_ASSET_DESCRIPTION: vector<u8> = b"Merak LP Asset";
    const LP_ASSET_NAME: vector<u8> = b"Merak LP Asset";

    public entry fun create_pool(schema: &mut Schema, asset1: u256, asset2: u256, ctx: &mut TxContext) {
        let sender = ctx.sender();

        let (asset1, asset2) = sort_assets(asset1, asset2);

        asset_not_found_error(schema.asset_metadata().contains(asset1));
        asset_not_found_error(schema.asset_metadata().contains(asset2));
        pool_already_exists_error(!schema.pools().contains(asset1, asset2));

        let asset1_metadata = schema.asset_metadata()[asset1];
        let asset2_metadata = schema.asset_metadata()[asset2];
        let lp_asset_symbol = dubhe_dex_functions::pool_asset_symbol(asset1_metadata, asset2_metadata);
        let pool_address = dubhe_dex_functions::generate_pool_address(asset1, asset2);

        let lp_asset_id = dubhe_assets_functions::do_create(
            schema,
            false,
            false,
            false,
            dubhe_asset_type::new_package(),
            @0x0,
            ascii::string(LP_ASSET_NAME),
            lp_asset_symbol,
            ascii::string(LP_ASSET_DESCRIPTION),
            9,
            ascii::string(b""),
            ascii::string(b""),
        );


        schema.pools().set(asset1, asset2, dubhe_pool::new(pool_address, lp_asset_id));
        pool_created_event(sender, asset1, asset2, pool_address, lp_asset_id, lp_asset_symbol);
    }

    public entry fun add_liquidity(schema: &mut Schema, asset1: u256, asset2: u256, amount1_desired: u256, amount2_desired: u256, amount1_min: u256, amount2_min: u256, ctx: &mut TxContext) {
        let sender = ctx.sender();

        let (pool_address, lp_asset_id) = dubhe_dex_functions::get_pool(schema, asset1, asset2).get();

        let reserve1 = dubhe_assets_system::balance_of(schema, asset1, pool_address);
        let reserve2 = dubhe_assets_system::balance_of(schema, asset2, pool_address);
        let amount1;
        let amount2;
        if(reserve1 == 0 || reserve2 == 0) {
            amount1 = amount1_desired;
            amount2 = amount2_desired;
        } else {
            let amount2_optimal = dubhe_dex_functions::quote(amount1_desired, reserve1, reserve2);
            if(amount2_optimal <= amount2_desired) {
                assert!(amount2_optimal >= amount2_min, 0);
                amount1 = amount1_desired;
                amount2 = amount2_optimal;
            } else {
                let amount1_optimal = dubhe_dex_functions::quote(amount2_desired, reserve2, reserve1);
                assert!(amount1_optimal <= amount1_desired, 0);
                assert!(amount1_optimal >= amount1_min, 0);
                amount1 = amount1_optimal;
                amount2 = amount2_desired;
            }
        };

        dubhe_assets_functions::do_transfer(schema, asset1, sender, pool_address, amount1);
        dubhe_assets_functions::do_transfer(schema, asset2, sender, pool_address, amount2);

        let total_supply = dubhe_assets_system::supply_of(schema, lp_asset_id);
        let mut lp_token_amount;
        let min_liquidity = schema.min_liquidity()[];
        if (total_supply == 0) {
            lp_token_amount = dubhe_dex_functions::calc_lp_amount_for_zero_supply(schema, amount1, amount2);
            dubhe_assets_functions::do_mint(
                schema,
                lp_asset_id,
                pool_address,
                min_liquidity
            );
        } else {
            let side1 = dubhe_math_system::safe_mul_div(amount1, total_supply, reserve1);
            let side2 = dubhe_math_system::safe_mul_div(amount2, total_supply, reserve2);
            lp_token_amount = side1.min(side2);
        };

        below_min_liquidity_error(lp_token_amount >= min_liquidity);

        if(schema.fee_to().contains()) {
            let lp_fee = schema.lp_fee()[];
            let fee_to = schema.fee_to()[];
            let fee = dubhe_math_system::safe_mul_div(lp_token_amount, lp_fee, 10000);
            dubhe_assets_functions::do_mint(schema, lp_asset_id, fee_to, fee);
            lp_token_amount = lp_token_amount - fee;
        };

        dubhe_assets_functions::do_mint(schema, lp_asset_id, sender, lp_token_amount);
        liquidity_added_event(sender, asset1, asset2, amount1, amount2, lp_asset_id, lp_token_amount);
    }

    public entry fun remove_liquidity(schema: &mut Schema, asset1: u256, asset2: u256, lp_token_burn: u256, amount1_min_receive: u256, amount2_min_receive: u256, ctx: &mut TxContext) {
        let sender = ctx.sender();
        let mut lp_token_burn = lp_token_burn;

        let (pool_address, lp_asset_id) = dubhe_dex_functions::get_pool(schema, asset1, asset2).get();

        let reserve1 = dubhe_assets_system::balance_of(schema, asset1, pool_address);
        let reserve2 = dubhe_assets_system::balance_of(schema, asset2, pool_address);

        let total_supply = dubhe_assets_system::supply_of(schema, lp_asset_id);
        overflows_error(total_supply >= lp_token_burn);

        if(schema.fee_to().contains()) {
            let lp_fee = schema.lp_fee()[];
            let fee_to = schema.fee_to()[];
            let fee = dubhe_math_system::safe_mul_div(lp_token_burn, lp_fee, 10000);
            dubhe_assets_functions::do_transfer(schema, lp_asset_id, sender, fee_to, fee);
            lp_token_burn = lp_token_burn - fee;
        };

        let amount1 = dubhe_math_system::safe_mul_div(lp_token_burn, reserve1, total_supply);
        let amount2 = dubhe_math_system::safe_mul_div(lp_token_burn, reserve2, total_supply);

        below_min_amount_error(amount1 > 0 && amount1 >= amount1_min_receive);
        below_min_amount_error(amount2 > 0 && amount2 >= amount2_min_receive);

        // burn the provided lp token amount that includes the fee
        dubhe_assets_functions::do_burn(schema, lp_asset_id, sender, lp_token_burn);

        dubhe_assets_functions::do_transfer(schema, asset1, pool_address, sender, amount1);
        dubhe_assets_functions::do_transfer(schema, asset2, pool_address, sender, amount2);

        liquidity_removed_event(sender, asset1, asset2, amount1, amount2, lp_asset_id, lp_token_burn);
    }

    /// Swap the exact amount of `asset1` into `asset2`.
    /// `amount_out_min` param allows you to specify the min amount of the `asset2`
    /// you're happy to receive.
    ///
    public entry fun swap_exact_tokens_for_tokens(schema: &mut Schema, path: vector<u256>, amount_in: u256, amount_out_min: u256, to: address, ctx: &mut TxContext) {
        let sender = ctx.sender();
        dubhe_dex_functions::do_swap_exact_tokens_for_tokens(schema, sender, path, amount_in, amount_out_min, to);
    }

    /// Swap any amount of `asset1` to get the exact amount of `asset2`.
    /// `amount_in_max` param allows to specify the max amount of the `asset1`
    /// you're happy to provide.
    ///
    public entry fun swap_tokens_for_exact_tokens(schema: &mut Schema, path: vector<u256>, amount_out: u256, amount_in_max: u256, to: address, ctx: &mut TxContext) {
        let sender = ctx.sender();
        dubhe_dex_functions::do_swap_tokens_for_exact_tokens(schema, sender, path, amount_out, amount_in_max, to);
    }

    public entry fun swap_exact_coin_for_tokens<T>(schema: &mut Schema, path: vector<u256>, amount_in: Coin<T>, amount_out_min: u256, to: address, ctx: &mut TxContext) {
        let sender = ctx.sender();
        let amount_in = dubhe_wrapper_system::wrap(schema, amount_in, sender);
        dubhe_dex_functions::do_swap_exact_tokens_for_tokens(schema, sender, path, amount_in, amount_out_min, to);
    }

    public fun get_amount_out(schema: &mut Schema, path: vector<u256>, amount_in: u256): u256 {
        dubhe_dex_functions::validate_swap_path(schema, path);
        if(amount_in == 0) {
            return 0
        };
        let balance_path = dubhe_dex_functions::balance_path_from_amount_in(schema, amount_in, path);
        let amount_out = balance_path[balance_path.length() - 1].get_balance();
        amount_out
    }

    public fun get_amount_in(schema: &mut Schema, path: vector<u256>, amount_out: u256): u256 {
        dubhe_dex_functions::validate_swap_path(schema, path);
        if(amount_out == 0) {
            return 0
        };
        let balance_path = dubhe_dex_functions::balance_path_from_amount_out(schema, amount_out, path);
        let amount_in = balance_path[0].get_balance();
        amount_in
    }
}