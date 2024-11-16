// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {PoolConfigurator} from "../../../src/pool/PoolConfigurator.sol";
import {IPoolAddressesProvider} from "../../../src/interfaces/IPoolAddressesProvider.sol";
import {Script} from "forge-std/Script.sol";

contract DeployPoolConfigurator is Script {
    function run() external returns (PoolConfigurator) {
        vm.startBroadcast();
        PoolConfigurator poolConfigurator = new PoolConfigurator(
            IPoolAddressesProvider(0xa031e87b079aE109Fc9d76094434A04c3D4111A9)
        );
        vm.stopBroadcast();
        return poolConfigurator;
    }
}
// forge script DeployPoolConfigurator --account defaultKey --sender 0x755AC4E90c24135f1B7f73AeEA6a7ff42b07dd94 --rpc-url $SKALE_TITAN_HUB_RPC_URL --broadcast --legacy
// 0xe8Ee52769E88C78b841cfE43B5C460Ca6342c156
