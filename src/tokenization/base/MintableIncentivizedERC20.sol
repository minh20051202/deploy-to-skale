// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IncentivizedERC20} from "./IncentivizedERC20.sol";
import {IPool} from "../../interfaces/IPool.sol";
import {IIncentivesController} from "../../interfaces/IIncentivesController.sol";

contract MintableIncentivizedERC20 is IncentivizedERC20 {
    constructor(
        IPool pool,
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) IncentivizedERC20(pool, name_, symbol_, decimals_) {}

    function _mint(address account, uint128 amount) internal virtual {
        uint256 oldTotalSupply = _totalSupply;
        _totalSupply = oldTotalSupply + amount;

        uint128 oldAccountBalance = _userState[account].balance;
        _userState[account].balance = oldAccountBalance + amount;

        IIncentivesController incentivesControllerLocal = _incentivesController;

        if (address(incentivesControllerLocal) != address(0)) {
            incentivesControllerLocal.handleAction(
                account,
                oldTotalSupply,
                oldAccountBalance
            );
        }
    }

    function _burn(address account, uint128 amount) internal virtual {
        uint256 oldTotalSupply = _totalSupply;
        _totalSupply = oldTotalSupply - amount;

        uint128 oldAccountBalance = _userState[account].balance;
        _userState[account].balance = oldAccountBalance - amount;

        IIncentivesController incentivesControllerLocal = _incentivesController;

        if (address(incentivesControllerLocal) != address(0)) {
            incentivesControllerLocal.handleAction(
                account,
                oldTotalSupply,
                oldAccountBalance
            );
        }
    }
}
