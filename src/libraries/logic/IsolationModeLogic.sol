// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {DataTypes} from "../types/DataTypes.sol";
import {ReserveConfiguration} from "../configuration/ReserveConfiguration.sol";
import {UserConfiguration} from "../configuration/UserConfiguration.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

library IsolationModeLogic {
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using UserConfiguration for DataTypes.UserConfigurationMap;
    using SafeCast for uint256;

    event IsolationModeTotalDebtUpdated(
        address indexed asset,
        uint256 totalDebt
    );

    function updateIsolatedDebtIfIsolated(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        DataTypes.UserConfigurationMap storage userConfig,
        DataTypes.ReserveCache memory reserveCache,
        uint256 repayAmount
    ) internal {
        (
            bool isolationModeActive,
            address isolationModeCollateralAddress,

        ) = userConfig.getIsolationModeState(reservesData, reservesList);

        if (isolationModeActive) {
            uint128 isolationModeTotalDebt = reservesData[
                isolationModeCollateralAddress
            ].isolationModeTotalDebt;

            uint128 isolatedDebtRepaid = (repayAmount /
                10 **
                    (reserveCache.reserveConfiguration.getDecimals() -
                        ReserveConfiguration.DEBT_CEILING_DECIMALS))
                .toUint128();

            // since the debt ceiling does not take into account the interest accrued, it might happen that amount
            // repaid > debt in isolation mode
            if (isolationModeTotalDebt <= isolatedDebtRepaid) {
                reservesData[isolationModeCollateralAddress]
                    .isolationModeTotalDebt = 0;
                emit IsolationModeTotalDebtUpdated(
                    isolationModeCollateralAddress,
                    0
                );
            } else {
                uint256 nextIsolationModeTotalDebt = reservesData[
                    isolationModeCollateralAddress
                ].isolationModeTotalDebt =
                    isolationModeTotalDebt -
                    isolatedDebtRepaid;
                emit IsolationModeTotalDebtUpdated(
                    isolationModeCollateralAddress,
                    nextIsolationModeTotalDebt
                );
            }
        }
    }
}
