// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Pool} from "../../../src/pool/Pool.sol";
import {IPoolAddressesProvider} from "../../../src/interfaces/IPoolAddressesProvider.sol";
import {Script} from "forge-std/Script.sol";

contract DeployPool is Script {
    function run() external returns (Pool) {
        vm.startBroadcast();
        Pool pool = new Pool(
            IPoolAddressesProvider(0xa031e87b079aE109Fc9d76094434A04c3D4111A9)
        );
        vm.stopBroadcast();
        return pool;
    }
}
// forge script DeployPoolAddressesProvider --account defaultKey --sender 0x755AC4E90c24135f1B7f73AeEA6a7ff42b07dd94 --rpc-url $SKALE_TITAN_HUB_RPC_URL --broadcast --legacy
// 0x61F3792D4EA8709646Ce5DB4c3bE1603cee8b5e7
