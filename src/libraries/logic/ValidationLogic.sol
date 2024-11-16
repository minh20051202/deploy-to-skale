// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {DataTypes} from "./ReserveLogic.sol";
import {WadRayMath} from "../math/WadRayMath.sol";
import {Errors} from "../helpers/Errors.sol";
import {ReserveLogic} from "./ReserveLogic.sol";
import {ReserveConfiguration} from "../configuration/ReserveConfiguration.sol";
import {UserConfiguration} from "../configuration/UserConfiguration.sol";
import {GenericLogic} from "./GenericLogic.sol";
import {IPoolAddressesProvider} from "../../interfaces/IPoolAddressesProvider.sol";
import {IncentivizedERC20} from "../../tokenization/base/IncentivizedERC20.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IAToken} from "../../interfaces/IAToken.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IPriceOracleGetter} from "../../interfaces/IPriceOracleGetter.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {PercentageMath} from "../math/PercentageMath.sol";

library ValidationLogic {
    using WadRayMath for uint256;
    using ReserveLogic for DataTypes.ReserveData;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using UserConfiguration for DataTypes.UserConfigurationMap;
    using SafeCast for uint256;
    using PercentageMath for uint256;

    uint256 public constant REBALANCE_UP_LIQUIDITY_RATE_THRESHOLD = 0.9e4;

    uint256 public constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1e18;

    bytes32 public constant ISOLATED_COLLATERAL_SUPPLIER_ROLE =
        keccak256("ISOLATED_COLLATERAL_SUPPLIER");

    function validateSupply(
        DataTypes.ReserveCache memory reserveCache,
        DataTypes.ReserveData storage reserve,
        uint256 amount
    ) internal view {
        require(amount != 0, Errors.INVALID_AMOUNT);

        (bool isActive, bool isFrozen, , , bool isPaused) = reserveCache
            .reserveConfiguration
            .getFlags();
        require(isActive, Errors.RESERVE_INACTIVE);
        require(!isPaused, Errors.RESERVE_PAUSED);
        require(!isFrozen, Errors.RESERVE_FROZEN);

        uint256 supplyCap = reserveCache.reserveConfiguration.getSupplyCap();
        require(
            supplyCap == 0 ||
                ((IAToken(reserveCache.aTokenAddress).scaledTotalSupply() +
                    uint256(reserve.accruedToTreasury)).rayMul(
                        reserveCache.nextLiquidityIndex
                    ) + amount) <=
                supplyCap *
                    (10 ** reserveCache.reserveConfiguration.getDecimals()),
            Errors.SUPPLY_CAP_EXCEEDED
        );
    }

    function validateTransfer(
        DataTypes.ReserveData storage reserve
    ) internal view {
        require(!reserve.configuration.getPaused(), Errors.RESERVE_PAUSED);
    }

    function validateHFAndLtv(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        mapping(uint8 => DataTypes.EModeCategory) storage eModeCategories,
        DataTypes.UserConfigurationMap memory userConfig,
        address asset,
        address from,
        uint256 reservesCount,
        address oracle,
        uint8 userEModeCategory
    ) internal view {
        DataTypes.ReserveData memory reserve = reservesData[asset];

        (, bool hasZeroLtvCollateral) = validateHealthFactor(
            reservesData,
            reservesList,
            eModeCategories,
            userConfig,
            from,
            userEModeCategory,
            reservesCount,
            oracle
        );

        require(
            !hasZeroLtvCollateral || reserve.configuration.getLtv() == 0,
            Errors.LTV_VALIDATION_FAILED
        );
    }

    function validateHealthFactor(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        mapping(uint8 => DataTypes.EModeCategory) storage eModeCategories,
        DataTypes.UserConfigurationMap memory userConfig,
        address user,
        uint8 userEModeCategory,
        uint256 reservesCount,
        address oracle
    ) internal view returns (uint256, bool) {
        (, , , , uint256 healthFactor, bool hasZeroLtvCollateral) = GenericLogic
            .calculateUserAccountData(
                reservesData,
                reservesList,
                eModeCategories,
                DataTypes.CalculateUserAccountDataParams({
                    userConfig: userConfig,
                    reservesCount: reservesCount,
                    user: user,
                    oracle: oracle,
                    userEModeCategory: userEModeCategory
                })
            );

        require(
            healthFactor >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
            Errors.HEALTH_FACTOR_LOWER_THAN_LIQUIDATION_THRESHOLD
        );

        return (healthFactor, hasZeroLtvCollateral);
    }

    function validateUseAsCollateral(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        DataTypes.UserConfigurationMap storage userConfig,
        DataTypes.ReserveConfigurationMap memory reserveConfig
    ) internal view returns (bool) {
        if (reserveConfig.getLtv() == 0) {
            return false;
        }
        if (!userConfig.isUsingAsCollateralAny()) {
            return true;
        }
        (bool isolationModeActive, , ) = userConfig.getIsolationModeState(
            reservesData,
            reservesList
        );

        return (!isolationModeActive && reserveConfig.getDebtCeiling() == 0);
    }

    function validateAutomaticUseAsCollateral(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        DataTypes.UserConfigurationMap storage userConfig,
        DataTypes.ReserveConfigurationMap memory reserveConfig,
        address aTokenAddress
    ) internal view returns (bool) {
        //   if (reserveConfig.getDebtCeiling() != 0) {
        //   IPoolAddressesProvider addressesProvider = IncentivizedERC20(aTokenAddress).POOL().ADDRESSES_PROVIDER();
        // if (!IAccessControl(addressesProvider.getACLManager()).hasRole(ISOLATED_COLLATERAL_SUPPLIER_ROLE,msg.sender)) return false;
        // }
        return
            validateUseAsCollateral(
                reservesData,
                reservesList,
                userConfig,
                reserveConfig
            );
    }

    struct ValidateBorrowLocalVars {
        uint256 currentLtv;
        uint256 collateralNeededInBaseCurrency;
        uint256 userCollateralInBaseCurrency;
        uint256 userDebtInBaseCurrency;
        uint256 availableLiquidity;
        uint256 healthFactor;
        uint256 totalDebt;
        uint256 totalSupplyVariableDebt;
        uint256 reserveDecimals;
        uint256 borrowCap;
        uint256 amountInBaseCurrency;
        uint256 assetUnit;
        address eModePriceSource;
        address siloedBorrowingAddress;
        bool isActive;
        bool isFrozen;
        bool isPaused;
        bool borrowingEnabled;
        bool stableRateBorrowingEnabled;
        bool siloedBorrowingEnabled;
    }

    function validateBorrow(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        mapping(uint8 => DataTypes.EModeCategory) storage eModeCategories,
        DataTypes.ValidateBorrowParams memory params
    ) internal view {
        require(params.amount != 0, Errors.INVALID_AMOUNT);

        ValidateBorrowLocalVars memory vars;

        (
            vars.isActive,
            vars.isFrozen,
            vars.borrowingEnabled,
            vars.stableRateBorrowingEnabled,
            vars.isPaused
        ) = params.reserveCache.reserveConfiguration.getFlags();

        require(vars.isActive, Errors.RESERVE_INACTIVE);
        require(!vars.isPaused, Errors.RESERVE_PAUSED);
        require(!vars.isFrozen, Errors.RESERVE_FROZEN);
        require(vars.borrowingEnabled, Errors.BORROWING_NOT_ENABLED);

        //validate interest rate mode
        require(
            params.interestRateMode == DataTypes.InterestRateMode.VARIABLE ||
                params.interestRateMode == DataTypes.InterestRateMode.STABLE,
            Errors.INVALID_INTEREST_RATE_MODE_SELECTED
        );

        vars.reserveDecimals = params
            .reserveCache
            .reserveConfiguration
            .getDecimals();
        vars.borrowCap = params
            .reserveCache
            .reserveConfiguration
            .getBorrowCap();
        unchecked {
            vars.assetUnit = 10 ** vars.reserveDecimals;
        }

        if (vars.borrowCap != 0) {
            vars.totalSupplyVariableDebt = params
                .reserveCache
                .currScaledVariableDebt
                .rayMul(params.reserveCache.nextVariableBorrowIndex);

            vars.totalDebt =
                params.reserveCache.currTotalStableDebt +
                vars.totalSupplyVariableDebt +
                params.amount;

            unchecked {
                require(
                    vars.totalDebt <= vars.borrowCap * vars.assetUnit,
                    Errors.BORROW_CAP_EXCEEDED
                );
            }
        }

        if (params.isolationModeActive) {
            // check that the asset being borrowed is borrowable in isolation mode AND
            // the total exposure is no bigger than the collateral debt ceiling
            require(
                params
                    .reserveCache
                    .reserveConfiguration
                    .getBorrowableInIsolation(),
                Errors.ASSET_NOT_BORROWABLE_IN_ISOLATION
            );

            require(
                reservesData[params.isolationModeCollateralAddress]
                    .isolationModeTotalDebt +
                    (params.amount /
                        10 **
                            (vars.reserveDecimals -
                                ReserveConfiguration.DEBT_CEILING_DECIMALS))
                        .toUint128() <=
                    params.isolationModeDebtCeiling,
                Errors.DEBT_CEILING_EXCEEDED
            );
        }

        if (params.userEModeCategory != 0) {
            require(
                params.reserveCache.reserveConfiguration.getEModeCategory() ==
                    params.userEModeCategory,
                Errors.INCONSISTENT_EMODE_CATEGORY
            );
            vars.eModePriceSource = eModeCategories[params.userEModeCategory]
                .priceSource;
        }

        (
            vars.userCollateralInBaseCurrency,
            vars.userDebtInBaseCurrency,
            vars.currentLtv,
            ,
            vars.healthFactor,

        ) = GenericLogic.calculateUserAccountData(
            reservesData,
            reservesList,
            eModeCategories,
            DataTypes.CalculateUserAccountDataParams({
                userConfig: params.userConfig,
                reservesCount: params.reservesCount,
                user: params.userAddress,
                oracle: params.oracle,
                userEModeCategory: params.userEModeCategory
            })
        );

        require(
            vars.userCollateralInBaseCurrency != 0,
            Errors.COLLATERAL_BALANCE_IS_ZERO
        );
        require(vars.currentLtv != 0, Errors.LTV_VALIDATION_FAILED);

        require(
            vars.healthFactor > HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
            Errors.HEALTH_FACTOR_LOWER_THAN_LIQUIDATION_THRESHOLD
        );

        vars.amountInBaseCurrency =
            IPriceOracleGetter(params.oracle).getAssetPrice(
                vars.eModePriceSource != address(0)
                    ? vars.eModePriceSource
                    : params.asset
            ) *
            params.amount;
        unchecked {
            vars.amountInBaseCurrency /= vars.assetUnit;
        }

        //add the current already borrowed amount to the amount requested to calculate the total collateral needed.
        vars.collateralNeededInBaseCurrency = (vars.userDebtInBaseCurrency +
            vars.amountInBaseCurrency).percentDiv(vars.currentLtv); //LTV is calculated in percentage

        require(
            vars.collateralNeededInBaseCurrency <=
                vars.userCollateralInBaseCurrency,
            Errors.COLLATERAL_CANNOT_COVER_NEW_BORROW
        );

        /**
         * Following conditions need to be met if the user is borrowing at a stable rate:
         * 1. Reserve must be enabled for stable rate borrowing
         * 2. Users cannot borrow from the reserve if their collateral is (mostly) the same currency
         *    they are borrowing, to prevent abuses.
         * 3. Users will be able to borrow only a portion of the total available liquidity
         */

        if (params.interestRateMode == DataTypes.InterestRateMode.STABLE) {
            //check if the borrow mode is stable and if stable rate borrowing is enabled on this reserve

            require(
                vars.stableRateBorrowingEnabled,
                Errors.STABLE_BORROWING_NOT_ENABLED
            );

            require(
                !params.userConfig.isUsingAsCollateral(
                    reservesData[params.asset].id
                ) ||
                    params.reserveCache.reserveConfiguration.getLtv() == 0 ||
                    params.amount >
                    IERC20(params.reserveCache.aTokenAddress).balanceOf(
                        params.userAddress
                    ),
                Errors.COLLATERAL_SAME_AS_BORROWING_CURRENCY
            );

            vars.availableLiquidity = IERC20(params.asset).balanceOf(
                params.reserveCache.aTokenAddress
            );

            //calculate the max available loan size in stable rate mode as a percentage of the
            //available liquidity
            uint256 maxLoanSizeStable = vars.availableLiquidity.percentMul(
                params.maxStableLoanPercent
            );

            require(
                params.amount <= maxLoanSizeStable,
                Errors.AMOUNT_BIGGER_THAN_MAX_LOAN_SIZE_STABLE
            );
        }

        if (params.userConfig.isBorrowingAny()) {
            (vars.siloedBorrowingEnabled, vars.siloedBorrowingAddress) = params
                .userConfig
                .getSiloedBorrowingState(reservesData, reservesList);

            if (vars.siloedBorrowingEnabled) {
                require(
                    vars.siloedBorrowingAddress == params.asset,
                    Errors.SILOED_BORROWING_VIOLATION
                );
            } else {
                require(
                    !params
                        .reserveCache
                        .reserveConfiguration
                        .getSiloedBorrowing(),
                    Errors.SILOED_BORROWING_VIOLATION
                );
            }
        }
    }

    function validateWithdraw(
        DataTypes.ReserveCache memory reserveCache,
        uint256 amount,
        uint256 userBalance
    ) internal pure {
        require(amount != 0, Errors.INVALID_AMOUNT);
        require(
            amount <= userBalance,
            Errors.NOT_ENOUGH_AVAILABLE_USER_BALANCE
        );

        (bool isActive, , , , bool isPaused) = reserveCache
            .reserveConfiguration
            .getFlags();
        require(isActive, Errors.RESERVE_INACTIVE);
        require(!isPaused, Errors.RESERVE_PAUSED);
    }

    function validateRepay(
        DataTypes.ReserveCache memory reserveCache,
        uint256 amountSent,
        DataTypes.InterestRateMode interestRateMode,
        address onBehalfOf,
        uint256 stableDebt,
        uint256 variableDebt
    ) internal view {
        require(amountSent != 0, Errors.INVALID_AMOUNT);
        require(
            amountSent != type(uint256).max || msg.sender == onBehalfOf,
            Errors.NO_EXPLICIT_AMOUNT_TO_REPAY_ON_BEHALF
        );

        (bool isActive, , , , bool isPaused) = reserveCache
            .reserveConfiguration
            .getFlags();
        require(isActive, Errors.RESERVE_INACTIVE);
        require(!isPaused, Errors.RESERVE_PAUSED);

        require(
            (stableDebt != 0 &&
                interestRateMode == DataTypes.InterestRateMode.STABLE) ||
                (variableDebt != 0 &&
                    interestRateMode == DataTypes.InterestRateMode.VARIABLE),
            Errors.NO_DEBT_OF_SELECTED_TYPE
        );
    }

    function validateSetUseReserveAsCollateral(
        DataTypes.ReserveCache memory reserveCache,
        uint256 userBalance
    ) internal pure {
        require(userBalance != 0, Errors.UNDERLYING_BALANCE_ZERO);

        (bool isActive, , , , bool isPaused) = reserveCache
            .reserveConfiguration
            .getFlags();
        require(isActive, Errors.RESERVE_INACTIVE);
        require(!isPaused, Errors.RESERVE_PAUSED);
    }
}
