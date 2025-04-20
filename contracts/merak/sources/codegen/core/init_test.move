#[test_only]module merak::merak_init_test {

  use sui::clock;

  use sui::test_scenario;

  use sui::test_scenario::Scenario;

  public fun deploy_dapp_for_testing(scenario: &mut Scenario) {
    let ctx = test_scenario::ctx(scenario);
    let clock = clock::create_for_testing(ctx);
    merak::merak_genesis::run(&clock,  ctx);
    clock::destroy_for_testing(clock);
    test_scenario::next_tx(scenario, ctx.sender());
  }
}
