module dubhe::dapps_system {
    use std::ascii::String;
    use std::ascii;
    use std::type_name;
    use dubhe::root_schema::Root;
    use dubhe::root_system;
    use sui::address;
    use dubhe::dapp_metadata;
    use sui::clock::Clock;
    use dubhe::dapps_schema::Dapps;

    public fun current_package_id<T>(): address {
        let dapp_package_id_string = type_name::get<T>().get_address().into_bytes();
        address::from_ascii_bytes(&dapp_package_id_string)
    }

    public entry fun register<T>(
        dapps: &mut Dapps,
        name: String,
        description: String,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let dapp_package_id = current_package_id<T>();
        assert!(!dapps.borrow_metadata().contains_key(dapp_package_id), 0);

        dapps.borrow_mut_metadata().set(
            dapp_package_id,
            dapp_metadata::new(
                name,
                description,
                ascii::string(b""),
                ascii::string(b""),
                clock.timestamp_ms(),
                vector[]
            )
        );
        dapps.borrow_mut_admin().set(dapp_package_id, ctx.sender());
        dapps.borrow_mut_version().set(dapp_package_id, 0);
        dapps.borrow_mut_safe_mode().set(dapp_package_id, false);
    }

    public entry fun upgrade<T>(dapps: &mut Dapps, old_package_id: address, ctx: &mut TxContext) {
        let new_package_id = current_package_id<T>();
        assert!(!dapps.borrow_metadata().contains_key(new_package_id), 0);
        assert!(dapps.borrow_metadata().contains_key(old_package_id), 0);

        let admin = dapps.borrow_mut_admin().take(old_package_id);
        assert!(admin == ctx.sender(), 0);
        let metadata = dapps.borrow_mut_metadata().take(old_package_id);
        let version = dapps.borrow_mut_version().take(old_package_id) + 1;
        let safe_mode = dapps.borrow_mut_safe_mode().take(old_package_id);

        dapps.borrow_mut_metadata().set(new_package_id, metadata);
        dapps.borrow_mut_admin().set(new_package_id, admin);
        dapps.borrow_mut_version().set(new_package_id, version);
        dapps.borrow_mut_safe_mode().set(new_package_id, safe_mode);
    }

    public entry fun set_metadata(
        dapps: &mut Dapps,
        package_id: address,
        name: String,
        description: String,
        icon_url: String,
        website_url: String,
        partners: vector<String>,
        ctx: &mut TxContext
    ) {
        assert!(dapps.borrow_admin().get(package_id) == ctx.sender(), 0);
        assert!(dapps.borrow_metadata().contains_key(package_id), 0);
        let created_at = dapps.borrow_mut_metadata().take(package_id).get_created_at();
        dapps.borrow_mut_metadata().set(package_id, dapp_metadata::new(name, description, icon_url, website_url, created_at, partners));
    }

    public entry fun transfer_ownership(
        dapps: &mut Dapps,
        package_id: address,
        new_admin: address,
        ctx: &mut TxContext
    ) {
        assert!(dapps.borrow_admin().get(package_id) == ctx.sender(), 0);
        dapps.borrow_mut_admin().set(package_id, new_admin);
    }

    public entry fun add_verification(dapps: &mut Dapps, root: &Root, package_id: address, ctx: &mut TxContext) {
        root_system::ensure_root(root, ctx);
        assert!(dapps.borrow_metadata().contains_key(package_id), 0);
        dapps.borrow_mut_verified().set(package_id, true);
    }

    public entry fun remove_verification(dapps: &mut Dapps, root: &Root, package_id: address, ctx: &mut TxContext) {
        root_system::ensure_root(root, ctx);
        assert!(dapps.borrow_metadata().contains_key(package_id), 0);
        dapps.borrow_mut_verified().remove(package_id);
    }

    public fun ensure_admin<T: drop>(dapps: &Dapps, ctx: &TxContext) {
        let package_id = current_package_id<T>();
        assert!(dapps.borrow_admin().get(package_id) == ctx.sender(), 0);
    }

    public fun ensure_no_safe_mode<T: drop>(dapps: &Dapps) {
        let package_id = current_package_id<T>();
        assert!(!dapps.borrow_safe_mode().get(package_id), 0);
    }

}
