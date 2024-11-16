// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {PoolAddressesProvider} from "../../../src/providers/PoolAddressesProvider.sol";
import {Script} from "forge-std/Script.sol";

contract DeployPoolAddressesProvider is Script {
    function run() external returns (PoolAddressesProvider) {
        vm.startBroadcast();
        PoolAddressesProvider poolAddressesProvider = new PoolAddressesProvider(
            "Skale",
            0x755AC4E90c24135f1B7f73AeEA6a7ff42b07dd94
        );
        vm.stopBroadcast();
        return poolAddressesProvider;
    }
}
// forge script DeployPoolAddressesProvider --account defaultKey --sender 0x755AC4E90c24135f1B7f73AeEA6a7ff42b07dd94 --rpc-url $SKALE_TITAN_HUB_RPC_URL --broadcast --legacy
// 0xa031e87b079aE109Fc9d76094434A04c3D4111A9
