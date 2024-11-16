//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {PoolAddressesProvider} from "../../../src/providers/PoolAddressesProvider.sol";
import {Script} from "forge-std/Script.sol";

contract IntegrateAddressesProvider is Script {
    address pool = 0x61F3792D4EA8709646Ce5DB4c3bE1603cee8b5e7;
    address oracle = 0x8CAb6A8589Ab05e7277177CA1cD7f28594D75800;
    address poolDataProvider = 0x4773aF4C57BEB5BcE59b661b8ef8DA2bF35eB97A;
    address poolConfigurator = 0xe8Ee52769E88C78b841cfE43B5C460Ca6342c156;

    function setPoolImpl(address mostRecentlyDeployed) public {
        vm.startBroadcast();
        PoolAddressesProvider poolAddressesProvider = PoolAddressesProvider(
            mostRecentlyDeployed
        );
        poolAddressesProvider.setPoolImpl(pool);
        vm.stopBroadcast();
    }

    function setPriceOracle(address mostRecentlyDeployed) public {
        vm.startBroadcast();
        PoolAddressesProvider poolAddressesProvider = PoolAddressesProvider(
            mostRecentlyDeployed
        );
        poolAddressesProvider.setPriceOracle(oracle);
        vm.stopBroadcast();
    }

    function setPoolDataProvider(address mostRecentlyDeployed) public {
        vm.startBroadcast();
        PoolAddressesProvider poolAddressesProvider = PoolAddressesProvider(
            mostRecentlyDeployed
        );
        poolAddressesProvider.setPoolDataProvider(poolDataProvider);
        vm.stopBroadcast();
    }

    function setPoolConfiguratorImpl(address mostRecentlyDeployed) public {
        vm.startBroadcast();
        PoolAddressesProvider poolAddressesProvider = PoolAddressesProvider(
            mostRecentlyDeployed
        );
        poolAddressesProvider.setPoolConfiguratorImpl(poolConfigurator);
        vm.stopBroadcast();
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "PoolAddressesProvider",
            block.chainid
        );
        setPoolImpl(mostRecentlyDeployed);
        setPriceOracle(mostRecentlyDeployed);
        setPoolDataProvider(mostRecentlyDeployed);
        setPoolConfiguratorImpl(mostRecentlyDeployed);
    }
}

// forge script IntegrateAddressesProvider --account defaultKey --sender 0x755AC4E90c24135f1B7f73AeEA6a7ff42b07dd94 --rpc-url $SKALE_TITAN_HUB_RPC_URL --broadcast --legacy
