// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IStableDebtToken {
    event Mint(
        address indexed user,
        address indexed onBehalfOf,
        uint256 amount,
        uint256 currentBalance,
        uint256 balanceIncrease,
        uint256 newRate,
        uint256 avgStableRate,
        uint256 newTotalSupply
    );

    event Burn(
        address indexed from,
        uint256 amount,
        uint256 currentBalance,
        uint256 balanceIncrease,
        uint256 avgStableRate,
        uint256 newTotalSupply
    );

    function mint(
        address user,
        address onBehalfOf,
        uint256 amount,
        uint256 rate
    ) external returns (bool, uint256, uint256);

    function burn(
        address from,
        uint256 amount
    ) external returns (uint256, uint256);

    function getAverageStableRate() external view returns (uint256);

    function getUserStableRate(address user) external view returns (uint256);

    function getUserLastUpdated(address user) external view returns (uint40);

    function getSupplyData()
        external
        view
        returns (uint256, uint256, uint256, uint40);

    function getTotalSupplyLastUpdated() external view returns (uint40);

    function getTotalSupplyAndAvgRate()
        external
        view
        returns (uint256, uint256);

    function principalBalanceOf(address user) external view returns (uint256);

    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
}
