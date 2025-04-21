module dubhe::dubhe_dapp_system {

  use std::ascii::String;

  use std::ascii;

  use dubhe::type_info;

  use sui::clock::Clock;

  use sui::transfer::public_share_object;

  use dubhe::dubhe_schema::Schema;

  use dubhe::dubhe_dapp_metadata;

  use dubhe::dubhe_dapp_metadata::DappMetadata;

  use dubhe::storage::add_field;

  use dubhe::storage_value_internal::{Self, StorageValue};

  public fun create_dapp<DappKey: copy + drop>(
    schema: &mut Schema,
    _: DappKey,
    dapp_metadata: DappMetadata,
    ctx: &TxContext,
  ) {
    let package_id = type_info::get_package_id<DappKey>();
    schema.dapp_admin().set(package_id, ctx.sender());
    schema.dapp_version().set(package_id, 1);
    schema.dapp_metadata().set(package_id, dapp_metadata);
    schema.dapp_package_id().set(package_id, package_id);
    schema.dapp_pausable().set(package_id, false);
  }

   public fun upgrade_dapp<DappKey: copy + drop>(schema: &mut Schema, _: DappKey, new_package_id: address, new_version: u32, ctx: &mut TxContext) {
    let package_id = type_info::get_package_id<DappKey>();
    assert!(schema.dapp_metadata().contains(package_id), 0);
    assert!(schema.dapp_admin().get(package_id) == ctx.sender(), 0);
    let current_version = schema.dapp_version()[package_id];
    assert!(current_version < new_version, 0);
    schema.dapp_version().set(package_id, new_version);
    schema.dapp_package_id().set(package_id, new_package_id);
  }

  public entry fun set_metadata<DappKey: copy + drop>(
    schema: &mut Schema,
    name: String,
    description: String,
    cover_url: vector<String>,
    website_url: String,
    partners: vector<String>,
    ctx: &TxContext,
  ) {
    let package_id = type_info::get_package_id<DappKey>();  
    let admin = schema.dapp_admin().try_get(package_id);
    assert!(admin == option::some(ctx.sender()), 0);
    let created_at = schema.dapp_metadata().get(package_id).get_created_at();
    schema.dapp_metadata().set(package_id, dubhe_dapp_metadata::new(
                name,
                description,
                cover_url,
                website_url,
                created_at,
                partners
            )
    );
  }

  public entry fun transfer_ownership<DappKey: copy + drop>(schema: &mut Schema, new_admin: address, ctx: &mut TxContext) {
    let package_id = type_info::get_package_id<DappKey>();
    let admin = schema.dapp_admin().try_get(package_id);
    assert!(admin == option::some(ctx.sender()), 0);
    schema.dapp_admin().set(package_id, new_admin);
  }

  public entry fun set_pausable<DappKey: copy + drop>(schema: &mut Schema, pausable: bool, ctx: &TxContext) {
    let package_id = type_info::get_package_id<DappKey>();
    let admin = schema.dapp_admin().try_get(package_id);
    assert!(admin == option::some(ctx.sender()), 0);
    schema.dapp_pausable().set(package_id, pausable);
  }

  public fun ensure_dapp_not_pausable<DappKey: copy + drop>(schema: &mut Schema, _: DappKey) {
    let package_id = type_info::get_package_id<DappKey>();
    let pausable = schema.dapp_pausable().try_get(package_id);
    assert!(pausable == option::some(false), 0);
  }

  public fun ensure_dapp_admin_sign<DappKey: copy + drop>(schema: &mut Schema, _: DappKey, ctx: &TxContext) {
    let package_id = type_info::get_package_id<DappKey>();
    let admin = schema.dapp_admin().try_get(package_id);
    assert!(admin == option::some(ctx.sender()), 0);
  }

  public fun ensure_dapp_version<DappKey: copy + drop>(schema: &mut Schema, _: DappKey, on_chain_version: u32) {
    let package_id = type_info::get_package_id<DappKey>();
    let current_version = schema.dapp_version().get(package_id);
    assert!(current_version == on_chain_version, 0);
  }
}
