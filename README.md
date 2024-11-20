# dubhe-framework

### Testnet
```txt
PackageID: 0x1736475f476c5dec96f33c03c778843f572239d3a887d795eef66d2836484c28                 
Version: 1                                                                                    
Digest: 82AxMudWanFzYGgDoQgiudzxadV1fygDaB2GUfqpqfRi                                        
Modules: dapp_metadata, dapps_schema, dapps_system, root_schema, root_system, storage_double_map, storage_map, storage_value

ObjectID: 0xeecb3a6cd374bae300aa731d57745a267e7f7c98a9ecd2f6646db4231d24bfec
ObjectType: 0x2::package::UpgradeCap

ObjectID: 0xf1b8d53c26b2de48d0a4729000e956318e7dcb1fbb32e8d9510a92445999047c
ObjectType: 0x1736475f476c5dec96f33c03c778843f572239d3a887d795eef66d2836484c28::root_schema::Root

ObjectID: 0x92c78ef688a5cb7f6a9f18e76d1da927e26281c367564ffbe5f886ec06434f08
ObjectType: 0x1736475f476c5dec96f33c03c778843f572239d3a887d795eef66d2836484c28::dapps_schema::Dapps
```

```shell
# upgrade
sui client upgrade --gas-budget 1000000000 --upgrade-capability 0x9f4cd3e0aa5587b2d9191fa20ea877a0d66c6eb6a4f49ec34328122b29d1d9c6
```

