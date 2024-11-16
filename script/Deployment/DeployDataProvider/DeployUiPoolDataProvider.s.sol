// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UiPoolDataProvider} from "../../src/dataProvider/UiPoolDataProvider.sol";
import {Script} from "forge-std/Script.sol";

contract DeployUiPoolDataProvider is Script {
    function run() external returns (UiPoolDataProvider) {
        vm.startBroadcast();
        UiPoolDataProvider uiPoolDataProvider = new UiPoolDataProvider();
        vm.stopBroadcast();
        return uiPoolDataProvider;
    }
}
// 0x71dADf278c709369D49ADecD245f48A726569ff3
