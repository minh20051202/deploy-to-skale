// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ITreasury} from "./interfaces/ITreasury.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Treasury is ITreasury {
    address internal _fundsAdmin;

    modifier onlyFundsAdmin() {
        require(msg.sender == _fundsAdmin, "ONLY_BY_FUNDS_ADMIN");
        _;
    }

    constructor(address reserveController) {
        _setFundsAdmin(reserveController);
    }

    function getFundsAdmin() external view returns (address) {
        return _fundsAdmin;
    }

    function approve(
        IERC20 token,
        address recipient,
        uint256 amount
    ) external onlyFundsAdmin {
        token.approve(recipient, amount);
    }

    function transfer(
        IERC20 token,
        address recipient,
        uint256 amount
    ) external onlyFundsAdmin {
        token.transfer(recipient, amount);
    }

    function setFundsAdmin(address admin) external onlyFundsAdmin {
        _setFundsAdmin(admin);
    }

    function _setFundsAdmin(address admin) internal {
        _fundsAdmin = admin;
        emit NewFundsAdmin(admin);
    }
}
