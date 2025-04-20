#[allow(lint(share_owned))]module merak::merak_genesis {

  use std::ascii::string;

  use sui::clock::Clock;

  use merak::merak_dapp_system;

  public entry fun run(clock: &Clock, ctx: &mut TxContext) {
    // Create schemas
    let mut schema = merak::merak_schema::create(ctx);
    // Setup default storage
    merak_dapp_system::create(&mut schema, string(b"merak"),string(b"Merak Protocol"), clock , ctx);
    // Logic that needs to be automated once the contract is deployed
    merak::merak_deploy_hook::run(&mut schema,  ctx);
    // Authorize schemas and public share objects
    sui::transfer::public_share_object(schema);
  }
}
