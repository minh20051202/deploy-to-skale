// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {DataTypes} from "../types/DataTypes.sol";
import {IPriceOracleGetter} from "../../interfaces/IPriceOracleGetter.sol";

library EModeLogic {
    function getEModeConfiguration(
        DataTypes.EModeCategory storage category,
        IPriceOracleGetter oracle
    ) internal view returns (uint256, uint256, uint256) {
        uint256 eModeAssetPrice = 0;
        address eModePriceSource = category.priceSource;

        if (eModePriceSource != address(0)) {
            eModeAssetPrice = oracle.getAssetPrice(eModePriceSource);
        }

        return (category.ltv, category.liquidationThreshold, eModeAssetPrice);
    }

    function isInEModeCategory(
        uint256 eModeUserCategory,
        uint256 eModeAssetCategory
    ) internal pure returns (bool) {
        return (eModeUserCategory != 0 &&
            eModeAssetCategory == eModeUserCategory);
    }
}
