// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {DataTypes} from "../libraries/types/DataTypes.sol";

interface IReserveInterestRateStrategy {
    function calculateInterestRates(
        DataTypes.CalculateInterestRatesParams memory params
    ) external view returns (uint256, uint256, uint256);
}
