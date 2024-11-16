// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./PoolStorage.sol";
import {Errors} from "../libraries/helpers/Errors.sol";
import {PoolLogic} from "../libraries/logic/PoolLogic.sol";
import {SupplyLogic} from "../libraries/logic/SupplyLogic.sol";
import {ReserveLogic} from "../libraries/logic/ReserveLogic.sol";

import {ReserveConfiguration} from "../libraries/configuration/ReserveConfiguration.sol";
import {IPoolAddressesProvider} from "../interfaces/IPoolAddressesProvider.sol";
import {BorrowLogic} from "../libraries/logic/BorrowLogic.sol";
import {DataTypes} from "../libraries/types/DataTypes.sol";
import {IPool} from "../interfaces/IPool.sol";

contract Pool is PoolStorage, IPool {
    using ReserveLogic for DataTypes.ReserveData;

    IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;

    constructor(IPoolAddressesProvider provider) {
        ADDRESSES_PROVIDER = provider;
        _maxStableRateBorrowSizePercent = 0.25e4;
    }

    modifier onlyPoolConfigurator() {
        _onlyPoolConfigurator();
        _;
    }

    function _onlyPoolConfigurator() internal view virtual {
        require(
            ADDRESSES_PROVIDER.getPoolConfigurator() == msg.sender,
            Errors.CALLER_NOT_POOL_CONFIGURATOR
        );
    }

    function supply(address asset, uint256 amount, address onBehalfOf) public {
        SupplyLogic.executeSupply(
            _reserves,
            _reservesList,
            _usersConfig[onBehalfOf],
            DataTypes.ExecuteSupplyParams({
                asset: asset,
                amount: amount,
                onBehalfOf: onBehalfOf
            })
        );
    }

    function widthdraw(
        address asset,
        uint256 amount,
        address to
    ) public returns (uint256) {
        return
            SupplyLogic.executeWithdraw(
                _reserves,
                _reservesList,
                _eModeCategories,
                _usersConfig[msg.sender],
                DataTypes.ExecuteWithdrawParams({
                    asset: asset,
                    amount: amount,
                    to: to,
                    reservesCount: _reservesCount,
                    oracle: ADDRESSES_PROVIDER.getPriceOracle(),
                    userEModeCategory: _usersEModeCategory[msg.sender]
                })
            );
    }

    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) public {
        BorrowLogic.executeBorrow(
            _reserves,
            _reservesList,
            _eModeCategories,
            _usersConfig[onBehalfOf],
            DataTypes.ExecuteBorrowParams({
                asset: asset,
                user: msg.sender,
                onBehalfOf: onBehalfOf,
                amount: amount,
                interestRateMode: DataTypes.InterestRateMode(interestRateMode),
                referralCode: referralCode,
                releaseUnderlying: true,
                maxStableRateBorrowSizePercent: _maxStableRateBorrowSizePercent,
                reservesCount: _reservesCount,
                oracle: ADDRESSES_PROVIDER.getPriceOracle(),
                userEModeCategory: _usersEModeCategory[onBehalfOf],
                priceOracleSentinel: ADDRESSES_PROVIDER.getPriceOracleSentinel()
            })
        );
    }

    function repay(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf
    ) public returns (uint256) {
        return
            BorrowLogic.executeRepay(
                _reserves,
                _reservesList,
                _usersConfig[onBehalfOf],
                DataTypes.ExecuteRepayParams({
                    asset: asset,
                    amount: amount,
                    interestRateMode: DataTypes.InterestRateMode(
                        interestRateMode
                    ),
                    onBehalfOf: onBehalfOf,
                    useATokens: false
                })
            );
    }

    function finalizeTransfer(
        address asset,
        address from,
        address to,
        uint256 amount,
        uint256 balanceFromBefore,
        uint256 balanceToBefore
    ) external {
        require(
            msg.sender == _reserves[asset].aTokenAddress,
            Errors.CALLER_NOT_ATOKEN
        );
        SupplyLogic.executeFinalizeTransfer(
            _reserves,
            _reservesList,
            _eModeCategories,
            _usersConfig,
            DataTypes.FinalizeTransferParams({
                asset: asset,
                from: from,
                to: to,
                amount: amount,
                balanceFromBefore: balanceFromBefore,
                balanceToBefore: balanceToBefore,
                reservesCount: _reservesCount,
                oracle: ADDRESSES_PROVIDER.getPriceOracle(),
                fromEModeCategory: _usersEModeCategory[from]
            })
        );
    }

    function initReserve(
        address asset,
        address aTokenAddress,
        address stableDebtAddress,
        address variableDebtAddress,
        address interestRateStrategyAddress
    ) external {
        if (
            PoolLogic.executeInitReserve(
                _reserves,
                _reservesList,
                DataTypes.InitReserveParams({
                    asset: asset,
                    aTokenAddress: aTokenAddress,
                    stableDebtAddress: stableDebtAddress,
                    variableDebtAddress: variableDebtAddress,
                    interestRateStrategyAddress: interestRateStrategyAddress,
                    reservesCount: _reservesCount,
                    maxNumberReserves: MAX_NUMBER_RESERVES()
                })
            )
        ) {
            _reservesCount++;
        }
    }

    function MAX_NUMBER_RESERVES() public pure returns (uint16) {
        return ReserveConfiguration.MAX_RESERVES_COUNT;
    }

    function getReserveData(
        address asset
    ) external view virtual returns (DataTypes.ReserveData memory) {
        return _reserves[asset];
    }

    function setConfiguration(
        address asset,
        DataTypes.ReserveConfigurationMap calldata configuration
    ) external onlyPoolConfigurator {
        require(asset != address(0), Errors.ZERO_ADDRESS_NOT_VALID);
        require(
            _reserves[asset].id != 0 || _reservesList[0] == asset,
            Errors.ASSET_NOT_LISTED
        );
        _reserves[asset].configuration = configuration;
    }

    function configureEModeCategory(
        uint8 id,
        DataTypes.EModeCategory memory category
    ) external virtual override onlyPoolConfigurator {
        // category 0 is reserved for volatile heterogeneous assets and it's always disabled
        require(id != 0, Errors.EMODE_CATEGORY_RESERVED);
        _eModeCategories[id] = category;
    }

    function setUserUseReserveAsCollateral(
        address asset,
        bool useAsCollateral
    ) public {
        SupplyLogic.executeUseReserveAsCollateral(
            _reserves,
            _reservesList,
            _eModeCategories,
            _usersConfig[msg.sender],
            asset,
            useAsCollateral,
            _reservesCount,
            ADDRESSES_PROVIDER.getPriceOracle(),
            _usersEModeCategory[msg.sender]
        );
    }

    function getUserAccountData(
        address user
    )
        external
        view
        virtual
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {
        return
            PoolLogic.executeGetUserAccountData(
                _reserves,
                _reservesList,
                _eModeCategories,
                DataTypes.CalculateUserAccountDataParams({
                    userConfig: _usersConfig[user],
                    reservesCount: _reservesCount,
                    user: user,
                    oracle: ADDRESSES_PROVIDER.getPriceOracle(),
                    userEModeCategory: _usersEModeCategory[user]
                })
            );
    }

    function getConfiguration(
        address asset
    ) external view returns (DataTypes.ReserveConfigurationMap memory) {
        return _reserves[asset].configuration;
    }

    function getUserConfiguration(
        address user
    ) external view virtual returns (DataTypes.UserConfigurationMap memory) {
        return _usersConfig[user];
    }

    function getReserveNormalizedIncome(
        address asset
    ) external view virtual returns (uint256) {
        return _reserves[asset].getNormalizedIncome();
    }

    function getReserveNormalizedVariableDebt(
        address asset
    ) external view virtual returns (uint256) {
        return _reserves[asset].getNormalizedDebt();
    }

    function getReservesList()
        external
        view
        virtual
        returns (address[] memory)
    {
        uint256 reservesListCount = _reservesCount;
        uint256 droppedReservesCount = 0;
        address[] memory reservesList = new address[](reservesListCount);

        for (uint256 i = 0; i < reservesListCount; i++) {
            if (_reservesList[i] != address(0)) {
                reservesList[i - droppedReservesCount] = _reservesList[i];
            } else {
                droppedReservesCount++;
            }
        }

        assembly {
            mstore(reservesList, sub(reservesListCount, droppedReservesCount))
        }
        return reservesList;
    }

    function getUserEMode(
        address user
    ) external view virtual override returns (uint256) {
        return _usersEModeCategory[user];
    }

    function getEModeCategoryData(
        uint8 id
    ) external view virtual override returns (DataTypes.EModeCategory memory) {
        return _eModeCategories[id];
    }

    function resetIsolationModeTotalDebt(
        address asset
    ) external virtual override onlyPoolConfigurator {
        PoolLogic.executeResetIsolationModeTotalDebt(_reserves, asset);
    }
}
