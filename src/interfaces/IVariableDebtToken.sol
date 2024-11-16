// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./IScaledBalanceToken.sol";

interface IVariableDebtToken is IScaledBalanceToken {
    function mint(
        address user,
        address onBehalfOf,
        uint256 amount,
        uint256 index
    ) external returns (bool, uint256);

    function burn(
        address from,
        uint256 amount,
        uint256 index
    ) external returns (uint256);

    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
}
