// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IPoolDataProvider} from "./interfaces/IPoolDataProvider.sol";
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

contract PoolDataProvider is IPoolDataProvider {
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using UserConfiguration for DataTypes.UserConfigurationMap;
    using WadRayMath for uint256;

    IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;

    constructor(IPoolAddressesProvider addressesProvider) {
        ADDRESSES_PROVIDER = addressesProvider;
    }

    function getAllReservesTokens()
        external
        view
        override
        returns (TokenData[] memory)
    {
        IPool pool = IPool(ADDRESSES_PROVIDER.getPool());
        address[] memory reserves = pool.getReservesList();
        TokenData[] memory reservesTokens = new TokenData[](reserves.length);
        for (uint256 i = 0; i < reserves.length; i++) {
            reservesTokens[i] = TokenData({
                symbol: IERC20Metadata(reserves[i]).symbol(),
                tokenAddress: reserves[i]
            });
        }
        return reservesTokens;
    }

    function getAllATokens()
        external
        view
        override
        returns (TokenData[] memory)
    {
        IPool pool = IPool(ADDRESSES_PROVIDER.getPool());
        address[] memory reserves = pool.getReservesList();
        TokenData[] memory aTokens = new TokenData[](reserves.length);
        for (uint256 i = 0; i < reserves.length; i++) {
            DataTypes.ReserveData memory reserveData = pool.getReserveData(
                reserves[i]
            );
            aTokens[i] = TokenData({
                symbol: IERC20Metadata(reserveData.aTokenAddress).symbol(),
                tokenAddress: reserveData.aTokenAddress
            });
        }
        return aTokens;
    }

    function getReserveConfigurationData(
        address asset
    )
        external
        view
        override
        returns (
            uint256 decimals,
            uint256 ltv,
            uint256 liquidationThreshold,
            uint256 liquidationBonus,
            uint256 reserveFactor,
            bool usageAsCollateralEnabled,
            bool borrowingEnabled,
            bool stableBorrowRateEnabled,
            bool isActive,
            bool isFrozen
        )
    {
        DataTypes.ReserveConfigurationMap memory configuration = IPool(
            ADDRESSES_PROVIDER.getPool()
        ).getConfiguration(asset);

        (
            ltv,
            liquidationThreshold,
            liquidationBonus,
            decimals,
            reserveFactor,

        ) = configuration.getParams();

        (
            isActive,
            isFrozen,
            borrowingEnabled,
            stableBorrowRateEnabled,

        ) = configuration.getFlags();

        usageAsCollateralEnabled = liquidationThreshold != 0;
    }

    function getReserveEModeCategory(
        address asset
    ) external view override returns (uint256) {
        DataTypes.ReserveConfigurationMap memory configuration = IPool(
            ADDRESSES_PROVIDER.getPool()
        ).getConfiguration(asset);
        return configuration.getEModeCategory();
    }

    function getReserveCaps(
        address asset
    ) external view override returns (uint256 borrowCap, uint256 supplyCap) {
        (borrowCap, supplyCap) = IPool(ADDRESSES_PROVIDER.getPool())
            .getConfiguration(asset)
            .getCaps();
    }

    /// @inheritdoc IPoolDataProvider
    function getPaused(
        address asset
    ) external view override returns (bool isPaused) {
        (, , , , isPaused) = IPool(ADDRESSES_PROVIDER.getPool())
            .getConfiguration(asset)
            .getFlags();
    }

    /// @inheritdoc IPoolDataProvider
    function getSiloedBorrowing(
        address asset
    ) external view override returns (bool) {
        return
            IPool(ADDRESSES_PROVIDER.getPool())
                .getConfiguration(asset)
                .getSiloedBorrowing();
    }

    /// @inheritdoc IPoolDataProvider
    function getLiquidationProtocolFee(
        address asset
    ) external view override returns (uint256) {
        return
            IPool(ADDRESSES_PROVIDER.getPool())
                .getConfiguration(asset)
                .getLiquidationProtocolFee();
    }

    /// @inheritdoc IPoolDataProvider
    function getUnbackedMintCap(
        address asset
    ) external view override returns (uint256) {
        return
            IPool(ADDRESSES_PROVIDER.getPool())
                .getConfiguration(asset)
                .getUnbackedMintCap();
    }

    /// @inheritdoc IPoolDataProvider
    function getDebtCeiling(
        address asset
    ) external view override returns (uint256) {
        return
            IPool(ADDRESSES_PROVIDER.getPool())
                .getConfiguration(asset)
                .getDebtCeiling();
    }

    /// @inheritdoc IPoolDataProvider
    function getDebtCeilingDecimals() external pure override returns (uint256) {
        return ReserveConfiguration.DEBT_CEILING_DECIMALS;
    }

    /// @inheritdoc IPoolDataProvider
    function getReserveData(
        address asset
    )
        external
        view
        override
        returns (
            uint256 unbacked,
            uint256 accruedToTreasuryScaled,
            uint256 totalAToken,
            uint256 totalStableDebt,
            uint256 totalVariableDebt,
            uint256 liquidityRate,
            uint256 variableBorrowRate,
            uint256 stableBorrowRate,
            uint256 averageStableBorrowRate,
            uint256 liquidityIndex,
            uint256 variableBorrowIndex,
            uint40 lastUpdateTimestamp
        )
    {
        DataTypes.ReserveData memory reserve = IPool(
            ADDRESSES_PROVIDER.getPool()
        ).getReserveData(asset);

        return (
            reserve.unbacked,
            reserve.accruedToTreasury,
            IERC20Metadata(reserve.aTokenAddress).totalSupply(),
            IERC20Metadata(reserve.stableDebtTokenAddress).totalSupply(),
            IERC20Metadata(reserve.variableDebtTokenAddress).totalSupply(),
            reserve.currentLiquidityRate,
            reserve.currentVariableBorrowRate,
            reserve.currentStableBorrowRate,
            IStableDebtToken(reserve.stableDebtTokenAddress)
                .getAverageStableRate(),
            reserve.liquidityIndex,
            reserve.variableBorrowIndex,
            reserve.lastUpdateTimestamp
        );
    }

    /// @inheritdoc IPoolDataProvider
    function getATokenTotalSupply(
        address asset
    ) external view override returns (uint256) {
        DataTypes.ReserveData memory reserve = IPool(
            ADDRESSES_PROVIDER.getPool()
        ).getReserveData(asset);
        return IERC20Metadata(reserve.aTokenAddress).totalSupply();
    }

    /// @inheritdoc IPoolDataProvider
    function getTotalDebt(
        address asset
    ) external view override returns (uint256) {
        DataTypes.ReserveData memory reserve = IPool(
            ADDRESSES_PROVIDER.getPool()
        ).getReserveData(asset);
        return
            IERC20Metadata(reserve.stableDebtTokenAddress).totalSupply() +
            IERC20Metadata(reserve.variableDebtTokenAddress).totalSupply();
    }

    /// @inheritdoc IPoolDataProvider
    function getUserReserveData(
        address asset,
        address user
    )
        external
        view
        override
        returns (
            uint256 currentATokenBalance,
            uint256 currentStableDebt,
            uint256 currentVariableDebt,
            uint256 principalStableDebt,
            uint256 scaledVariableDebt,
            uint256 stableBorrowRate,
            uint256 liquidityRate,
            uint40 stableRateLastUpdated,
            bool usageAsCollateralEnabled
        )
    {
        DataTypes.ReserveData memory reserve = IPool(
            ADDRESSES_PROVIDER.getPool()
        ).getReserveData(asset);

        DataTypes.UserConfigurationMap memory userConfig = IPool(
            ADDRESSES_PROVIDER.getPool()
        ).getUserConfiguration(user);

        currentATokenBalance = IERC20Metadata(reserve.aTokenAddress).balanceOf(
            user
        );
        currentVariableDebt = IERC20Metadata(reserve.variableDebtTokenAddress)
            .balanceOf(user);
        currentStableDebt = IERC20Metadata(reserve.stableDebtTokenAddress)
            .balanceOf(user);
        principalStableDebt = IStableDebtToken(reserve.stableDebtTokenAddress)
            .principalBalanceOf(user);
        scaledVariableDebt = IVariableDebtToken(
            reserve.variableDebtTokenAddress
        ).scaledBalanceOf(user);
        liquidityRate = reserve.currentLiquidityRate;
        stableBorrowRate = IStableDebtToken(reserve.stableDebtTokenAddress)
            .getUserStableRate(user);
        stableRateLastUpdated = IStableDebtToken(reserve.stableDebtTokenAddress)
            .getUserLastUpdated(user);
        usageAsCollateralEnabled = userConfig.isUsingAsCollateral(reserve.id);
    }

    /// @inheritdoc IPoolDataProvider
    function getReserveTokensAddresses(
        address asset
    )
        external
        view
        override
        returns (
            address aTokenAddress,
            address stableDebtTokenAddress,
            address variableDebtTokenAddress
        )
    {
        DataTypes.ReserveData memory reserve = IPool(
            ADDRESSES_PROVIDER.getPool()
        ).getReserveData(asset);

        return (
            reserve.aTokenAddress,
            reserve.stableDebtTokenAddress,
            reserve.variableDebtTokenAddress
        );
    }

    /// @inheritdoc IPoolDataProvider
    function getInterestRateStrategyAddress(
        address asset
    ) external view override returns (address irStrategyAddress) {
        DataTypes.ReserveData memory reserve = IPool(
            ADDRESSES_PROVIDER.getPool()
        ).getReserveData(asset);

        return (reserve.interestRateStrategyAddress);
    }

    /// @inheritdoc IPoolDataProvider
    function getFlashLoanEnabled(
        address asset
    ) external view override returns (bool) {
        DataTypes.ReserveConfigurationMap memory configuration = IPool(
            ADDRESSES_PROVIDER.getPool()
        ).getConfiguration(asset);

        return configuration.getFlashLoanEnabled();
    }
}
