//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {PriceOracleGetter} from "../../../src/oracle/PriceOracleGetter.sol";
import {Script} from "forge-std/Script.sol";

contract SetAssetToPriceFeed is Script {
    address btcAsset = 0xe8f08137Fd9787208D9b5B81235390eFAEeB81d5;
    address btcPriceFeedAddress = 0xe8f08137Fd9787208D9b5B81235390eFAEeB81d5;

    function setAssetToPriceFeed(address mostRecentlyDeployed) public {
        vm.startBroadcast();
        PriceOracleGetter priceOracleGetter = PriceOracleGetter(
            mostRecentlyDeployed
        );
        priceOracleGetter.setAssetToPriceFeed(btcAsset, btcPriceFeedAddress);
        vm.stopBroadcast();
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "PriceOracleGetter",
            block.chainid
        );
        setAssetToPriceFeed(mostRecentlyDeployed);
    }
}

// forge script SetAssetToPriceFeed --account defaultKey --sender 0x755AC4E90c24135f1B7f73AeEA6a7ff42b07dd94 --rpc-url $SKALE_TITAN_HUB_RPC_URL --broadcast --legacy
