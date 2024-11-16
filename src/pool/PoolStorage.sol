// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {DataTypes} from "../libraries/types/DataTypes.sol";
import {ReserveLogic} from "../libraries/logic/ReserveLogic.sol";
import {ReserveConfiguration} from "../libraries/configuration/ReserveConfiguration.sol";
import {UserConfiguration} from "../libraries/configuration/UserConfiguration.sol";

contract PoolStorage {
    using ReserveLogic for DataTypes.ReserveData;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using UserConfiguration for DataTypes.UserConfigurationMap;

    mapping(address => DataTypes.ReserveData) internal _reserves;

    mapping(uint256 => address) internal _reservesList;

    mapping(address => DataTypes.UserConfigurationMap) internal _usersConfig;

    mapping(uint8 => DataTypes.EModeCategory) internal _eModeCategories;

    mapping(address => uint8) internal _usersEModeCategory;

    uint64 internal _maxStableRateBorrowSizePercent;

    uint16 internal _reservesCount;
}
