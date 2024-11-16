// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {WadRayMath} from "../libraries/math/WadRayMath.sol";
import {IPool} from "../interfaces/IPool.sol";
import {Errors} from "../libraries/helpers/Errors.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {DebtTokenBase} from "./base/DebtTokenBase.sol";
import {IncentivizedERC20} from "./base/IncentivizedERC20.sol";
import {IStableDebtToken} from "../interfaces/IStableDebtToken.sol";
import {MathUtils} from "../libraries/math/MathUtils.sol";
import {IIncentivesController} from "../interfaces/IIncentivesController.sol";

contract StableDebtToken is DebtTokenBase, IncentivizedERC20, IStableDebtToken {
    using WadRayMath for uint256;
    using SafeCast for uint256;

    mapping(address => uint40) internal _timestamps;

    uint128 internal _avgStableRate;

    uint40 internal _totalSupplyTimestamp;

    constructor(
        IPool pool,
        address underlyingAsset,
        IIncentivesController incentivesController,
        uint8 debtTokenDecimals,
        string memory debtTokenName,
        string memory debtTokenSymbol
    )
        DebtTokenBase()
        IncentivizedERC20(
            pool,
            debtTokenName,
            debtTokenSymbol,
            debtTokenDecimals
        )
    {
        _incentivesController = incentivesController;
        _underlyingAsset = underlyingAsset;
    }

    function getAverageStableRate()
        external
        view
        virtual
        override
        returns (uint256)
    {
        return _avgStableRate;
    }

    function getUserLastUpdated(
        address user
    ) external view virtual override returns (uint40) {
        return _timestamps[user];
    }

    function getUserStableRate(
        address user
    ) external view virtual override returns (uint256) {
        return _userState[user].additionalData;
    }

    function balanceOf(
        address account
    ) public view virtual override returns (uint256) {
        uint256 accountBalance = super.balanceOf(account);
        uint256 stableRate = _userState[account].additionalData;
        if (accountBalance == 0) {
            return 0;
        }
        uint256 cumulatedInterest = MathUtils.calculateCompoundedInterest(
            stableRate,
            _timestamps[account],
            block.timestamp
        );
        return accountBalance.rayMul(cumulatedInterest);
    }

    struct MintLocalVars {
        uint256 previousSupply;
        uint256 nextSupply;
        uint256 amountInRay;
        uint256 currentStableRate;
        uint256 nextStableRate;
        uint256 currentAvgStableRate;
    }

    function mint(
        address user,
        address onBehalfOf,
        uint256 amount,
        uint256 rate
    ) external virtual override onlyPool returns (bool, uint256, uint256) {
        MintLocalVars memory vars;

        if (user != onBehalfOf) {
            _decreaseBorrowAllowance(onBehalfOf, user, amount);
        }

        (
            ,
            uint256 currentBalance,
            uint256 balanceIncrease
        ) = _calculateBalanceIncrease(onBehalfOf);

        vars.previousSupply = totalSupply();
        vars.currentAvgStableRate = _avgStableRate;
        vars.nextSupply = _totalSupply = vars.previousSupply + amount;

        vars.amountInRay = amount.wadToRay();

        vars.currentStableRate = _userState[onBehalfOf].additionalData;
        vars.nextStableRate = (vars.currentStableRate.rayMul(
            currentBalance.wadToRay()
        ) + vars.amountInRay.rayMul(rate)).rayDiv(
                (currentBalance + amount).wadToRay()
            );

        _userState[onBehalfOf].additionalData = vars.nextStableRate.toUint128();

        _totalSupplyTimestamp = _timestamps[onBehalfOf] = uint40(
            block.timestamp
        );

        vars.currentAvgStableRate = _avgStableRate = (
            (vars.currentAvgStableRate.rayMul(vars.previousSupply.wadToRay()) +
                rate.rayMul(vars.amountInRay)).rayDiv(
                    vars.nextSupply.wadToRay()
                )
        ).toUint128();

        uint256 amountToMint = amount + balanceIncrease;
        _mint(onBehalfOf, amountToMint, vars.previousSupply);

        emit Transfer(address(0), onBehalfOf, amountToMint);
        emit Mint(
            user,
            onBehalfOf,
            amountToMint,
            currentBalance,
            balanceIncrease,
            vars.nextStableRate,
            vars.currentAvgStableRate,
            vars.nextSupply
        );

        return (
            currentBalance == 0,
            vars.nextSupply,
            vars.currentAvgStableRate
        );
    }

    function burn(
        address from,
        uint256 amount
    ) external virtual override onlyPool returns (uint256, uint256) {
        (
            ,
            uint256 currentBalance,
            uint256 balanceIncrease
        ) = _calculateBalanceIncrease(from);

        uint256 previousSupply = totalSupply();
        uint256 nextAvgStableRate = 0;
        uint256 nextSupply = 0;
        uint256 userStableRate = _userState[from].additionalData;

        if (previousSupply <= amount) {
            _avgStableRate = 0;
            _totalSupply = 0;
        } else {
            nextSupply = _totalSupply = previousSupply - amount;
            uint256 firstTerm = uint256(_avgStableRate).rayMul(
                previousSupply.wadToRay()
            );
            uint256 secondTerm = userStableRate.rayMul(amount.wadToRay());

            if (secondTerm >= firstTerm) {
                nextAvgStableRate = _totalSupply = _avgStableRate = 0;
            } else {
                nextAvgStableRate = _avgStableRate = (
                    (firstTerm - secondTerm).rayDiv(nextSupply.wadToRay())
                ).toUint128();
            }
        }

        if (amount == currentBalance) {
            _userState[from].additionalData = 0;
            _timestamps[from] = 0;
        } else {
            _timestamps[from] = uint40(block.timestamp);
        }

        _totalSupplyTimestamp = uint40(block.timestamp);

        if (balanceIncrease > amount) {
            uint256 amountToMint = balanceIncrease - amount;
            _mint(from, amountToMint, previousSupply);
            emit Transfer(address(0), from, amountToMint);
            emit Mint(
                from,
                from,
                amountToMint,
                currentBalance,
                balanceIncrease,
                userStableRate,
                nextAvgStableRate,
                nextSupply
            );
        } else {
            uint256 amountToBurn = amount - balanceIncrease;
            _burn(from, amountToBurn, previousSupply);
            emit Transfer(from, address(0), amountToBurn);
            emit Burn(
                from,
                amountToBurn,
                currentBalance,
                balanceIncrease,
                nextAvgStableRate,
                nextSupply
            );
        }

        return (nextSupply, nextAvgStableRate);
    }

    function _calculateBalanceIncrease(
        address user
    ) internal view returns (uint256, uint256, uint256) {
        uint256 previousPrincipalBalance = super.balanceOf(user);

        if (previousPrincipalBalance == 0) {
            return (0, 0, 0);
        }

        uint256 newPrincipalBalance = balanceOf(user);

        return (
            previousPrincipalBalance,
            newPrincipalBalance,
            newPrincipalBalance - previousPrincipalBalance
        );
    }

    function getSupplyData()
        external
        view
        override
        returns (uint256, uint256, uint256, uint40)
    {
        uint256 avgRate = _avgStableRate;
        return (
            super.totalSupply(),
            _calcTotalSupply(avgRate),
            avgRate,
            _totalSupplyTimestamp
        );
    }

    function getTotalSupplyAndAvgRate()
        external
        view
        override
        returns (uint256, uint256)
    {
        uint256 avgRate = _avgStableRate;
        return (_calcTotalSupply(avgRate), avgRate);
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _calcTotalSupply(_avgStableRate);
    }

    function getTotalSupplyLastUpdated()
        external
        view
        override
        returns (uint40)
    {
        return _totalSupplyTimestamp;
    }

    function principalBalanceOf(
        address user
    ) external view virtual override returns (uint256) {
        return super.balanceOf(user);
    }

    function UNDERLYING_ASSET_ADDRESS()
        external
        view
        override
        returns (address)
    {
        return _underlyingAsset;
    }

    function _calcTotalSupply(uint256 avgRate) internal view returns (uint256) {
        uint256 principalSupply = super.totalSupply();

        if (principalSupply == 0) {
            return 0;
        }

        uint256 cumulatedInterest = MathUtils.calculateCompoundedInterest(
            avgRate,
            _totalSupplyTimestamp,
            block.timestamp
        );

        return principalSupply.rayMul(cumulatedInterest);
    }

    function _mint(
        address account,
        uint256 amount,
        uint256 oldTotalSupply
    ) internal {
        uint128 castAmount = amount.toUint128();
        uint128 oldAccountBalance = _userState[account].balance;
        _userState[account].balance = oldAccountBalance + castAmount;

        if (address(_incentivesController) != address(0)) {
            _incentivesController.handleAction(
                account,
                oldTotalSupply,
                oldAccountBalance
            );
        }
    }

    function _burn(
        address account,
        uint256 amount,
        uint256 oldTotalSupply
    ) internal {
        uint128 castAmount = amount.toUint128();
        uint128 oldAccountBalance = _userState[account].balance;
        _userState[account].balance = oldAccountBalance - castAmount;

        if (address(_incentivesController) != address(0)) {
            _incentivesController.handleAction(
                account,
                oldTotalSupply,
                oldAccountBalance
            );
        }
    }

    function _EIP712BaseId() internal view override returns (string memory) {
        return name();
    }

    function transfer(
        address,
        uint256
    ) external virtual override returns (bool) {
        revert(Errors.OPERATION_NOT_SUPPORTED);
    }

    function allowance(
        address,
        address
    ) external view virtual override returns (uint256) {
        revert(Errors.OPERATION_NOT_SUPPORTED);
    }

    function approve(
        address,
        uint256
    ) external virtual override returns (bool) {
        revert(Errors.OPERATION_NOT_SUPPORTED);
    }

    function transferFrom(
        address,
        address,
        uint256
    ) external virtual override returns (bool) {
        revert(Errors.OPERATION_NOT_SUPPORTED);
    }

    function increaseAllowance(
        address,
        uint256
    ) external virtual override returns (bool) {
        revert(Errors.OPERATION_NOT_SUPPORTED);
    }

    function decreaseAllowance(
        address,
        uint256
    ) external virtual override returns (bool) {
        revert(Errors.OPERATION_NOT_SUPPORTED);
    }
}
