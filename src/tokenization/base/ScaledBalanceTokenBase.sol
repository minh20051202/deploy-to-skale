// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {WadRayMath} from "../../libraries/math/WadRayMath.sol";
import {IPool} from "../../interfaces/IPool.sol";
import {MintableIncentivizedERC20} from "./MintableIncentivizedERC20.sol";
import {IScaledBalanceToken} from "../../interfaces/IScaledBalanceToken.sol";
import {Errors} from "../../libraries/helpers/Errors.sol";

abstract contract ScaledBalanceTokenBase is
    MintableIncentivizedERC20,
    IScaledBalanceToken
{
    using WadRayMath for uint256;
    using SafeCast for uint256;

    constructor(
        IPool pool,
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) MintableIncentivizedERC20(pool, name_, symbol_, decimals_) {}

    function scaledBalanceOf(address user) external view returns (uint256) {
        return super.balanceOf(user);
    }

    function getScaledUserBalanceAndSupply(
        address user
    ) external view returns (uint256, uint256) {
        return (super.balanceOf(user), super.totalSupply());
    }

    function scaledTotalSupply() public view virtual returns (uint256) {
        return super.totalSupply();
    }

    function getPreviousIndex(
        address user
    ) external view virtual returns (uint256) {
        return _userState[user].additionalData;
    }

    function _mintScaled(
        address caller,
        address onBehalfOf,
        uint256 amount,
        uint256 index
    ) internal returns (bool) {
        uint256 amountScaled = amount.rayDiv(index);
        require(amountScaled != 0, Errors.INVALID_MINT_AMOUNT);

        uint256 scaledBalance = super.balanceOf(onBehalfOf);
        uint256 balanceIncrease = scaledBalance.rayMul(index) -
            scaledBalance.rayMul(_userState[onBehalfOf].additionalData);

        _userState[onBehalfOf].additionalData = index.toUint128();

        _mint(onBehalfOf, amountScaled.toUint128());

        uint256 amountToMint = amount + balanceIncrease;
        emit Transfer(address(0), onBehalfOf, amountToMint);
        emit Mint(caller, onBehalfOf, amountToMint, balanceIncrease, index);

        return (scaledBalance == 0);
    }

    function _burnScaled(
        address user,
        address target,
        uint256 amount,
        uint256 index
    ) internal {
        uint256 amountScaled = amount.rayDiv(index);
        require(amountScaled != 0, Errors.INVALID_BURN_AMOUNT);

        uint256 scaledBalance = super.balanceOf(user);
        uint256 balanceIncrease = scaledBalance.rayMul(index) -
            scaledBalance.rayMul(_userState[user].additionalData);

        _userState[user].additionalData = index.toUint128();

        _burn(user, amountScaled.toUint128());

        if (balanceIncrease > amount) {
            uint256 amountToMint = balanceIncrease - amount;
            emit Transfer(address(0), user, amountToMint);
            emit Mint(user, user, amountToMint, balanceIncrease, index);
        } else {
            uint256 amountToBurn = amount - balanceIncrease;
            emit Transfer(user, address(0), amountToBurn);
            emit Burn(user, target, amountToBurn, balanceIncrease, index);
        }
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount,
        uint256 index
    ) internal {
        uint256 senderScaledBalance = super.balanceOf(sender);
        uint256 senderBalanceIncrease = senderScaledBalance.rayMul(index) -
            senderScaledBalance.rayMul(_userState[sender].additionalData);

        uint256 recipientScaledBalance = super.balanceOf(recipient);
        uint256 recipientBalanceIncrease = recipientScaledBalance.rayMul(
            index
        ) - recipientScaledBalance.rayMul(_userState[recipient].additionalData);

        _userState[sender].additionalData = index.toUint128();
        _userState[recipient].additionalData = index.toUint128();

        super._transfer(sender, recipient, amount.rayDiv(index).toUint128());

        if (senderBalanceIncrease > 0) {
            emit Transfer(address(0), sender, senderBalanceIncrease);
            emit Mint(
                _msgSender(),
                sender,
                senderBalanceIncrease,
                senderBalanceIncrease,
                index
            );
        }

        if (sender != recipient && recipientBalanceIncrease > 0) {
            emit Transfer(address(0), recipient, recipientBalanceIncrease);
            emit Mint(
                _msgSender(),
                recipient,
                recipientBalanceIncrease,
                recipientBalanceIncrease,
                index
            );
        }

        emit Transfer(sender, recipient, amount);
    }
}
