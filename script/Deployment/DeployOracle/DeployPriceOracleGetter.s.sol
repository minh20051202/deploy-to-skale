// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {PriceOracleGetter} from "../../../src/oracle/PriceOracleGetter.sol";
import {Script} from "forge-std/Script.sol";

contract DeployPriceOracleGetter is Script {
    function run() external returns (PriceOracleGetter) {
        vm.startBroadcast();
        PriceOracleGetter priceOracleGetter = new PriceOracleGetter(
            0x755AC4E90c24135f1B7f73AeEA6a7ff42b07dd94
        );
        vm.stopBroadcast();
        return priceOracleGetter;
    }
}
// forge script DeployPoolAddressesProvider --account defaultKey --sender 0x755AC4E90c24135f1B7f73AeEA6a7ff42b07dd94 --rpc-url $SKALE_TITAN_HUB_RPC_URL --broadcast --legacy
// 0x8CAb6A8589Ab05e7277177CA1cD7f28594D75800
