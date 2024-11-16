// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {WadRayMath} from "../../libraries/math/WadRayMath.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IPool} from "../../interfaces/IPool.sol";
import {IIncentivesController} from "../../interfaces/IIncentivesController.sol";
import {Errors} from "../../libraries/helpers/Errors.sol";

abstract contract IncentivizedERC20 is Context, IERC20Metadata {
    using WadRayMath for uint256;
    using SafeCast for uint256;

    struct UserState {
        uint128 balance;
        uint128 additionalData;
    }

    mapping(address => UserState) internal _userState;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 internal _totalSupply;
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    IIncentivesController internal _incentivesController;

    IPool public immutable POOL;

    modifier onlyPool() {
        require(_msgSender() == address(POOL), Errors.CALLER_MUST_BE_POOL);
        _;
    }

    constructor(
        IPool pool,
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) {
        // _addressesProvider = pool.ADDRESSES_PROVIDER();
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        POOL = pool;
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() external view override returns (string memory) {
        return _symbol;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(
        address account
    ) public view virtual override returns (uint256) {
        return _userState[account].balance;
    }

    function getIncentivesController()
        external
        view
        virtual
        returns (IIncentivesController)
    {
        return _incentivesController;
    }

    function setIncentivesController(
        IIncentivesController controller
    ) external {
        _incentivesController = controller;
    }

    function transfer(
        address recipient,
        uint256 amount
    ) external virtual override returns (bool) {
        uint128 castAmount = amount.toUint128();
        _transfer(_msgSender(), recipient, castAmount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) external view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) external virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external virtual override returns (bool) {
        uint128 castAmount = amount.toUint128();
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()] - castAmount
        );
        _transfer(sender, recipient, castAmount);
        return true;
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) external virtual returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) external virtual returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] - subtractedValue
        );
        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint128 amount
    ) internal virtual {
        uint128 oldSenderBalance = _userState[sender].balance;
        _userState[sender].balance = oldSenderBalance - amount;
        uint128 oldRecipientBalance = _userState[recipient].balance;
        _userState[recipient].balance = oldRecipientBalance + amount;

        IIncentivesController incentivesControllerLocal = _incentivesController;
        if (address(incentivesControllerLocal) != address(0)) {
            uint256 currentTotalSupply = _totalSupply;
            incentivesControllerLocal.handleAction(
                sender,
                currentTotalSupply,
                oldSenderBalance
            );
            if (sender != recipient) {
                incentivesControllerLocal.handleAction(
                    recipient,
                    currentTotalSupply,
                    oldRecipientBalance
                );
            }
        }
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _setName(string memory newName) internal {
        _name = newName;
    }

    function _setSymbol(string memory newSymbol) internal {
        _symbol = newSymbol;
    }

    function _setDecimals(uint8 newDecimals) internal {
        _decimals = newDecimals;
    }
}
