// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {WadRayMath} from "../math/WadRayMath.sol";

library MathUtils {
    uint256 internal constant SECONDS_PER_YEAR = 365 days;

    using WadRayMath for uint256;

    function calculateLinearInterest(
        uint256 rate,
        uint40 lastUpdateTimestamp
    ) internal view returns (uint256) {
        uint256 result = rate *
            (block.timestamp - uint256(lastUpdateTimestamp));
        unchecked {
            result = result / SECONDS_PER_YEAR;
        }

        return WadRayMath.RAY + result;
    }

    function calculateCompoundedInterest(
        uint256 rate,
        uint40 lastUpdateTimestamp,
        uint256 currentTimestamp
    ) internal pure returns (uint256) {
        uint256 exp = currentTimestamp - uint256(lastUpdateTimestamp);
        if (exp == 0) {
            return WadRayMath.RAY;
        }

        uint256 expMinusOne;
        uint256 expMinusTwo;
        uint256 basePowerTwo;
        uint256 basePowerThree;

        unchecked {
            expMinusOne = exp - 1;
            expMinusTwo = exp > 2 ? exp - 2 : 0;
            basePowerTwo =
                rate.rayMul(rate) /
                (SECONDS_PER_YEAR * SECONDS_PER_YEAR);
            basePowerThree = basePowerTwo.rayMul(rate) / SECONDS_PER_YEAR;
        }

        uint256 secondTerm = exp * expMinusOne * basePowerTwo;
        unchecked {
            secondTerm /= 2;
        }

        uint256 thirdTerm = exp * expMinusOne * expMinusTwo * basePowerThree;
        unchecked {
            thirdTerm /= 6;
        }

        return
            WadRayMath.RAY +
            (rate * exp) /
            SECONDS_PER_YEAR +
            secondTerm +
            thirdTerm;
    }
}
