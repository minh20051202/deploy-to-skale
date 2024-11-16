// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {EIP712Base} from "./EIP712Base.sol";
import {Errors} from "../../libraries/helpers/Errors.sol";

abstract contract DebtTokenBase is Context, EIP712Base {
    event BorrowAllowanceDelegated(
        address indexed fromUser,
        address indexed toUser,
        address indexed asset,
        uint256 amount
    );

    mapping(address => mapping(address => uint256)) internal _borrowAllowances;

    bytes32 public constant DELEGATION_WITH_SIG_TYPEHASH =
        keccak256(
            "DelegationWithSig(address delegatee,uint256 value,uint256 nonce,uint256 deadline)"
        );

    address internal _underlyingAsset;

    constructor() EIP712Base() {}

    function approveDelegation(address delegatee, uint256 amount) external {
        _approveDelegation(_msgSender(), delegatee, amount);
    }

    function delegationWithSig(
        address delegator,
        address delegatee,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(delegator != address(0), Errors.ZERO_ADDRESS_NOT_VALID);
        //solium-disable-next-line
        require(block.timestamp <= deadline, Errors.INVALID_EXPIRATION);
        uint256 currentValidNonce = _nonces[delegator];
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        DELEGATION_WITH_SIG_TYPEHASH,
                        delegatee,
                        value,
                        currentValidNonce,
                        deadline
                    )
                )
            )
        );
        require(
            delegator == ecrecover(digest, v, r, s),
            Errors.INVALID_SIGNATURE
        );
        _nonces[delegator] = currentValidNonce + 1;
        _approveDelegation(delegator, delegatee, value);
    }

    function borrowAllowance(
        address fromUser,
        address toUser
    ) external view returns (uint256) {
        return _borrowAllowances[fromUser][toUser];
    }

    function _approveDelegation(
        address delegator,
        address delegatee,
        uint256 amount
    ) internal {
        _borrowAllowances[delegator][delegatee] = amount;
        emit BorrowAllowanceDelegated(
            delegator,
            delegatee,
            _underlyingAsset,
            amount
        );
    }

    function _decreaseBorrowAllowance(
        address delegator,
        address delegatee,
        uint256 amount
    ) internal {
        uint256 newAllowance = _borrowAllowances[delegator][delegatee] - amount;

        _borrowAllowances[delegator][delegatee] = newAllowance;

        emit BorrowAllowanceDelegated(
            delegator,
            delegatee,
            _underlyingAsset,
            newAllowance
        );
    }
}
