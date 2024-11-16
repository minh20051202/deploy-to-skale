// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IPoolAddressesProvider} from "../interfaces/IPoolAddressesProvider.sol";
import {DataTypes} from "../libraries/types/DataTypes.sol";

interface IPool {
    function ADDRESSES_PROVIDER()
        external
        view
        returns (IPoolAddressesProvider);

    function finalizeTransfer(
        address asset,
        address from,
        address to,
        uint256 amount,
        uint256 balanceFromBefore,
        uint256 balanceToBefore
    ) external;

    function configureEModeCategory(
        uint8 id,
        DataTypes.EModeCategory memory config
    ) external;

    function resetIsolationModeTotalDebt(address asset) external;

    function getReserveNormalizedIncome(
        address asset
    ) external view returns (uint256);

    function getReserveNormalizedVariableDebt(
        address asset
    ) external view returns (uint256);

    function setUserUseReserveAsCollateral(
        address asset,
        bool useAsCollateral
    ) external;

    function setConfiguration(
        address asset,
        DataTypes.ReserveConfigurationMap calldata configuration
    ) external;

    function getConfiguration(
        address asset
    ) external view returns (DataTypes.ReserveConfigurationMap memory);

    function getReservesList() external view returns (address[] memory);

    function getUserConfiguration(
        address user
    ) external view returns (DataTypes.UserConfigurationMap memory);

    function getUserEMode(address user) external view returns (uint256);

    function getReserveData(
        address asset
    ) external view returns (DataTypes.ReserveData memory);

    function getEModeCategoryData(
        uint8 id
    ) external view returns (DataTypes.EModeCategory memory);
}
