// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {PoolDataProvider} from "../../../src/dataProvider/PoolDataProvider.sol";
import {IPoolAddressesProvider} from "../../../src/interfaces/IPoolAddressesProvider.sol";
import {Script} from "forge-std/Script.sol";

contract DeployPoolDataProvider is Script {
    function run() external returns (PoolDataProvider) {
        vm.startBroadcast();
        PoolDataProvider poolDataProvider = new PoolDataProvider(
            IPoolAddressesProvider(0xa031e87b079aE109Fc9d76094434A04c3D4111A9)
        );
        vm.stopBroadcast();
        return poolDataProvider;
    }
}
// 0x4773aF4C57BEB5BcE59b661b8ef8DA2bF35eB97A
