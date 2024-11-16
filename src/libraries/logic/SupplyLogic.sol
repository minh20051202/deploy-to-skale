// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {DataTypes} from "../types/DataTypes.sol";
import {ValidationLogic} from "./ValidationLogic.sol";
import {ReserveLogic} from "./ReserveLogic.sol";
import {UserConfiguration} from "../configuration/UserConfiguration.sol";
import {ReserveConfiguration} from "../configuration/ReserveConfiguration.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IAToken} from "../../interfaces/IAToken.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {WadRayMath} from "../math/WadRayMath.sol";
import {Errors} from "../helpers/Errors.sol";

library SupplyLogic {
    using ReserveLogic for DataTypes.ReserveCache;
    using ReserveLogic for DataTypes.ReserveData;
    using UserConfiguration for DataTypes.UserConfigurationMap;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using SafeERC20 for IERC20;
    using WadRayMath for uint256;

    event ReserveUsedAsCollateralEnabled(
        address indexed reserve,
        address indexed user
    );
    event ReserveUsedAsCollateralDisabled(
        address indexed reserve,
        address indexed user
    );
    event Withdraw(
        address indexed reserve,
        address indexed user,
        address indexed to,
        uint256 amount
    );
    event Supply(
        address indexed reserve,
        address user,
        address indexed onBehalfOf,
        uint256 amount
    );

    function executeSupply(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        DataTypes.UserConfigurationMap storage userConfig,
        DataTypes.ExecuteSupplyParams memory params
    ) external {
        DataTypes.ReserveData storage reserve = reservesData[params.asset];
        DataTypes.ReserveCache memory reserveCache = reserve.cache();

        reserve.updateState(reserveCache);

        ValidationLogic.validateSupply(reserveCache, reserve, params.amount);

        reserve.updateInterestRates(
            reserveCache,
            params.asset,
            params.amount,
            0
        );

        IERC20(params.asset).safeTransferFrom(
            msg.sender,
            reserveCache.aTokenAddress,
            params.amount
        );

        bool isFirstSupply = IAToken(reserveCache.aTokenAddress).mint(
            msg.sender,
            params.onBehalfOf,
            params.amount,
            reserveCache.nextLiquidityIndex
        );

        if (isFirstSupply) {
            if (
                ValidationLogic.validateAutomaticUseAsCollateral(
                    reservesData,
                    reservesList,
                    userConfig,
                    reserveCache.reserveConfiguration,
                    reserveCache.aTokenAddress
                )
            ) {
                userConfig.setUsingAsCollateral(reserve.id, true);
                emit ReserveUsedAsCollateralEnabled(
                    params.asset,
                    params.onBehalfOf
                );
            }
        }

        emit Supply(params.asset, msg.sender, params.onBehalfOf, params.amount);
    }

    function executeWithdraw(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        mapping(uint8 => DataTypes.EModeCategory) storage eModeCategories,
        DataTypes.UserConfigurationMap storage userConfig,
        DataTypes.ExecuteWithdrawParams memory params
    ) external returns (uint256) {
        DataTypes.ReserveData storage reserve = reservesData[params.asset];
        DataTypes.ReserveCache memory reserveCache = reserve.cache();

        reserve.updateState(reserveCache);

        uint256 userBalance = IAToken(reserveCache.aTokenAddress)
            .scaledBalanceOf(msg.sender)
            .rayMul(reserveCache.nextLiquidityIndex);

        uint256 amountToWithdraw = params.amount;

        if (params.amount == type(uint256).max) {
            amountToWithdraw = userBalance;
        }

        ValidationLogic.validateWithdraw(
            reserveCache,
            amountToWithdraw,
            userBalance
        );

        reserve.updateInterestRates(
            reserveCache,
            params.asset,
            0,
            amountToWithdraw
        );

        bool isCollateral = userConfig.isUsingAsCollateral(reserve.id);

        if (isCollateral && amountToWithdraw == userBalance) {
            userConfig.setUsingAsCollateral(reserve.id, false);
            emit ReserveUsedAsCollateralDisabled(params.asset, msg.sender);
        }

        IAToken(reserveCache.aTokenAddress).burn(
            msg.sender,
            params.to,
            amountToWithdraw,
            reserveCache.nextLiquidityIndex
        );

        if (isCollateral && userConfig.isBorrowingAny()) {
            ValidationLogic.validateHFAndLtv(
                reservesData,
                reservesList,
                eModeCategories,
                userConfig,
                params.asset,
                msg.sender,
                params.reservesCount,
                params.oracle,
                params.userEModeCategory
            );
        }

        emit Withdraw(params.asset, msg.sender, params.to, amountToWithdraw);

        return amountToWithdraw;
    }

    function executeFinalizeTransfer(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        mapping(uint8 => DataTypes.EModeCategory) storage eModeCategories,
        mapping(address => DataTypes.UserConfigurationMap) storage usersConfig,
        DataTypes.FinalizeTransferParams memory params
    ) internal {
        DataTypes.ReserveData storage reserve = reservesData[params.asset];

        ValidationLogic.validateTransfer(reserve);

        uint256 reserveId = reserve.id;

        if (params.from != params.to && params.amount != 0) {
            DataTypes.UserConfigurationMap storage fromConfig = usersConfig[
                params.from
            ];

            if (fromConfig.isUsingAsCollateral(reserveId)) {
                if (fromConfig.isBorrowingAny()) {
                    ValidationLogic.validateHFAndLtv(
                        reservesData,
                        reservesList,
                        eModeCategories,
                        usersConfig[params.from],
                        params.asset,
                        params.from,
                        params.reservesCount,
                        params.oracle,
                        params.fromEModeCategory
                    );
                }
                if (params.balanceFromBefore == params.amount) {
                    fromConfig.setUsingAsCollateral(reserveId, false);
                    emit ReserveUsedAsCollateralDisabled(
                        params.asset,
                        params.from
                    );
                }
            }

            if (params.balanceToBefore == 0) {
                DataTypes.UserConfigurationMap storage toConfig = usersConfig[
                    params.to
                ];
                if (
                    ValidationLogic.validateAutomaticUseAsCollateral(
                        reservesData,
                        reservesList,
                        toConfig,
                        reserve.configuration,
                        reserve.aTokenAddress
                    )
                ) {
                    toConfig.setUsingAsCollateral(reserveId, true);
                    emit ReserveUsedAsCollateralEnabled(
                        params.asset,
                        params.to
                    );
                }
            }
        }
    }

    function executeUseReserveAsCollateral(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        mapping(uint8 => DataTypes.EModeCategory) storage eModeCategories,
        DataTypes.UserConfigurationMap storage userConfig,
        address asset,
        bool useAsCollateral,
        uint256 reservesCount,
        address priceOracle,
        uint8 userEModeCategory
    ) external {
        DataTypes.ReserveData storage reserve = reservesData[asset];
        DataTypes.ReserveCache memory reserveCache = reserve.cache();

        uint256 userBalance = IERC20(reserveCache.aTokenAddress).balanceOf(
            msg.sender
        );

        ValidationLogic.validateSetUseReserveAsCollateral(
            reserveCache,
            userBalance
        );

        if (useAsCollateral == userConfig.isUsingAsCollateral(reserve.id))
            return;

        if (useAsCollateral) {
            require(
                ValidationLogic.validateUseAsCollateral(
                    reservesData,
                    reservesList,
                    userConfig,
                    reserveCache.reserveConfiguration
                ),
                Errors.USER_IN_ISOLATION_MODE_OR_LTV_ZERO
            );

            userConfig.setUsingAsCollateral(reserve.id, true);
            emit ReserveUsedAsCollateralEnabled(asset, msg.sender);
        } else {
            userConfig.setUsingAsCollateral(reserve.id, false);
            ValidationLogic.validateHFAndLtv(
                reservesData,
                reservesList,
                eModeCategories,
                userConfig,
                asset,
                msg.sender,
                reservesCount,
                priceOracle,
                userEModeCategory
            );

            emit ReserveUsedAsCollateralDisabled(asset, msg.sender);
        }
    }
}
