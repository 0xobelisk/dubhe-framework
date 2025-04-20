#[allow(lint(share_owned))]module dubhe::dubhe_genesis {

  use std::ascii::string;

  use sui::clock::Clock;

  use dubhe::dubhe_dapp_system;

  public entry fun run(clock: &Clock, ctx: &mut TxContext) {
    // Create schemas
    let mut schema = dubhe::dubhe_schema::create(ctx);
    // Setup default storage
    dubhe_dapp_system::create(&mut schema, string(b"dubhe"),string(b"Dubhe Protocol"), clock , ctx);
    // Logic that needs to be automated once the contract is deployed
    dubhe::dubhe_deploy_hook::run(&mut schema,  ctx);
    // Authorize schemas and public share objects
    sui::transfer::public_share_object(schema);
  }
}
