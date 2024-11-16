// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IScaledBalanceToken} from "./IScaledBalanceToken.sol";

interface IAToken is IERC20, IScaledBalanceToken {
    event BalanceTransfer(
        address indexed from,
        address indexed to,
        uint256 value,
        uint256 index
    );

    function mint(
        address caller,
        address onBehalfOf,
        uint256 amount,
        uint256 index
    ) external returns (bool);

    function burn(
        address from,
        address receiverOfUnderlying,
        uint256 amount,
        uint256 index
    ) external;

    function mintToTreasury(uint256 amount, uint256 index) external;

    function transferOnLiquidation(
        address from,
        address to,
        uint256 value
    ) external;

    function transferUnderlyingTo(address target, uint256 amount) external;

    function handleRepayment(
        address user,
        address onBehalfOf,
        uint256 amount
    ) external;

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function UNDERLYING_ASSET_ADDRESS() external view returns (address);

    function RESERVE_TREASURY_ADDRESS() external view returns (address);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function nonces(address owner) external view returns (uint256);

    function rescueTokens(address token, address to, uint256 amount) external;
}
