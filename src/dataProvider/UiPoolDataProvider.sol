// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IUiPoolDataProvider} from "./interfaces/IUiPoolDataProvider.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {WadRayMath} from "../libraries/math/WadRayMath.sol";
import {ReserveConfiguration} from "../libraries/configuration/ReserveConfiguration.sol";
import {UserConfiguration} from "../libraries/configuration/UserConfiguration.sol";
import {DataTypes} from "../libraries/types/DataTypes.sol";
import {IPoolAddressesProvider} from "../interfaces/IPoolAddressesProvider.sol";
import {IPool} from "../interfaces/IPool.sol";
import {IAToken} from "../interfaces/IAToken.sol";
import {IVariableDebtToken} from "../interfaces/IVariableDebtToken.sol";
import {IStableDebtToken} from "../interfaces/IStableDebtToken.sol";
import {IPoolDataProvider} from "./interfaces/IPoolDataProvider.sol";
import {IPriceOracleGetter} from "../interfaces/IPriceOracleGetter.sol";
import {ReserveInterestRateStrategy} from "../pool/ReserveInterestRateStrategy.sol";

contract UiPoolDataProvider is IUiPoolDataProvider {
    using WadRayMath for uint256;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using UserConfiguration for DataTypes.UserConfigurationMap;

    uint256 public constant ETH_CURRENCY_UNIT = 1 ether;

    function getReservesList(
        IPoolAddressesProvider provider
    ) public view override returns (address[] memory) {
        IPool pool = IPool(provider.getPool());
        return pool.getReservesList();
    }

    function getReservesData(
        IPoolAddressesProvider provider
    )
        public
        view
        override
        returns (AggregatedReserveData[] memory, BaseCurrencyInfo memory)
    {
        IPriceOracleGetter oracle = IPriceOracleGetter(
            provider.getPriceOracle()
        );
        IPool pool = IPool(provider.getPool());
        IPoolDataProvider poolDataProvider = IPoolDataProvider(
            provider.getPoolDataProvider()
        );

        address[] memory reserves = pool.getReservesList();
        AggregatedReserveData[]
            memory reservesData = new AggregatedReserveData[](reserves.length);

        for (uint256 i = 0; i < reserves.length; i++) {
            AggregatedReserveData memory reserveData = reservesData[i];
            reserveData.underlyingAsset = reserves[i];

            // reserve current state
            DataTypes.ReserveData memory baseData = pool.getReserveData(
                reserveData.underlyingAsset
            );
            //the liquidity index. Expressed in ray
            reserveData.liquidityIndex = baseData.liquidityIndex;
            //variable borrow index. Expressed in ray
            reserveData.variableBorrowIndex = baseData.variableBorrowIndex;
            //the current supply rate. Expressed in ray
            reserveData.liquidityRate = baseData.currentLiquidityRate;
            //the current variable borrow rate. Expressed in ray
            reserveData.variableBorrowRate = baseData.currentVariableBorrowRate;
            //the current stable borrow rate. Expressed in ray
            reserveData.stableBorrowRate = baseData.currentStableBorrowRate;
            reserveData.lastUpdateTimestamp = baseData.lastUpdateTimestamp;
            reserveData.aTokenAddress = baseData.aTokenAddress;
            reserveData.stableDebtTokenAddress = baseData
                .stableDebtTokenAddress;
            reserveData.variableDebtTokenAddress = baseData
                .variableDebtTokenAddress;
            //address of the interest rate strategy
            reserveData.interestRateStrategyAddress = baseData
                .interestRateStrategyAddress;
            reserveData.priceInMarketReferenceCurrency = oracle.getAssetPrice(
                reserveData.underlyingAsset
            );
            reserveData.priceOracle = oracle.getSourceOfAsset(
                reserveData.underlyingAsset
            );
            reserveData.availableLiquidity = IERC20Metadata(
                reserveData.underlyingAsset
            ).balanceOf(reserveData.aTokenAddress);
            (
                reserveData.totalPrincipalStableDebt,
                ,
                reserveData.averageStableRate,
                reserveData.stableDebtLastUpdateTimestamp
            ) = IStableDebtToken(reserveData.stableDebtTokenAddress)
                .getSupplyData();
            reserveData.totalScaledVariableDebt = IVariableDebtToken(
                reserveData.variableDebtTokenAddress
            ).scaledTotalSupply();

            // Due we take the symbol from underlying token we need a special case for $MKR as symbol() returns bytes32

            reserveData.symbol = IERC20Metadata(reserveData.underlyingAsset)
                .symbol();
            reserveData.name = IERC20Metadata(reserveData.underlyingAsset)
                .name();

            //stores the reserve configuration
            DataTypes.ReserveConfigurationMap
                memory reserveConfigurationMap = baseData.configuration;
            uint256 eModeCategoryId;
            (
                reserveData.baseLTVasCollateral,
                reserveData.reserveLiquidationThreshold,
                reserveData.reserveLiquidationBonus,
                reserveData.decimals,
                reserveData.reserveFactor,
                eModeCategoryId
            ) = reserveConfigurationMap.getParams();
            reserveData.usageAsCollateralEnabled =
                reserveData.baseLTVasCollateral != 0;

            (
                reserveData.isActive,
                reserveData.isFrozen,
                reserveData.borrowingEnabled,
                reserveData.stableBorrowRateEnabled,
                reserveData.isPaused
            ) = reserveConfigurationMap.getFlags();

            // interest rates
            try
                ReserveInterestRateStrategy(
                    reserveData.interestRateStrategyAddress
                ).getVariableRateSlope1()
            returns (uint256 res) {
                reserveData.variableRateSlope1 = res;
            } catch {}
            try
                ReserveInterestRateStrategy(
                    reserveData.interestRateStrategyAddress
                ).getVariableRateSlope2()
            returns (uint256 res) {
                reserveData.variableRateSlope2 = res;
            } catch {}
            try
                ReserveInterestRateStrategy(
                    reserveData.interestRateStrategyAddress
                ).getStableRateSlope1()
            returns (uint256 res) {
                reserveData.stableRateSlope1 = res;
            } catch {}
            try
                ReserveInterestRateStrategy(
                    reserveData.interestRateStrategyAddress
                ).getStableRateSlope2()
            returns (uint256 res) {
                reserveData.stableRateSlope2 = res;
            } catch {}
            try
                ReserveInterestRateStrategy(
                    reserveData.interestRateStrategyAddress
                ).getBaseStableBorrowRate()
            returns (uint256 res) {
                reserveData.baseStableBorrowRate = res;
            } catch {}
            try
                ReserveInterestRateStrategy(
                    reserveData.interestRateStrategyAddress
                ).getBaseVariableBorrowRate()
            returns (uint256 res) {
                reserveData.baseVariableBorrowRate = res;
            } catch {}
            try
                ReserveInterestRateStrategy(
                    reserveData.interestRateStrategyAddress
                ).OPTIMAL_USAGE_RATIO()
            returns (uint256 res) {
                reserveData.optimalUsageRatio = res;
            } catch {}

            // v3 only
            reserveData.eModeCategoryId = uint8(eModeCategoryId);
            reserveData.debtCeiling = reserveConfigurationMap.getDebtCeiling();
            reserveData.debtCeilingDecimals = poolDataProvider
                .getDebtCeilingDecimals();
            (
                reserveData.borrowCap,
                reserveData.supplyCap
            ) = reserveConfigurationMap.getCaps();

            try
                poolDataProvider.getFlashLoanEnabled(
                    reserveData.underlyingAsset
                )
            returns (bool flashLoanEnabled) {
                reserveData.flashLoanEnabled = flashLoanEnabled;
            } catch (bytes memory) {
                reserveData.flashLoanEnabled = true;
            }

            reserveData.isSiloedBorrowing = reserveConfigurationMap
                .getSiloedBorrowing();
            reserveData.unbacked = baseData.unbacked;
            reserveData.isolationModeTotalDebt = baseData
                .isolationModeTotalDebt;
            reserveData.accruedToTreasury = baseData.accruedToTreasury;

            DataTypes.EModeCategory memory categoryData = pool
                .getEModeCategoryData(reserveData.eModeCategoryId);
            reserveData.eModeLtv = categoryData.ltv;
            reserveData.eModeLiquidationThreshold = categoryData
                .liquidationThreshold;
            reserveData.eModeLiquidationBonus = categoryData.liquidationBonus;
            // each eMode category may or may not have a custom oracle to override the individual assets price oracles
            reserveData.eModePriceSource = categoryData.priceSource;
            reserveData.eModeLabel = categoryData.label;

            reserveData.borrowableInIsolation = reserveConfigurationMap
                .getBorrowableInIsolation();
        }

        BaseCurrencyInfo memory baseCurrencyInfo;

        return (reservesData, baseCurrencyInfo);
    }

    function getUserReservesData(
        IPoolAddressesProvider provider,
        address user
    ) external view override returns (UserReserveData[] memory, uint8) {
        IPool pool = IPool(provider.getPool());
        address[] memory reserves = pool.getReservesList();
        DataTypes.UserConfigurationMap memory userConfig = pool
            .getUserConfiguration(user);

        uint8 userEmodeCategoryId = uint8(pool.getUserEMode(user));

        UserReserveData[] memory userReservesData = new UserReserveData[](
            user != address(0) ? reserves.length : 0
        );

        for (uint256 i = 0; i < reserves.length; i++) {
            DataTypes.ReserveData memory baseData = pool.getReserveData(
                reserves[i]
            );

            // user reserve data
            userReservesData[i].underlyingAsset = reserves[i];
            userReservesData[i].scaledATokenBalance = IAToken(
                baseData.aTokenAddress
            ).scaledBalanceOf(user);
            userReservesData[i].usageAsCollateralEnabledOnUser = userConfig
                .isUsingAsCollateral(i);

            if (userConfig.isBorrowing(i)) {
                userReservesData[i].scaledVariableDebt = IVariableDebtToken(
                    baseData.variableDebtTokenAddress
                ).scaledBalanceOf(user);
                userReservesData[i].principalStableDebt = IStableDebtToken(
                    baseData.stableDebtTokenAddress
                ).principalBalanceOf(user);
                if (userReservesData[i].principalStableDebt != 0) {
                    userReservesData[i].stableBorrowRate = IStableDebtToken(
                        baseData.stableDebtTokenAddress
                    ).getUserStableRate(user);
                    userReservesData[i]
                        .stableBorrowLastUpdateTimestamp = IStableDebtToken(
                        baseData.stableDebtTokenAddress
                    ).getUserLastUpdated(user);
                }
            }
        }

        return (userReservesData, userEmodeCategoryId);
    }
}
