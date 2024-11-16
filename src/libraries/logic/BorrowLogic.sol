// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {DataTypes} from "../types/DataTypes.sol";
import {ReserveLogic} from "../logic/ReserveLogic.sol";
import {ValidationLogic} from "../logic/ValidationLogic.sol";
import {UserConfiguration} from "../configuration/UserConfiguration.sol";
import {ReserveConfiguration} from "../configuration/ReserveConfiguration.sol";
import {IVariableDebtToken} from "../../interfaces/IVariableDebtToken.sol";
import {IStableDebtToken} from "../../interfaces/IStableDebtToken.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IAToken} from "../../interfaces/IAToken.sol";
import {Helpers} from "../helpers/Helpers.sol";

import {IsolationModeLogic} from "../logic/IsolationModeLogic.sol";

library BorrowLogic {
    using ReserveLogic for DataTypes.ReserveCache;
    using ReserveLogic for DataTypes.ReserveData;
    using UserConfiguration for DataTypes.UserConfigurationMap;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

    event Borrow(
        address indexed reserve,
        address user,
        address indexed onBehalfOf,
        uint256 amount,
        DataTypes.InterestRateMode interestRateMode,
        uint256 borrowRate,
        uint16 indexed referralCode
    );

    event Repay(
        address indexed reserve,
        address indexed user,
        address indexed repayer,
        uint256 amount,
        bool useATokens
    );

    event IsolationModeTotalDebtUpdated(
        address indexed asset,
        uint256 totalDebt
    );

    function executeBorrow(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        mapping(uint8 => DataTypes.EModeCategory) storage eModeCategories,
        DataTypes.UserConfigurationMap storage userConfig,
        DataTypes.ExecuteBorrowParams memory params
    ) public {
        DataTypes.ReserveData storage reserve = reservesData[params.asset];
        DataTypes.ReserveCache memory reserveCache = reserve.cache();

        reserve.updateState(reserveCache);

        (
            bool isolationModeActive,
            address isolationModeCollateralAddress,
            uint256 isolationModeDebtCeiling
        ) = userConfig.getIsolationModeState(reservesData, reservesList);

        ValidationLogic.validateBorrow(
            reservesData,
            reservesList,
            eModeCategories,
            DataTypes.ValidateBorrowParams({
                reserveCache: reserveCache,
                userConfig: userConfig,
                asset: params.asset,
                userAddress: params.onBehalfOf,
                amount: params.amount,
                interestRateMode: params.interestRateMode,
                maxStableLoanPercent: params.maxStableRateBorrowSizePercent,
                reservesCount: params.reservesCount,
                oracle: params.oracle,
                userEModeCategory: params.userEModeCategory,
                priceOracleSentinel: params.priceOracleSentinel,
                isolationModeActive: isolationModeActive,
                isolationModeCollateralAddress: isolationModeCollateralAddress,
                isolationModeDebtCeiling: isolationModeDebtCeiling
            })
        );

        uint256 currentStableRate = 0;
        bool isFirstBorrowing = false;

        if (params.interestRateMode == DataTypes.InterestRateMode.STABLE) {
            currentStableRate = reserve.currentStableBorrowRate;

            (
                isFirstBorrowing,
                reserveCache.nextTotalStableDebt,
                reserveCache.nextAvgStableBorrowRate
            ) = IStableDebtToken(reserveCache.stableDebtTokenAddress).mint(
                params.user,
                params.onBehalfOf,
                params.amount,
                currentStableRate
            );
        } else {
            (
                isFirstBorrowing,
                reserveCache.nextScaledVariableDebt
            ) = IVariableDebtToken(reserveCache.variableDebtTokenAddress).mint(
                params.user,
                params.onBehalfOf,
                params.amount,
                reserveCache.nextVariableBorrowIndex
            );
        }

        if (isFirstBorrowing) {
            userConfig.setBorrowing(reserve.id, true);
        }

        if (isolationModeActive) {
            uint256 nextIsolationModeTotalDebt = reservesData[
                isolationModeCollateralAddress
            ].isolationModeTotalDebt += (params.amount /
                10 **
                    (reserveCache.reserveConfiguration.getDecimals() -
                        ReserveConfiguration.DEBT_CEILING_DECIMALS))
                .toUint128();
            emit IsolationModeTotalDebtUpdated(
                isolationModeCollateralAddress,
                nextIsolationModeTotalDebt
            );
        }

        reserve.updateInterestRates(
            reserveCache,
            params.asset,
            0,
            params.releaseUnderlying ? params.amount : 0
        );

        if (params.releaseUnderlying) {
            IAToken(reserveCache.aTokenAddress).transferUnderlyingTo(
                params.user,
                params.amount
            );
        }

        emit Borrow(
            params.asset,
            params.user,
            params.onBehalfOf,
            params.amount,
            params.interestRateMode,
            params.interestRateMode == DataTypes.InterestRateMode.STABLE
                ? currentStableRate
                : reserve.currentVariableBorrowRate,
            params.referralCode
        );
    }

    function executeRepay(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        DataTypes.UserConfigurationMap storage userConfig,
        DataTypes.ExecuteRepayParams memory params
    ) external returns (uint256) {
        DataTypes.ReserveData storage reserve = reservesData[params.asset];
        DataTypes.ReserveCache memory reserveCache = reserve.cache();
        reserve.updateState(reserveCache);

        (uint256 stableDebt, uint256 variableDebt) = Helpers.getUserCurrentDebt(
            params.onBehalfOf,
            reserveCache
        );

        ValidationLogic.validateRepay(
            reserveCache,
            params.amount,
            params.interestRateMode,
            params.onBehalfOf,
            stableDebt,
            variableDebt
        );

        uint256 paybackAmount = params.interestRateMode ==
            DataTypes.InterestRateMode.STABLE
            ? stableDebt
            : variableDebt;

        // Allows a user to repay with aTokens without leaving dust from interest.
        if (params.useATokens && params.amount == type(uint256).max) {
            params.amount = IAToken(reserveCache.aTokenAddress).balanceOf(
                msg.sender
            );
        }

        if (params.amount < paybackAmount) {
            paybackAmount = params.amount;
        }

        if (params.interestRateMode == DataTypes.InterestRateMode.STABLE) {
            (
                reserveCache.nextTotalStableDebt,
                reserveCache.nextAvgStableBorrowRate
            ) = IStableDebtToken(reserveCache.stableDebtTokenAddress).burn(
                params.onBehalfOf,
                paybackAmount
            );
        } else {
            reserveCache.nextScaledVariableDebt = IVariableDebtToken(
                reserveCache.variableDebtTokenAddress
            ).burn(
                    params.onBehalfOf,
                    paybackAmount,
                    reserveCache.nextVariableBorrowIndex
                );
        }

        reserve.updateInterestRates(
            reserveCache,
            params.asset,
            params.useATokens ? 0 : paybackAmount,
            0
        );

        if (stableDebt + variableDebt - paybackAmount == 0) {
            userConfig.setBorrowing(reserve.id, false);
        }

        IsolationModeLogic.updateIsolatedDebtIfIsolated(
            reservesData,
            reservesList,
            userConfig,
            reserveCache,
            paybackAmount
        );

        if (params.useATokens) {
            IAToken(reserveCache.aTokenAddress).burn(
                msg.sender,
                reserveCache.aTokenAddress,
                paybackAmount,
                reserveCache.nextLiquidityIndex
            );
        } else {
            IERC20(params.asset).safeTransferFrom(
                msg.sender,
                reserveCache.aTokenAddress,
                paybackAmount
            );
            IAToken(reserveCache.aTokenAddress).handleRepayment(
                msg.sender,
                params.onBehalfOf,
                paybackAmount
            );
        }

        emit Repay(
            params.asset,
            params.onBehalfOf,
            msg.sender,
            paybackAmount,
            params.useATokens
        );

        return paybackAmount;
    }
}
