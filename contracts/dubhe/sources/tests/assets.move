#[test_only]
module dubhe::assets_tests {
    use std::ascii;
    use std::ascii::String;
    use dubhe::dubhe_assets_functions;
    use dubhe::dubhe_init_test::deploy_dapp_for_testing;
    use dubhe::dubhe_assets_system;
    use dubhe::dubhe_schema::Schema;
    use sui::test_scenario;
    use sui::test_scenario::Scenario;
    use dubhe::dubhe_asset_type;
    public fun create_assets(schema: &mut Schema, name: String, symbol: String, description: String, decimals: u8, url: String, info: String, scenario: &mut Scenario): u256 {
        let asset_id = dubhe_assets_functions::do_create(schema, true, true, true, dubhe_asset_type::new_private(), @0xA, name, symbol, description, decimals, url, info);
        test_scenario::next_tx(scenario,@0xA);
        asset_id
    }

    #[test]
    public fun assets_create() {
        let sender = @0xA;
        let mut scenario = test_scenario::begin(sender);
        let mut schema = deploy_dapp_for_testing(&mut scenario);

        let name = ascii::string(b"Obelisk Coin");
        let symbol = ascii::string(b"OBJ");
        let description = ascii::string(b"Obelisk Coin");
        let url = ascii::string(b"");
        let info = ascii::string(b"Obelisk Coin");
        let decimals = 9;
        let asset1  = create_assets(&mut schema, name, symbol, description, decimals, url, info, &mut scenario);
        let asset2 = create_assets(&mut schema, name, symbol, description, decimals, url, info, &mut scenario);

        // assert!(schema.next_asset_id()[] == 4, 0);

        let ctx = test_scenario::ctx(&mut scenario);
        dubhe_assets_system::mint(&mut schema, asset1, ctx.sender(), 100, ctx);
        dubhe_assets_system::mint(&mut schema, asset2, ctx.sender(), 100, ctx);
        assert!(dubhe_assets_system::balance_of(&mut schema, asset1, ctx.sender()) == 100, 0);
        assert!(dubhe_assets_system::balance_of(&mut schema, asset1, @0x10000) == 0, 0);
        assert!(dubhe_assets_system::supply_of(&mut schema, asset1) == 100, 0);

        dubhe_assets_system::transfer(&mut schema, asset1, @0x0002, 50, ctx);
        assert!(dubhe_assets_system::balance_of(&mut schema, asset1, ctx.sender()) == 50, 0);
        assert!(dubhe_assets_system::balance_of(&mut schema, asset1, @0x0002) == 50, 0);
        assert!(dubhe_assets_system::supply_of(&mut schema, asset1) == 100, 0);

        dubhe_assets_system::burn(&mut schema, asset1, ctx.sender(), 50, ctx);
        assert!(dubhe_assets_system::balance_of(&mut schema, asset1, ctx.sender()) == 0, 0);
        assert!(dubhe_assets_system::supply_of(&mut schema, asset1) == 50, 0);

        test_scenario::return_shared<Schema>(schema);
        scenario.end();
    }
}