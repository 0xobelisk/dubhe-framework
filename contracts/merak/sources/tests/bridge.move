#[test_only]
module merak::bridge_tests {
    use std::ascii::{string};
    use sui::transfer::public_share_object;
    use merak::merak_bridge_system;
    use merak::merak_wrapper_system;
    use merak::dubhe::DUBHE;
    use merak::merak_init_test::deploy_dapp_for_testing;
    use merak::merak_assets_system;
    use merak::merak_schema::Schema;
    use sui::test_scenario;
    use sui::coin;

    #[test]
    public fun bridge() {
        let sender = @0xA;
        let mut scenario = test_scenario::begin(sender);
        deploy_dapp_for_testing(&mut scenario);

        let mut schema = test_scenario::take_shared<Schema>(&scenario);
        schema.fee_to().set(@0xB);

        let ctx = test_scenario::ctx(&mut scenario);
        let amount = 100 * 10000000;
        let dubhe = coin::mint_for_testing<DUBHE>(amount, ctx);

        merak_wrapper_system::wrap(&mut schema, dubhe, ctx.sender());
        assert!(merak_assets_system::balance_of(&mut schema, 1, ctx.sender()) as u64 == amount);

        let to = @0x1;
        let amount = 10 * 10000000;
        merak_bridge_system::withdraw(&mut schema, 1, to, string(b"Dubhe OS"), amount, ctx);
        assert!(merak_assets_system::balance_of(&mut schema, 1, ctx.sender()) as u64 == 90 * 10000000);

        let amount = 10 * 10000000;
        let mut treasury_cap = coin::create_treasury_cap_for_testing<DUBHE>(ctx);
        merak_bridge_system::deposit(&mut schema,  &mut treasury_cap, 1,@0x1, @0xA, string(b"Dubhe OS"), amount, ctx);
        assert!(merak_assets_system::balance_of(&mut schema, 1, ctx.sender()) as u64 == 100 * 10000000);

        public_share_object(treasury_cap);
        test_scenario::return_shared<Schema>(schema);
        scenario.end();
    }
}