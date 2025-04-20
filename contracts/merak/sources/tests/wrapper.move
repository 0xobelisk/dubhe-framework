#[test_only]
module merak::wrapper_tests {
    use merak::merak_schema::Schema;
    use merak::merak_init_test::deploy_dapp_for_testing;
    use merak::merak_assets_system;
    use merak::merak_wrapper_system;
    use sui::test_scenario;
    use sui::coin;
    use sui::sui::SUI;

    #[test]
    public fun wrapper_tests() {
         let sender = @0xA;
        let mut scenario = test_scenario::begin(sender);
        deploy_dapp_for_testing(&mut scenario);
        let mut schema = test_scenario::take_shared<Schema>(&scenario);
        
        let ctx = test_scenario::ctx(&mut scenario);
        let amount: u256 = 1000000;

        let sui = coin::mint_for_testing<SUI>(amount as u64, ctx);
        let beneficiary = ctx.sender();
        merak_wrapper_system::wrap(&mut schema, sui, beneficiary);
        assert!(merak_assets_system::balance_of(&mut schema,0, beneficiary) == amount, 0);
        assert!(merak_assets_system::supply_of(&mut schema,0) == amount, 1);

        merak_wrapper_system::unwrap<SUI>(&mut schema, amount, beneficiary, ctx);
        assert!(merak_assets_system::balance_of(&mut schema, 0, beneficiary) == 0, 1);

        let sui = coin::mint_for_testing<SUI>(amount as u64, ctx);
        merak_wrapper_system::wrap(&mut schema, sui, beneficiary);
        assert!(merak_assets_system::balance_of(&mut schema,0, beneficiary) == amount, 0);
        assert!(merak_assets_system::supply_of(&mut schema,0) == amount, 1);

        let sui = coin::mint_for_testing<SUI>(amount as u64, ctx);
        merak_wrapper_system::wrap(&mut schema, sui, beneficiary);
        assert!(merak_assets_system::balance_of(&mut schema,0, beneficiary) == amount * 2, 0);
        assert!(merak_assets_system::supply_of(&mut schema,0) == amount * 2, 1);

        let sui = coin::mint_for_testing<SUI>(amount as u64, ctx);
        merak_wrapper_system::wrap(&mut schema, sui, beneficiary);
        assert!(merak_assets_system::balance_of(&mut schema,0, beneficiary) == amount * 3, 0);
        assert!(merak_assets_system::supply_of(&mut schema,0) == amount * 3, 1);

        test_scenario::return_shared<Schema>(schema);
        scenario.end();
    }
}