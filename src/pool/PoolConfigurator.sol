// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ReserveConfiguration} from "../libraries/configuration/ReserveConfiguration.sol";
import {DataTypes} from "../libraries/types/DataTypes.sol";
import {IPool} from "../interfaces/IPool.sol";
import {IPoolConfigurator} from "../interfaces/IPoolConfigurator.sol";
import {IPoolAddressesProvider} from "../interfaces/IPoolAddressesProvider.sol";
import {Errors} from "../libraries/helpers/Errors.sol";
import {IPoolDataProvider} from "../interfaces/IPoolDataProvider.sol";
import {PercentageMath} from "../libraries/math/PercentageMath.sol";
import {Errors} from "../libraries/helpers/Errors.sol";

contract PoolConfigurator is IPoolConfigurator {
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using PercentageMath for uint256;

    IPoolAddressesProvider internal _addressesProvider;
    IPool internal _pool;

    constructor(IPoolAddressesProvider provider) {
        _addressesProvider = provider;
        _pool = IPool(_addressesProvider.getPool());
    }

    function setReserveActive(address asset, bool active) external {
        // if (!active) _checkNoSuppliers(asset);
        DataTypes.ReserveConfigurationMap memory currentConfig = _pool
            .getConfiguration(asset);
        currentConfig.setActive(active);
        _pool.setConfiguration(asset, currentConfig);
        emit ReserveActive(asset, active);
    }

    function configureReserveAsCollateral(
        address asset,
        uint256 ltv,
        uint256 liquidationThreshold,
        uint256 liquidationBonus
    ) external {
        //validation of the parameters: the LTV can
        //only be lower or equal than the liquidation threshold
        //(otherwise a loan against the asset would cause instantaneous liquidation)
        require(ltv <= liquidationThreshold, Errors.INVALID_RESERVE_PARAMS);

        DataTypes.ReserveConfigurationMap memory currentConfig = _pool
            .getConfiguration(asset);

        if (liquidationThreshold != 0) {
            //liquidation bonus must be bigger than 100.00%, otherwise the liquidator would receive less
            //collateral than needed to cover the debt
            require(
                liquidationBonus > PercentageMath.PERCENTAGE_FACTOR,
                Errors.INVALID_RESERVE_PARAMS
            );

            //if threshold * bonus is less than PERCENTAGE_FACTOR, it's guaranteed that at the moment
            //a loan is taken there is enough collateral available to cover the liquidation bonus
            require(
                liquidationThreshold.percentMul(liquidationBonus) <=
                    PercentageMath.PERCENTAGE_FACTOR,
                Errors.INVALID_RESERVE_PARAMS
            );
        } else {
            require(liquidationBonus == 0, Errors.INVALID_RESERVE_PARAMS);
            //if the liquidation threshold is being set to 0,
            // the reserve is being disabled as collateral. To do so,
            //we need to ensure no liquidity is supplied
            _checkNoSuppliers(asset);
        }

        currentConfig.setLtv(ltv);
        currentConfig.setLiquidationThreshold(liquidationThreshold);
        currentConfig.setLiquidationBonus(liquidationBonus);

        _pool.setConfiguration(asset, currentConfig);

        emit CollateralConfigurationChanged(
            asset,
            ltv,
            liquidationThreshold,
            liquidationBonus
        );
    }

    function _checkNoSuppliers(address asset) internal view {
        (
            ,
            uint256 accruedToTreasury,
            uint256 totalATokens,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,

        ) = IPoolDataProvider(_addressesProvider.getPoolDataProvider())
                .getReserveData(asset);

        require(
            totalATokens == 0 && accruedToTreasury == 0,
            Errors.RESERVE_LIQUIDITY_NOT_ZERO
        );
    }

    function setReserveBorrowing(
        address asset,
        bool enabled
    ) external override {
        DataTypes.ReserveConfigurationMap memory currentConfig = _pool
            .getConfiguration(asset);
        if (!enabled) {
            require(
                !currentConfig.getStableRateBorrowingEnabled(),
                Errors.STABLE_BORROWING_ENABLED
            );
        }
        currentConfig.setBorrowingEnabled(enabled);
        _pool.setConfiguration(asset, currentConfig);
        emit ReserveBorrowing(asset, enabled);
    }

    function setAssetEModeCategory(
        address asset,
        uint8 newCategoryId
    ) external override {
        DataTypes.ReserveConfigurationMap memory currentConfig = _pool
            .getConfiguration(asset);

        if (newCategoryId != 0) {
            DataTypes.EModeCategory memory categoryData = _pool
                .getEModeCategoryData(newCategoryId);
            require(
                categoryData.liquidationThreshold >
                    currentConfig.getLiquidationThreshold(),
                Errors.INVALID_EMODE_CATEGORY_ASSIGNMENT
            );
        }
        uint256 oldCategoryId = currentConfig.getEModeCategory();
        currentConfig.setEModeCategory(newCategoryId);
        _pool.setConfiguration(asset, currentConfig);
        emit EModeAssetCategoryChanged(
            asset,
            uint8(oldCategoryId),
            newCategoryId
        );
    }

    function setEModeCategory(
        uint8 categoryId,
        uint16 ltv,
        uint16 liquidationThreshold,
        uint16 liquidationBonus,
        address oracle,
        string calldata label
    ) external override {
        require(ltv != 0, Errors.INVALID_EMODE_CATEGORY_PARAMS);
        require(
            liquidationThreshold != 0,
            Errors.INVALID_EMODE_CATEGORY_PARAMS
        );

        // validation of the parameters: the LTV can
        // only be lower or equal than the liquidation threshold
        // (otherwise a loan against the asset would cause instantaneous liquidation)
        require(
            ltv <= liquidationThreshold,
            Errors.INVALID_EMODE_CATEGORY_PARAMS
        );
        require(
            liquidationBonus > PercentageMath.PERCENTAGE_FACTOR,
            Errors.INVALID_EMODE_CATEGORY_PARAMS
        );

        // if threshold * bonus is less than PERCENTAGE_FACTOR, it's guaranteed that at the moment
        // a loan is taken there is enough collateral available to cover the liquidation bonus
        require(
            uint256(liquidationThreshold).percentMul(liquidationBonus) <=
                PercentageMath.PERCENTAGE_FACTOR,
            Errors.INVALID_EMODE_CATEGORY_PARAMS
        );

        address[] memory reserves = _pool.getReservesList();
        for (uint256 i = 0; i < reserves.length; i++) {
            DataTypes.ReserveConfigurationMap memory currentConfig = _pool
                .getConfiguration(reserves[i]);
            if (categoryId == currentConfig.getEModeCategory()) {
                require(
                    ltv > currentConfig.getLtv(),
                    Errors.INVALID_EMODE_CATEGORY_PARAMS
                );
                require(
                    liquidationThreshold >
                        currentConfig.getLiquidationThreshold(),
                    Errors.INVALID_EMODE_CATEGORY_PARAMS
                );
            }
        }

        _pool.configureEModeCategory(
            categoryId,
            DataTypes.EModeCategory({
                ltv: ltv,
                liquidationThreshold: liquidationThreshold,
                liquidationBonus: liquidationBonus,
                priceSource: oracle,
                label: label
            })
        );
        emit EModeCategoryAdded(
            categoryId,
            ltv,
            liquidationThreshold,
            liquidationBonus,
            oracle,
            label
        );
    }

    function setDebtCeiling(
        address asset,
        uint256 newDebtCeiling
    ) external override {
        DataTypes.ReserveConfigurationMap memory currentConfig = _pool
            .getConfiguration(asset);

        uint256 oldDebtCeiling = currentConfig.getDebtCeiling();
        if (oldDebtCeiling == 0) {
            _checkNoSuppliers(asset);
        }
        currentConfig.setDebtCeiling(newDebtCeiling);
        _pool.setConfiguration(asset, currentConfig);

        if (newDebtCeiling == 0) {
            _pool.resetIsolationModeTotalDebt(asset);
        }

        emit DebtCeilingChanged(asset, oldDebtCeiling, newDebtCeiling);
    }

    function setSiloedBorrowing(
        address asset,
        bool newSiloed
    ) external override {
        if (newSiloed) {
            _checkNoBorrowers(asset);
        }
        DataTypes.ReserveConfigurationMap memory currentConfig = _pool
            .getConfiguration(asset);

        bool oldSiloed = currentConfig.getSiloedBorrowing();

        currentConfig.setSiloedBorrowing(newSiloed);

        _pool.setConfiguration(asset, currentConfig);

        emit SiloedBorrowingChanged(asset, oldSiloed, newSiloed);
    }

    function _checkNoBorrowers(address asset) internal view {
        uint256 totalDebt = IPoolDataProvider(
            _addressesProvider.getPoolDataProvider()
        ).getTotalDebt(asset);
        require(totalDebt == 0, Errors.RESERVE_DEBT_NOT_ZERO);
    }
}
