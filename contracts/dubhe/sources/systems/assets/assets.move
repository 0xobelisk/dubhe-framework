module dubhe::dubhe_assets_system {
    use std::ascii::String;
    use std::ascii::string;
    use dubhe::dubhe_errors::{
        asset_not_found_error, no_permission_error, not_mintable_error, not_burnable_error, account_not_found_error, asset_not_liquid_error, asset_not_frozen_error
    };
    use dubhe::dubhe_schema::Schema;
    use dubhe::dubhe_account_status;
    use dubhe::dubhe_asset_status;
    use dubhe::dubhe_assets_functions;
    use dubhe::dubhe_asset_type;

    public entry fun create(    
        schema: &mut Schema,
        name: String,
        symbol: String,
        description: String,
        decimals: u8,
        icon_url: String,
        extra_info: String,
        initial_supply: u256,
        send_to: address,
        owner: address,
        is_mintable: bool,
        is_burnable: bool,
        is_freezable: bool
    ) {
        // TODO: Charge a fee for creating an asset
        // dapps_system::ensure_no_pausable<DappKey>(dapp);

        // Create a new asset
        let asset_id = dubhe_assets_functions::do_create(
            schema,
            is_mintable,
            is_burnable,
            is_freezable,
            dubhe_asset_type::new_private(),
            owner,
            name,
            symbol,
            description,
            decimals,
            icon_url,
            extra_info
        );

        if (initial_supply > 0) {
            // Mint the initial supply
            dubhe_assets_functions::do_mint(schema, asset_id, send_to, initial_supply);
        };
    }

    /// Mint `amount` of asset `id` to `who`.
    public entry fun mint(schema: &mut Schema, asset_id: u256, to: address, amount: u256, ctx: &mut TxContext) {
        let issuer = ctx.sender();
        asset_not_found_error(schema.asset_metadata().contains(asset_id));
        let asset_metadata = schema.asset_metadata().get(asset_id);
        no_permission_error(asset_metadata.get_owner() == issuer);
        not_mintable_error(asset_metadata.get_is_mintable());

        dubhe_assets_functions::do_mint(schema, asset_id, to, amount);
    }

    /// Reduce the balance of `who` by as much as possible up to `amount` assets of `id`.
    public entry fun burn(schema: &mut Schema, asset_id: u256, from: address, amount: u256, ctx: &mut TxContext) {
        let burner = ctx.sender();
        asset_not_found_error(schema.asset_metadata().contains(asset_id));
        let asset_metadata = schema.asset_metadata().get(asset_id);
        no_permission_error(asset_metadata.get_owner() == burner);
        not_burnable_error(asset_metadata.get_is_burnable());

        dubhe_assets_functions::do_burn(schema, asset_id, from, amount);
    }

    /// Move some assets from the sender account to another.
    public entry fun transfer(schema: &mut Schema, asset_id: u256, to: address, amount: u256, ctx: &mut TxContext) {
        let from = ctx.sender();
        dubhe_assets_functions::do_transfer(schema, asset_id, from, to, amount);
    }

    /// Transfer the entire transferable balance from the caller asset account.
    public entry fun transfer_all(schema: &mut Schema, asset_id: u256, to: address, ctx: &mut TxContext) {
        let from = ctx.sender();
        let balance = balance_of(schema, asset_id, from);

        dubhe_assets_functions::do_transfer(schema, asset_id, from, to, balance);
    }

    /// Disallow further unprivileged transfers of an asset `id` from an account `who`.
    /// `who` must already exist as an entry in `Account`s of the asset.
    public entry fun freeze_address(schema: &mut Schema, asset_id: u256, who: address, ctx: &mut TxContext) {
        let freezer = ctx.sender();

        asset_not_found_error(schema.asset_metadata().contains(asset_id));
        let asset_metadata = schema.asset_metadata().get(asset_id);
        no_permission_error(asset_metadata.get_owner() == freezer);
        account_not_found_error(schema.account().contains(asset_id, who));

        let mut account = schema.account()[asset_id, who];
        account.set_status(dubhe_account_status::new_frozen());
        schema.account().set(asset_id, who, account);
    }

    /// Disallow further unprivileged transfers of an asset `id` to and from an account `who`.
    public entry fun block_address(schema: &mut Schema, asset_id: u256, who: address, ctx: &mut TxContext) {
        let blocker = ctx.sender();

        asset_not_found_error(schema.asset_metadata().contains(asset_id));
        let asset_metadata = schema.asset_metadata().get(asset_id);
        no_permission_error(asset_metadata.get_owner() == blocker);
        account_not_found_error(schema.account().contains(asset_id, who));

        let mut account = schema.account()[asset_id, who];
        account.set_status(dubhe_account_status::new_blocked());
        schema.account().set(asset_id, who, account);
    }

    /// Allow unprivileged transfers to and from an account again.
    public entry fun thaw_address(schema: &mut Schema, asset_id: u256, who: address, ctx: &mut TxContext) {
        let unfreezer = ctx.sender();

        asset_not_found_error(schema.asset_metadata().contains(asset_id));
        let asset_metadata = schema.asset_metadata().get(asset_id);
        no_permission_error(asset_metadata.get_owner() == unfreezer);
        account_not_found_error(schema.account().contains(asset_id, who));

        let mut account = schema.account()[asset_id, who];
        account.set_status(dubhe_account_status::new_liquid());
        schema.account().set(asset_id, who, account);
    }

    /// Disallow further unprivileged transfers for the asset class.
    public entry fun freeze_asset(schema: &mut Schema, asset_id: u256, ctx: &mut TxContext) {
        let freezer = ctx.sender();

        asset_not_found_error(schema.asset_metadata().contains(asset_id));
        let mut asset_metadata = schema.asset_metadata()[asset_id];
        asset_not_liquid_error(asset_metadata.get_status() == dubhe_asset_status::new_liquid());
        no_permission_error(asset_metadata.get_owner() == freezer);

        asset_metadata.set_status(dubhe_asset_status::new_frozen());
        schema.asset_metadata().set(asset_id, asset_metadata);
    }

    /// Allow unprivileged transfers for the asset again.
    public entry fun thaw_asset(schema: &mut Schema, asset_id: u256, ctx: &mut TxContext) {
        let unfreezer = ctx.sender();

         asset_not_found_error(schema.asset_metadata().contains(asset_id));
        let mut asset_metadata = schema.asset_metadata()[asset_id];
        asset_not_frozen_error(asset_metadata.get_status() == dubhe_asset_status::new_frozen());
        no_permission_error(asset_metadata.get_owner() == unfreezer);

        asset_metadata.set_status(dubhe_asset_status::new_liquid());
        schema.asset_metadata().set(asset_id, asset_metadata);
    }

    /// Change the Owner of an asset.
    public entry fun transfer_ownership(schema: &mut Schema, asset_id: u256, to: address, ctx: &mut TxContext) {
        let owner = ctx.sender();

        asset_not_found_error(schema.asset_metadata().contains(asset_id));
        let mut asset_metadata = schema.asset_metadata()[asset_id];
        no_permission_error(asset_metadata.get_owner() == owner);

        asset_metadata.set_owner(to);
        schema.asset_metadata().set(asset_id, asset_metadata);
    }

    public fun balance_of(schema: &mut Schema, asset_id: u256, who: address): u256 {
        let maybe_account = schema.account().try_get(asset_id, who);
        if (maybe_account.is_none()) {
            return 0
        };
        let account = maybe_account.borrow();
        account.get_balance()
    }

    public fun supply_of(schema: &mut Schema, asset_id: u256): u256 {
        let maybe_asset_metadata = schema.asset_metadata().try_get(asset_id);
        if (maybe_asset_metadata.is_none()) {
            return 0
        };
        let asset_metadata = maybe_asset_metadata.borrow();
        asset_metadata.get_supply()
    }

    public fun create_asset<DappKey: drop>(
        schema: &mut Schema, 
        _: DappKey,
        name: String,
        symbol: String, 
        description: String, 
        decimals: u8,
        icon_url: String, 
        is_mintable: bool, 
        is_burnable: bool, 
        is_freezable: bool
    ): u256 {
        let asset_id = dubhe_assets_functions::do_create(
            schema,
            is_mintable,
            is_burnable,
            is_freezable,
            dubhe_asset_type::new_package(),
            @0x0,
            name,
            symbol,
            description,
            decimals,
            icon_url,
            string(b"")
        );
        dubhe_assets_functions::add_package_asset<DappKey>(schema, asset_id);
        asset_id
    }

    public fun mint_asset<DappKey: drop>(
        schema: &mut Schema,
        _: DappKey,
        asset_id: u256,
        to: address,
        amount: u256
    ) {
        dubhe_assets_functions::assert_asset_is_package_asset<DappKey>(schema, asset_id);
        dubhe_assets_functions::do_mint(schema, asset_id, to, amount);
    }

    public fun burn_asset<DappKey: drop>(
        schema: &mut Schema,
        _: DappKey,
        asset_id: u256,
        from: address,
        amount: u256
    ) {
        dubhe_assets_functions::assert_asset_is_package_asset<DappKey>(schema, asset_id);
        dubhe_assets_functions::do_burn(schema, asset_id, from, amount);
    }       

    public fun transfer_asset<DappKey: drop>(
        schema: &mut Schema,
        _: DappKey,
        asset_id: u256,
        from: address,
        to: address,
        amount: u256
    ) {
        dubhe_assets_functions::assert_asset_is_package_asset<DappKey>(schema, asset_id);
        dubhe_assets_functions::do_transfer(schema, asset_id, from, to, amount);
    }
}