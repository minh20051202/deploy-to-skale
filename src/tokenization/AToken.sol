// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {WadRayMath} from "../libraries/math/WadRayMath.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IAToken} from "../interfaces/IAToken.sol";
import {EIP712Base} from "./base/EIP712Base.sol";
import {ScaledBalanceTokenBase} from "./base/ScaledBalanceTokenBase.sol";
import {IncentivizedERC20} from "./base/IncentivizedERC20.sol";
import {IPool} from "../interfaces/IPool.sol";
import {IIncentivesController} from "../interfaces/IIncentivesController.sol";
import {Errors} from "../libraries/helpers/Errors.sol";

contract AToken is ScaledBalanceTokenBase, EIP712Base, IAToken {
    using WadRayMath for uint256;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

    bytes32 public constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    address internal _underlyingAsset;
    address internal _treasury;

    constructor(
        IPool pool,
        address treasury,
        address underlyingAsset,
        IIncentivesController incentivesController,
        uint8 aTokenDecimals,
        string memory aTokenName,
        string memory aTokenSymbol
    ) ScaledBalanceTokenBase(pool, aTokenName, aTokenSymbol, aTokenDecimals) {
        _treasury = treasury;
        _underlyingAsset = underlyingAsset;
        _incentivesController = incentivesController;

        _domainSeparator = _calculateDomainSeparator();
    }

    function mint(
        address caller,
        address onBehalfOf,
        uint256 amount,
        uint256 index
    ) external virtual override onlyPool returns (bool) {
        return _mintScaled(caller, onBehalfOf, amount, index);
    }

    function burn(
        address from,
        address receiverOfUnderlying,
        uint256 amount,
        uint256 index
    ) external virtual override onlyPool {
        _burnScaled(from, receiverOfUnderlying, amount, index);
        if (receiverOfUnderlying != address(this)) {
            IERC20(_underlyingAsset).safeTransfer(receiverOfUnderlying, amount);
        }
    }

    function mintToTreasury(
        uint256 amount,
        uint256 index
    ) external virtual override onlyPool {
        if (amount == 0) {
            return;
        }
        _mintScaled(address(POOL), _treasury, amount, index);
    }

    function transferOnLiquidation(
        address from,
        address to,
        uint256 value
    ) external virtual override onlyPool {
        // Being a normal transfer, the Transfer() and BalanceTransfer() are emitted
        // so no need to emit a specific event here
        _transfer(from, to, value, false);
    }

    function balanceOf(
        address user
    )
        public
        view
        virtual
        override(IncentivizedERC20, IERC20)
        returns (uint256)
    {
        return
            super.balanceOf(user).rayMul(
                POOL.getReserveNormalizedIncome(_underlyingAsset)
            );
    }

    function totalSupply()
        public
        view
        virtual
        override(IncentivizedERC20, IERC20)
        returns (uint256)
    {
        uint256 currentSupplyScaled = super.totalSupply();

        if (currentSupplyScaled == 0) {
            return 0;
        }

        return
            currentSupplyScaled.rayMul(
                POOL.getReserveNormalizedIncome(_underlyingAsset)
            );
    }

    function RESERVE_TREASURY_ADDRESS()
        external
        view
        override
        returns (address)
    {
        return _treasury;
    }

    function UNDERLYING_ASSET_ADDRESS()
        external
        view
        override
        returns (address)
    {
        return _underlyingAsset;
    }

    function transferUnderlyingTo(
        address target,
        uint256 amount
    ) external virtual override onlyPool {
        IERC20(_underlyingAsset).safeTransfer(target, amount);
    }

    function handleRepayment(
        address user,
        address onBehalfOf,
        uint256 amount
    ) external virtual override onlyPool {}

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        require(owner != address(0), Errors.ZERO_ADDRESS_NOT_VALID);
        //solium-disable-next-line
        require(block.timestamp <= deadline, Errors.INVALID_EXPIRATION);
        uint256 currentValidNonce = _nonces[owner];
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        PERMIT_TYPEHASH,
                        owner,
                        spender,
                        value,
                        currentValidNonce,
                        deadline
                    )
                )
            )
        );
        require(owner == ecrecover(digest, v, r, s), Errors.INVALID_SIGNATURE);
        _nonces[owner] = currentValidNonce + 1;
        _approve(owner, spender, value);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount,
        bool validate
    ) internal virtual {
        address underlyingAsset = _underlyingAsset;

        uint256 index = POOL.getReserveNormalizedIncome(underlyingAsset);

        uint256 fromBalanceBefore = super.balanceOf(from).rayMul(index);
        uint256 toBalanceBefore = super.balanceOf(to).rayMul(index);

        super._transfer(from, to, amount, index);

        if (validate) {
            POOL.finalizeTransfer(
                underlyingAsset,
                from,
                to,
                amount,
                fromBalanceBefore,
                toBalanceBefore
            );
        }

        emit BalanceTransfer(from, to, amount.rayDiv(index), index);
    }

    function _transfer(
        address from,
        address to,
        uint128 amount
    ) internal virtual override {
        _transfer(from, to, amount, true);
    }

    function DOMAIN_SEPARATOR()
        public
        view
        override(IAToken, EIP712Base)
        returns (bytes32)
    {
        return super.DOMAIN_SEPARATOR();
    }

    function nonces(
        address owner
    ) public view override(IAToken, EIP712Base) returns (uint256) {
        return super.nonces(owner);
    }

    function _EIP712BaseId() internal view override returns (string memory) {
        return name();
    }

    function rescueTokens(
        address token,
        address to,
        uint256 amount
    ) external override /*onlyPoolAdmin*/ {
        require(token != _underlyingAsset, Errors.UNDERLYING_CANNOT_BE_RESCUED);
        IERC20(token).safeTransfer(to, amount);
    }
}
