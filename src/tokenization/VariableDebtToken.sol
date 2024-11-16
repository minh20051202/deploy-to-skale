// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {DebtTokenBase} from "./base/DebtTokenBase.sol";
import {ScaledBalanceTokenBase} from "./base/ScaledBalanceTokenBase.sol";
import {WadRayMath} from "../libraries/math/WadRayMath.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IPool} from "../interfaces/IPool.sol";
import {IIncentivesController} from "../interfaces/IIncentivesController.sol";
import {Errors} from "../libraries/helpers/Errors.sol";
import {IVariableDebtToken} from "../interfaces/IVariableDebtToken.sol";

contract VariableDebtToken is
    DebtTokenBase,
    ScaledBalanceTokenBase,
    IVariableDebtToken
{
    using WadRayMath for uint256;
    using SafeCast for uint256;

    constructor(
        IPool pool,
        address underlyingAsset,
        IIncentivesController incentivesController,
        uint8 debtTokenDecimals,
        string memory debtTokenName,
        string memory debtTokenSymbol
    )
        DebtTokenBase()
        ScaledBalanceTokenBase(
            pool,
            debtTokenName,
            debtTokenSymbol,
            debtTokenDecimals
        )
    {
        _incentivesController = incentivesController;
        _underlyingAsset = underlyingAsset;
    }

    function balanceOf(
        address user
    ) public view virtual override returns (uint256) {
        uint256 scaledBalance = super.balanceOf(user);

        if (scaledBalance == 0) {
            return 0;
        }

        return
            scaledBalance.rayMul(
                POOL.getReserveNormalizedVariableDebt(_underlyingAsset)
            );
    }

    function mint(
        address user,
        address onBehalfOf,
        uint256 amount,
        uint256 index
    ) external onlyPool returns (bool, uint256) {
        if (user != onBehalfOf) {
            _decreaseBorrowAllowance(onBehalfOf, user, amount);
        }
        return (
            _mintScaled(user, onBehalfOf, amount, index),
            scaledTotalSupply()
        );
    }

    function burn(
        address from,
        uint256 amount,
        uint256 index
    ) external onlyPool returns (uint256) {
        _burnScaled(from, address(0), amount, index);
        return scaledTotalSupply();
    }

    function totalSupply() public view virtual override returns (uint256) {
        return
            super.totalSupply().rayMul(
                POOL.getReserveNormalizedVariableDebt(_underlyingAsset)
            );
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

    function UNDERLYING_ASSET_ADDRESS() external view returns (address) {
        return _underlyingAsset;
    }
}
