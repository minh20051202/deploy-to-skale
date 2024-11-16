// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {DataTypes} from "../types/DataTypes.sol";
import {EModeLogic} from "./EModeLogic.sol";
import {IPriceOracleGetter} from "../../interfaces/IPriceOracleGetter.sol";
import {IScaledBalanceToken} from "../../interfaces/IScaledBalanceToken.sol";
import {ReserveLogic} from "./ReserveLogic.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReserveConfiguration} from "../configuration/ReserveConfiguration.sol";
import {UserConfiguration} from "../configuration/UserConfiguration.sol";
import {PercentageMath} from "../math/PercentageMath.sol";
import {WadRayMath} from "../math/WadRayMath.sol";

library GenericLogic {
    using ReserveLogic for DataTypes.ReserveData;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using UserConfiguration for DataTypes.UserConfigurationMap;
    using WadRayMath for uint256;
    using PercentageMath for uint256;

    struct CalculateUserAccountDataVars {
        uint256 assetPrice;
        uint256 assetUnit;
        uint256 userBalanceInBaseCurrency;
        uint256 decimals;
        uint256 ltv;
        uint256 liquidationThreshold;
        uint256 i;
        uint256 healthFactor;
        uint256 totalCollateralInBaseCurrency;
        uint256 totalDebtInBaseCurrency;
        uint256 avgLtv;
        uint256 avgLiquidationThreshold;
        uint256 eModeAssetPrice;
        uint256 eModeLtv;
        uint256 eModeLiqThreshold;
        uint256 eModeAssetCategory;
        address currentReserveAddress;
        bool hasZeroLtvCollateral;
        bool isInEModeCategory;
    }

    function calculateUserAccountData(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        mapping(uint8 => DataTypes.EModeCategory) storage eModeCategories,
        DataTypes.CalculateUserAccountDataParams memory params
    )
        internal
        view
        returns (uint256, uint256, uint256, uint256, uint256, bool)
    {
        if (params.userConfig.isEmpty()) {
            return (0, 0, 0, 0, type(uint256).max, false);
        }

        CalculateUserAccountDataVars memory vars;

        if (params.userEModeCategory != 0) {
            (
                vars.eModeLtv,
                vars.eModeLiqThreshold,
                vars.eModeAssetPrice
            ) = EModeLogic.getEModeConfiguration(
                eModeCategories[params.userEModeCategory],
                IPriceOracleGetter(params.oracle)
            );
        }

        while (vars.i < params.reservesCount) {
            if (!params.userConfig.isUsingAsCollateralOrBorrowing(vars.i)) {
                unchecked {
                    ++vars.i;
                }
                continue;
            }

            vars.currentReserveAddress = reservesList[vars.i];

            if (vars.currentReserveAddress == address(0)) {
                unchecked {
                    ++vars.i;
                }
                continue;
            }

            DataTypes.ReserveData storage currentReserve = reservesData[
                vars.currentReserveAddress
            ];

            (
                vars.ltv,
                vars.liquidationThreshold,
                ,
                vars.decimals,
                ,
                vars.eModeAssetCategory
            ) = currentReserve.configuration.getParams();

            unchecked {
                vars.assetUnit = 10 ** vars.decimals;
            }

            vars.assetPrice = vars.eModeAssetPrice != 0 &&
                params.userEModeCategory == vars.eModeAssetCategory
                ? vars.eModeAssetPrice
                : IPriceOracleGetter(params.oracle).getAssetPrice(
                    vars.currentReserveAddress
                );

            if (
                vars.liquidationThreshold != 0 &&
                params.userConfig.isUsingAsCollateral(vars.i)
            ) {
                vars.userBalanceInBaseCurrency = _getUserBalanceInBaseCurrency(
                    params.user,
                    currentReserve,
                    vars.assetPrice,
                    vars.assetUnit
                );

                vars.totalCollateralInBaseCurrency += vars
                    .userBalanceInBaseCurrency;

                vars.isInEModeCategory = EModeLogic.isInEModeCategory(
                    params.userEModeCategory,
                    vars.eModeAssetCategory
                );

                if (vars.ltv != 0) {
                    vars.avgLtv +=
                        vars.userBalanceInBaseCurrency *
                        (vars.isInEModeCategory ? vars.eModeLtv : vars.ltv);
                } else {
                    vars.hasZeroLtvCollateral = true;
                }

                vars.avgLiquidationThreshold +=
                    vars.userBalanceInBaseCurrency *
                    (
                        vars.isInEModeCategory
                            ? vars.eModeLiqThreshold
                            : vars.liquidationThreshold
                    );
            }

            if (params.userConfig.isBorrowing(vars.i)) {
                vars.totalDebtInBaseCurrency += _getUserDebtInBaseCurrency(
                    params.user,
                    currentReserve,
                    vars.assetPrice,
                    vars.assetUnit
                );
            }

            unchecked {
                ++vars.i;
            }
        }

        unchecked {
            vars.avgLtv = vars.totalCollateralInBaseCurrency != 0
                ? vars.avgLtv / vars.totalCollateralInBaseCurrency
                : 0;
            vars.avgLiquidationThreshold = vars.totalCollateralInBaseCurrency !=
                0
                ? vars.avgLiquidationThreshold /
                    vars.totalCollateralInBaseCurrency
                : 0;
        }

        vars.healthFactor = (vars.totalDebtInBaseCurrency == 0)
            ? type(uint256).max
            : (
                vars.totalCollateralInBaseCurrency.percentMul(
                    vars.avgLiquidationThreshold
                )
            ).wadDiv(vars.totalDebtInBaseCurrency);
        return (
            vars.totalCollateralInBaseCurrency,
            vars.totalDebtInBaseCurrency,
            vars.avgLtv,
            vars.avgLiquidationThreshold,
            vars.healthFactor,
            vars.hasZeroLtvCollateral
        );
    }

    function calculateAvailableBorrows(
        uint256 totalCollateralInBaseCurrency,
        uint256 totalDebtInBaseCurrency,
        uint256 ltv
    ) internal pure returns (uint256) {
        uint256 availableBorrowsInBaseCurrency = totalCollateralInBaseCurrency
            .percentMul(ltv);

        if (availableBorrowsInBaseCurrency < totalDebtInBaseCurrency) {
            return 0;
        }

        availableBorrowsInBaseCurrency =
            availableBorrowsInBaseCurrency -
            totalDebtInBaseCurrency;
        return availableBorrowsInBaseCurrency;
    }

    function _getUserDebtInBaseCurrency(
        address user,
        DataTypes.ReserveData storage reserve,
        uint256 assetPrice,
        uint256 assetUnit
    ) private view returns (uint256) {
        // fetching variable debt
        uint256 userTotalDebt = IScaledBalanceToken(
            reserve.variableDebtTokenAddress
        ).scaledBalanceOf(user);
        if (userTotalDebt != 0) {
            userTotalDebt = userTotalDebt.rayMul(reserve.getNormalizedDebt());
        }

        userTotalDebt =
            userTotalDebt +
            IERC20(reserve.stableDebtTokenAddress).balanceOf(user);

        userTotalDebt = assetPrice * userTotalDebt;

        unchecked {
            return userTotalDebt / assetUnit;
        }
    }

    function _getUserBalanceInBaseCurrency(
        address user,
        DataTypes.ReserveData storage reserve,
        uint256 assetPrice,
        uint256 assetUnit
    ) private view returns (uint256) {
        uint256 normalizedIncome = reserve.getNormalizedIncome();
        uint256 balance = (
            IScaledBalanceToken(reserve.aTokenAddress)
                .scaledBalanceOf(user)
                .rayMul(normalizedIncome)
        ) * assetPrice;

        unchecked {
            return balance / assetUnit;
        }
    }
}
