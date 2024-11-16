// //SPDX-License-Identifier: MIT
// pragma solidity 0.8.20;

// import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
// import {PoolConfigurator} from "../../../src/pool/PoolConfigurator.sol";
// import {Script} from "forge-std/Script.sol";

// contract ConfigureReserveAsCollateral is Script {
//     function configureReserveAsCollateral(address mostRecentlyDeployed) public {
//         vm.startBroadcast();
//         PoolConfigurator poolConfigurator = PoolConfigurator(
//             mostRecentlyDeployed
//         );
//         poolConfigurator.configureReserveAsCollateral();
//         vm.stopBroadcast();
//     }

//     function run() external {
//         address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
//             "PoolConfigurator",
//             block.chainid
//         );
//         configureReserveAsCollateral(mostRecentlyDeployed);
//     }
// }

// // forge script ConfigureReserveAsCollateral --account defaultKey --sender 0x755AC4E90c24135f1B7f73AeEA6a7ff42b07dd94 --rpc-url $SKALE_TITAN_HUB_RPC_URL --broadcast --legacy
