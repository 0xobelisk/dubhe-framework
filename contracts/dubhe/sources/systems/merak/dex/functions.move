module dubhe::dubhe_dex_functions {
    use std::u64;
    use std::debug::print;
    use std::ascii;
    use std::ascii::String;
    use sui::vec_set;
    use dubhe::dubhe_math_system;
    use dubhe::dubhe_assets_functions;
    use dubhe::dubhe_schema::Schema;
    use dubhe::dubhe_pool::Pool;
    use sui::bcs;
    use sui::address;
    use dubhe::dubhe_asset_metadata::AssetMetadata;
    use dubhe::dubhe_assets_system;
    use dubhe::dubhe_path_element::PathElement;
    use dubhe::dubhe_path_element;
    use dubhe::dubhe_events::{
        swap_executed_event
    };
    use dubhe::dubhe_errors::{
        pool_not_found_error, below_min_liquidity_error, swap_path_too_small_error,
        more_than_max_swap_path_len_error, reserves_cannot_be_zero_error, amount_cannot_be_zero_error,
        less_than_amount_out_min_error, more_than_amount_in_max_error
    };
    use sui::hash;

    public(package) fun sort_assets(asset1: u256, asset2: u256): (u256, u256) {
        assert!(asset1 != asset2, 0);
        if (asset1 < asset2) {
            (asset1, asset2)
        } else {
            (asset2, asset1)
        }
    }

    public(package) fun generate_pool_address(asset1: u256, asset2: u256): address {
        let (asset1, asset2) = sort_assets(asset1, asset2);
        let mut asset1 = bcs::to_bytes(&asset1);
        let asset2 = bcs::to_bytes(&asset2);
        asset1.append(asset2);
        address::from_bytes(hash::blake2b256(&asset1))
    }

    public(package) fun get_pool(schema: &mut Schema, asset1: u256, asset2: u256): Pool {
        let (asset1, asset2) = sort_assets(asset1, asset2);
        pool_not_found_error(schema.pools().contains(asset1, asset2));
        schema.pools()[asset1, asset2]
    }

    public(package) fun pool_asset_symbol(asset1_metadata: AssetMetadata, asset2_metadata: AssetMetadata): String {
        let asset1_symbol = asset1_metadata.get_symbol();
        let asset2_symbol = asset2_metadata.get_symbol();
        let mut lp_asset_symbol = ascii::string(b"");
        lp_asset_symbol.append(asset1_symbol);
        lp_asset_symbol.append(ascii::string(b"-"));
        lp_asset_symbol.append(asset2_symbol);
        lp_asset_symbol
    }

    public(package) fun quote(amount: u256, reserve1: u256, reserve2: u256): u256 {
        dubhe_math_system::safe_mul_div(amount , reserve2 , reserve1 )
    }

    public(package) fun calc_lp_amount_for_zero_supply(schema: &mut Schema, amount1: u256, amount2: u256): u256 {
        let result  = dubhe_math_system::safe_mul_sqrt(amount1 , amount2 );
        let min_liquidity = schema.min_liquidity()[];
        below_min_liquidity_error(result >= min_liquidity);
        result - min_liquidity
    }

    /// Ensure that a path is valid.
    /// validate all the pools in the path are unique
    /// Avoiding circular paths
    public(package) fun validate_swap_path(schema: &mut Schema, path: vector<u256>) {
        let len = path.length();
        swap_path_too_small_error(len >= 2);
        more_than_max_swap_path_len_error(len <= schema.max_swap_path_len()[]);

        let mut pools = vec_set::empty<address>();

        let paths = dubhe_math_system::windows(&path, 2);
        paths.do!(|path| {
            let pool_address = generate_pool_address(path[0], path[1]);
            pools.insert(pool_address);
        });
    }

    /// Returns the balance of each asset in the dubhe_pool.
    /// The tuple result is in the order requested (not necessarily the same as dubhe_pool order).
    public(package) fun get_reserves(schema: &mut Schema, asset1: u256, asset2: u256): (u256, u256) {
        let pool = get_pool(schema, asset1, asset2);

        let balance1 = dubhe_assets_system::balance_of(schema, asset1, pool.get_pool_address());
        let balance2 = dubhe_assets_system::balance_of(schema, asset2, pool.get_pool_address());
        (balance1, balance2)
    }

    // Calculates amount out.
    //
    // Given an input amount of an asset and pair reserves, returns the maximum output amount
    // of the other asset.
    public(package) fun get_amount_out(schema: &mut Schema, amount_in: u256, reserve_in: u256, reserve_out: u256): u256 {
        reserves_cannot_be_zero_error(reserve_in > 0 && reserve_out > 0);

        let amount_in_with_fee = amount_in * (10000 - schema.swap_fee()[]);

        let numerator = amount_in_with_fee * reserve_out;

        let denominator = reserve_in * 10000 + amount_in_with_fee;

        numerator / denominator
    }

    // Calculates amount out.
    //
    // Given an input amount of an asset and pair reserves, returns the maximum output amount
    // of the other asset.
    public(package) fun get_amount_in(schema: &mut Schema, amount_out: u256, reserve_in: u256, reserve_out: u256): u256 {
        reserves_cannot_be_zero_error(reserve_in > 0 && reserve_out > 0);

        let numerator = reserve_in * amount_out * 10000;

        let denominator = (reserve_out - amount_out) * (10000 - schema.swap_fee()[]);
        (numerator / denominator + 1)
    }

    /// Following an amount into a `path`, get the corresponding amounts out.
    public(package) fun balance_path_from_amount_in(schema: &mut Schema, amount_in: u256, path: vector<u256>): vector<PathElement> {
        let mut balance_path = vector[];
        let mut amount_out = amount_in;

        let len = path.length();

        u64::range_do!(0, len, |i| {
            let asset1 = path[i];
            if (i + 1 < len) {
                let asset2 = path[i + 1];
                let (reserve_in, reserve_out) = get_reserves(schema, asset1, asset2);
                balance_path.push_back(dubhe_path_element::new(asset1, amount_out));
                amount_out = get_amount_out(schema, amount_out, reserve_in, reserve_out);
            } else {
                balance_path.push_back(dubhe_path_element::new(asset1, amount_out));
            };
        });
        balance_path
    }

    public(package) fun balance_path_from_amount_out(schema: &mut Schema, amount_out: u256, path: vector<u256>): vector<PathElement> {
        let mut balance_path = vector[];
        let mut amount_in = amount_out;
        let mut path = path;
        path.reverse();

        let len = path.length();
        u64::range_do!(0, len, |i| {
            let asset2 = path[i];
            if (i + 1 < len) {
                let asset1 = path[i + 1];
                let (reserve_in, reserve_out) = get_reserves(schema, asset1, asset2);
                balance_path.push_back(dubhe_path_element::new(asset2, amount_in));
                amount_in = get_amount_in(schema, amount_in, reserve_in, reserve_out);
            } else {
                balance_path.push_back(dubhe_path_element::new(asset2, amount_in));
            };
        });
        balance_path.reverse();
        balance_path
    }

    public(package) fun credit_swap(schema: &mut Schema, amount_in: u256, path: vector<PathElement>): (u256, u256) {
        let len = path.length();
        let mut pos = 0;
        let mut return_balance = 0;
        let mut return_asset_id = 0;
        while (pos < len) {
            let asset1 = path[pos].get_asset_id();

            if(pos + 1 < len) {
                let asset2 = path[pos + 1].get_asset_id();
                let amount_out = path[pos + 1].get_balance();
                let pool_from_address = generate_pool_address(asset1, asset2);

                if (pos + 2 < len) {
                    let asset3 = path[pos + 2].get_asset_id();
                    let pool_to_address = generate_pool_address(asset2, asset3);
                    dubhe_assets_functions::do_transfer(schema, asset2, pool_from_address, pool_to_address, amount_out);
                } else {
                    dubhe_assets_functions::do_burn(schema, asset2, pool_from_address, amount_out);
                    return_asset_id = asset2;
                    return_balance = amount_out;
                    break
                };
            };

            pos = pos + 1;
        };

        let asset1 = path[0].get_asset_id();
        let asset2 = path[1].get_asset_id();
        let pool_to_address = generate_pool_address(asset1, asset2);

        dubhe_assets_functions::do_mint(schema, asset1, pool_to_address, amount_in);
        (return_asset_id, return_balance)
    }

    // Swap assets along the `path`, withdrawing from `sender` and depositing in `send_to`.
    // Note: It's assumed that the provided `path` is valid.
    public(package) fun swap(schema: &mut Schema, sender: address, path: vector<PathElement>, send_to: address) {
        let asset_in = path[0].get_asset_id();
        let amount_in = path[0].get_balance();
        // Withdraw the first asset from the sender
        dubhe_assets_functions::do_burn(schema, asset_in, sender, amount_in);
        let (asset_id, amount_out) = credit_swap(schema, amount_in, path);
        // Deposit the last asset to the send_to
        dubhe_assets_functions::do_mint(schema, asset_id, send_to, amount_out);
    }

    /// Swap exactly `amount_in` of asset `path[0]` for asset `path[1]`.
    /// If an `amount_out_min` is specified, it will return an error if it is unable to acquire
    /// the amount desired.
    ///
    /// Withdraws the `path[0]` asset from `sender`, deposits the `path[1]` asset to `send_to`,
    /// respecting `keep_alive`.
    ///
    /// If successful, returns the amount of `path[1]` acquired for the `amount_in`.
    ///
    public(package) fun do_swap_exact_tokens_for_tokens(
        schema: &mut Schema,
        sender: address,
        path: vector<u256>,
        amount_in: u256,
        amount_out_min: u256,
        send_to: address
    ) {
        amount_cannot_be_zero_error(amount_in > 0 && amount_out_min > 0);
        validate_swap_path(schema, path);

        let balance_path = balance_path_from_amount_in(schema, amount_in, path);
        print(&balance_path);

        let amount_out = balance_path[balance_path.length() - 1].get_balance();
        less_than_amount_out_min_error(amount_out >= amount_out_min);

        swap(schema, sender, balance_path, send_to);
        swap_executed_event(sender, send_to, amount_in, amount_out, path);
    }

    /// Take the `path[0]` asset and swap some amount for `amount_out` of the `path[1]`. If an
    /// `amount_in_max` is specified, it will return an error if acquiring `amount_out` would be
    /// too costly.
    ///
    /// Withdraws `path[0]` asset from `sender`, deposits the `path[1]` asset to `send_to`,
    /// respecting `keep_alive`.
    ///
    /// If successful returns the amount of the `path[0]` taken to provide `path[1]`.
    ///
    public(package) fun do_swap_tokens_for_exact_tokens(
        schema: &mut Schema,
        sender: address,
        path: vector<u256>,
        amount_out: u256,
        amount_in_max: u256,
        send_to: address) {
        amount_cannot_be_zero_error(amount_out > 0 && amount_in_max > 0);

        validate_swap_path(schema, path);

        let balance_path = balance_path_from_amount_out(schema, amount_out, path);
        print(&balance_path);

        let amount_in = balance_path[0].get_balance();
        more_than_amount_in_max_error(amount_in <= amount_in_max);

        swap(schema, sender, balance_path, send_to);
        swap_executed_event(sender, send_to, amount_in, amount_out, path);
    }
}