// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {DataTypes} from "../types/DataTypes.sol";
import {WadRayMath} from "../math/WadRayMath.sol";
import {PercentageMath} from "../math/PercentageMath.sol";
import {Errors} from "../helpers/Errors.sol";
import {ReserveConfiguration} from "../configuration/ReserveConfiguration.sol";
import {IVariableDebtToken} from "../../interfaces/IVariableDebtToken.sol";
import {IStableDebtToken} from "../../interfaces/IStableDebtToken.sol";
import {MathUtils} from "../math/MathUtils.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IReserveInterestRateStrategy} from "../../interfaces/IReserveInterestRateStrategy.sol";

library ReserveLogic {
    using WadRayMath for uint256;
    using SafeCast for uint256;
    using PercentageMath for uint256;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    event ReserveDataUpdated(
        address indexed reserve,
        uint256 liquidityRate,
        uint256 stableBorrowRate,
        uint256 variableBorrowRate,
        uint256 liquidityIndex,
        uint256 variableBorrowIndex
    );

    function init(
        DataTypes.ReserveData storage reserve,
        address aTokenAddress,
        address stableDebtTokenAddress,
        address variableDebtTokenAddress,
        address interestRateStrategyAddress
    ) internal {
        require(
            reserve.aTokenAddress == address(0),
            Errors.RESERVE_ALREADY_INITIALIZED
        );

        reserve.liquidityIndex = uint128(WadRayMath.RAY);
        reserve.variableBorrowIndex = uint128(WadRayMath.RAY);
        reserve.aTokenAddress = aTokenAddress;
        reserve.stableDebtTokenAddress = stableDebtTokenAddress;
        reserve.variableDebtTokenAddress = variableDebtTokenAddress;
        reserve.interestRateStrategyAddress = interestRateStrategyAddress;
    }

    function getNormalizedDebt(
        DataTypes.ReserveData storage reserve
    ) internal view returns (uint256) {
        uint40 timestamp = reserve.lastUpdateTimestamp;

        //solium-disable-next-line
        if (timestamp == block.timestamp) {
            return reserve.variableBorrowIndex;
        } else {
            return
                MathUtils
                    .calculateCompoundedInterest(
                        reserve.currentVariableBorrowRate,
                        timestamp,
                        block.timestamp
                    )
                    .rayMul(reserve.variableBorrowIndex);
        }
    }

    function getNormalizedIncome(
        DataTypes.ReserveData storage reserve
    ) internal view returns (uint256) {
        uint40 timestamp = reserve.lastUpdateTimestamp;

        //solium-disable-next-line
        if (timestamp == block.timestamp) {
            return reserve.liquidityIndex;
        } else {
            return
                MathUtils
                    .calculateLinearInterest(
                        reserve.currentLiquidityRate,
                        timestamp
                    )
                    .rayMul(reserve.liquidityIndex);
        }
    }

    struct UpdateInterestRatesLocalVars {
        uint256 nextLiquidityRate;
        uint256 nextStableRate;
        uint256 nextVariableRate;
        uint256 totalVariableDebt;
    }

    function updateInterestRates(
        DataTypes.ReserveData storage reserve,
        DataTypes.ReserveCache memory reserveCache,
        address reserveAddress,
        uint256 liquidityAdded,
        uint256 liquidityTaken
    ) internal {
        UpdateInterestRatesLocalVars memory vars;

        vars.totalVariableDebt = reserveCache.nextScaledVariableDebt.rayMul(
            reserveCache.nextVariableBorrowIndex
        );

        (
            vars.nextLiquidityRate,
            vars.nextStableRate,
            vars.nextVariableRate
        ) = IReserveInterestRateStrategy(reserve.interestRateStrategyAddress)
            .calculateInterestRates(
                DataTypes.CalculateInterestRatesParams({
                    unbacked: reserve.unbacked,
                    liquidityAdded: liquidityAdded,
                    liquidityTaken: liquidityTaken,
                    totalStableDebt: reserveCache.nextTotalStableDebt,
                    totalVariableDebt: vars.totalVariableDebt,
                    averageStableBorrowRate: reserveCache
                        .nextAvgStableBorrowRate,
                    reserveFactor: reserveCache.reserveFactor,
                    reserve: reserveAddress,
                    aToken: reserveCache.aTokenAddress
                })
            );

        reserve.currentLiquidityRate = vars.nextLiquidityRate.toUint128();
        reserve.currentStableBorrowRate = vars.nextStableRate.toUint128();
        reserve.currentVariableBorrowRate = vars.nextVariableRate.toUint128();

        emit ReserveDataUpdated(
            reserveAddress,
            vars.nextLiquidityRate,
            vars.nextStableRate,
            vars.nextVariableRate,
            reserveCache.nextLiquidityIndex,
            reserveCache.nextVariableBorrowIndex
        );
    }

    function updateState(
        DataTypes.ReserveData storage reserve,
        DataTypes.ReserveCache memory reserveCache
    ) internal {
        if (reserve.lastUpdateTimestamp == uint40(block.timestamp)) {
            return;
        }

        _updateIndexes(reserve, reserveCache);
        _accrueToTreasury(reserve, reserveCache);

        reserve.lastUpdateTimestamp = uint40(block.timestamp);
    }

    function cache(
        DataTypes.ReserveData storage reserve
    ) internal view returns (DataTypes.ReserveCache memory) {
        DataTypes.ReserveCache memory reserveCache;

        reserveCache.reserveConfiguration = reserve.configuration;
        reserveCache.reserveFactor = reserveCache
            .reserveConfiguration
            .getReserveFactor();
        reserveCache.currLiquidityIndex = reserveCache
            .nextLiquidityIndex = reserve.liquidityIndex;
        reserveCache.currVariableBorrowIndex = reserveCache
            .nextVariableBorrowIndex = reserve.variableBorrowIndex;
        reserveCache.currLiquidityRate = reserve.currentLiquidityRate;
        reserveCache.currVariableBorrowRate = reserve.currentVariableBorrowRate;

        reserveCache.aTokenAddress = reserve.aTokenAddress;
        reserveCache.stableDebtTokenAddress = reserve.stableDebtTokenAddress;
        reserveCache.variableDebtTokenAddress = reserve
            .variableDebtTokenAddress;

        reserveCache.reserveLastUpdateTimestamp = reserve.lastUpdateTimestamp;

        reserveCache.currScaledVariableDebt = reserveCache
            .nextScaledVariableDebt = IVariableDebtToken(
            reserveCache.variableDebtTokenAddress
        ).scaledTotalSupply();

        (
            reserveCache.currPrincipalStableDebt,
            reserveCache.currTotalStableDebt,
            reserveCache.currAvgStableBorrowRate,
            reserveCache.stableDebtLastUpdateTimestamp
        ) = IStableDebtToken(reserveCache.stableDebtTokenAddress)
            .getSupplyData();

        reserveCache.nextTotalStableDebt = reserveCache.currTotalStableDebt;
        reserveCache.nextAvgStableBorrowRate = reserveCache
            .currAvgStableBorrowRate;

        return reserveCache;
    }

    function _updateIndexes(
        DataTypes.ReserveData storage reserve,
        DataTypes.ReserveCache memory reserveCache
    ) internal {
        if (reserveCache.currLiquidityRate != 0) {
            uint256 cumulatedLiquidityInterest = MathUtils
                .calculateLinearInterest(
                    reserveCache.currLiquidityRate,
                    reserveCache.reserveLastUpdateTimestamp
                );
            reserveCache.nextLiquidityIndex = cumulatedLiquidityInterest.rayMul(
                reserveCache.currLiquidityIndex
            );
            reserve.liquidityIndex = reserveCache
                .nextLiquidityIndex
                .toUint128();
        }
    }

    struct AccrueToTreasuryLocalVars {
        uint256 prevTotalStableDebt;
        uint256 prevTotalVariableDebt;
        uint256 currTotalVariableDebt;
        uint256 cumulatedStableInterest;
        uint256 totalDebtAccrued;
        uint256 amountToMint;
    }

    function _accrueToTreasury(
        DataTypes.ReserveData storage reserve,
        DataTypes.ReserveCache memory reserveCache
    ) internal {
        AccrueToTreasuryLocalVars memory vars;

        if (reserveCache.reserveFactor == 0) {
            return;
        }

        vars.prevTotalVariableDebt = reserveCache.currScaledVariableDebt.rayMul(
            reserveCache.currVariableBorrowIndex
        );

        vars.currTotalVariableDebt = reserveCache.currScaledVariableDebt.rayMul(
            reserveCache.nextVariableBorrowIndex
        );

        vars.cumulatedStableInterest = MathUtils.calculateCompoundedInterest(
            reserveCache.currAvgStableBorrowRate,
            reserveCache.stableDebtLastUpdateTimestamp,
            reserveCache.reserveLastUpdateTimestamp
        );

        vars.prevTotalStableDebt = reserveCache.currPrincipalStableDebt.rayMul(
            vars.cumulatedStableInterest
        );

        vars.totalDebtAccrued =
            vars.currTotalVariableDebt +
            reserveCache.currTotalStableDebt -
            vars.prevTotalVariableDebt -
            vars.prevTotalStableDebt;

        vars.amountToMint = vars.totalDebtAccrued.percentMul(
            reserveCache.reserveFactor
        );

        if (vars.amountToMint != 0) {
            reserve.accruedToTreasury += vars
                .amountToMint
                .rayDiv(reserveCache.nextLiquidityIndex)
                .toUint128();
        }
    }
}
