// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITreasury {
    event NewFundsAdmin(address indexed fundsAdmin);

    function getFundsAdmin() external view returns (address);

    function approve(IERC20 token, address recipient, uint256 amount) external;

    function transfer(IERC20 token, address recipient, uint256 amount) external;

    function setFundsAdmin(address admin) external;
}
