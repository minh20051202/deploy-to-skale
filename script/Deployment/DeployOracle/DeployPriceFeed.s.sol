// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SkalePriceFeed} from "../../../src/oracle/SkalePriceFeed.sol";
import {Script} from "forge-std/Script.sol";

contract DeploySkalePriceFeed is Script {
    function run() external returns (SkalePriceFeed) {
        vm.startBroadcast();
        SkalePriceFeed skalePriceFeed = new SkalePriceFeed(
            18,
            "ETH/USD",
            0x755AC4E90c24135f1B7f73AeEA6a7ff42b07dd94
        );
        vm.stopBroadcast();
        return skalePriceFeed;
    }
}
// forge script DeployPoolAddressesProvider --account defaultKey --sender 0x755AC4E90c24135f1B7f73AeEA6a7ff42b07dd94 --rpc-url $SKALE_TITAN_HUB_RPC_URL --broadcast --legacy
/* BTC/USD: 0xe8f08137Fd9787208D9b5B81235390eFAEeB81d5
   ETH/USD: 0x09aC113C5f84D769B2e3143d4c562e07A4De1d92
*/
