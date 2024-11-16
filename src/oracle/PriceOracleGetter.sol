// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IPriceOracleGetter} from "../interfaces/IPriceOracleGetter.sol";
import {ISkalePriceFeed} from "./Interface/ISkalePriceFeed.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Errors} from "../libraries/helpers/Errors.sol";

contract PriceOracleGetter is IPriceOracleGetter, Ownable {
    mapping(address => address) assetsSources;
    address private immutable i_owner;

    constructor(address owner) Ownable(owner) {
        i_owner = owner;
    }

    function BASE_CURRENCY() external pure returns (address) {
        return address(0);
    }

    function BASE_CURRENCY_UNIT() external pure returns (uint256) {
        return 1 ether;
    }

    function getAssetPrice(address asset) external view returns (uint256) {
        address priceFeed = assetsSources[asset];
        (, int256 answer, , , ) = ISkalePriceFeed(priceFeed).latestRoundData();
        return uint256(answer);
    }

    function getSourceOfAsset(
        address asset
    ) external view override returns (address) {
        return address(assetsSources[asset]);
    }

    function setAssetToPriceFeed(
        address asset,
        address priceFeedAddress
    ) external onlyOwner {
        require(asset != address(0), "Invalid Asset Address");
        require(priceFeedAddress != address(0), "Invalid Price Feed Address");
        assetsSources[asset] = priceFeedAddress;
    }

    function getOwner() external view returns (address) {
        return i_owner;
    }
}
