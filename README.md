# dubhe-framework

### Testnet
```txt
PackageID: 0x417ad1864a56a29ad0b5aaddd2e11bac1eeab6a68883ef53184a4cc5c293fec6                 
Version: 1                                                                                    
Digest: 82AxMudWanFzYGgDoQgiudzxadV1fygDaB2GUfqpqfRi                                        
Modules: dapp_metadata, dapps_schema, dapps_system, root_schema, root_system, storage_double_map, storage_map, storage_value

ObjectID: 0x48577235e995b059f25f09fc8b3ff74aad4c9b380835567c9967ca60dddf969f
ObjectType: 0x2::package::UpgradeCap

ObjectID: 0x818a958cbf878e0430f9d9327d1d6bd59bba06517c495ea99452e532b3d18c0d
ObjectType: 0x417ad1864a56a29ad0b5aaddd2e11bac1eeab6a68883ef53184a4cc5c293fec6::root_schema::Root

ObjectID: 0x181befc40b3dafe2740b41d5a970e49bed2cca20205506ee6be2cfb73ff2d3e9
ObjectType: 0x417ad1864a56a29ad0b5aaddd2e11bac1eeab6a68883ef53184a4cc5c293fec6::dapps_schema::Dapps
```

```shell
# upgrade
sui client upgrade --gas-budget 1000000000 --upgrade-capability 0x48577235e995b059f25f09fc8b3ff74aad4c9b380835567c9967ca60dddf969f
```

