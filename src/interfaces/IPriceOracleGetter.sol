// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IPriceOracleGetter {
    function BASE_CURRENCY() external view returns (address);

    function BASE_CURRENCY_UNIT() external view returns (uint256);

    function getAssetPrice(address asset) external view returns (uint256);

    function getSourceOfAsset(address asset) external view returns (address);
}
