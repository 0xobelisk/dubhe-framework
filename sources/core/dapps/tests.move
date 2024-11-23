#[test_only]
module dubhe::dapps_tests {
    use dubhe::dapps_schema::Dapps;
    use dubhe::dapps_schema;
    use dubhe::dapps_system;
    use std::ascii::string;
    use sui::clock;
    use sui::test_scenario;

    public struct DappKey has drop {}

    #[test]
    public fun dapps_register() {
        let mut scenario = test_scenario::begin(@0xA);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            dapps_schema::init_dapps_for_testing(ctx);
            test_scenario::next_tx(&mut scenario,@0xA);
        };

        let mut dapps = test_scenario::take_shared<Dapps>(&scenario);

        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        dapps_system::register<DappKey>(
            &mut dapps,
            string(b"DappKey"),
            string(b"DappKey"),
            &clock,
            test_scenario::ctx(&mut scenario)
        );

        test_scenario::next_tx(&mut scenario,@0xA);
        
        let package_id = dapps_system::current_package_id<DappKey>();
        assert!(dapps.borrow_version().get(package_id) == 0, 0);
        assert!(dapps.borrow_metadata().contains_key(package_id));
        assert!(dapps.borrow_admin().get(package_id) == test_scenario::ctx(&mut scenario).sender(), 0);
        assert!(dapps.borrow_safe_mode().get(package_id) == false, 0);

        // dapps_system::upgrade<DappKey>( &mut dapps, package_id, test_scenario::ctx(&mut scenario));
        //
        // assert!(dapps.borrow_version().get(package_id) == 1, 0);
        // assert!(dapps.borrow_metadata().contains_key(package_id));
        // assert!(dapps.borrow_admin().get(package_id) == test_scenario::ctx(&mut scenario).sender(), 0);
        // assert!(dapps.borrow_safe_mode().get(package_id) == false, 0);

        clock::destroy_for_testing(clock);
        test_scenario::return_shared<Dapps>(dapps);
        scenario.end();
    }
}