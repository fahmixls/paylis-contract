// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";

/**
 * @title PaymentGateway
 * @notice EIP-2771 meta-tx capable payment gateway
 * @dev   – Accepts any ERC-20 that owner activates
 *        – Fee taken as basis-points, supplied at call-time
 *        – Immutable fee collector (gas saving)
 */
contract PaymentGateway is ERC2771Context, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/
    error ZeroAddress();
    error ZeroAmount();
    error FeeTooHigh(); // > 10_000 bps
    error TokenNotActive();
    error TokenUnknown();
    error NoFeesToSweep();

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/
    event TokenAdded(address indexed token, string symbol);
    event TokenStatusChanged(address indexed token, bool isActive);
    event Paid(
        address indexed token,
        address indexed payer,
        address indexed receiver,
        uint256 amount,
        uint256 fee
    );
    event FeesSwept(address indexed token, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/
    struct TokenConfig {
        bool isActive;
        string symbol;
    }

    mapping(address => TokenConfig) public tokenConfig;
    address[] public activeTokens;
    mapping(address => uint256) public tokenIndex; // 1-based

    mapping(address => uint256) public accumulatedFees;
    address public immutable feeCollector;

    /*//////////////////////////////////////////////////////////////
                           INITIALIZATION
    //////////////////////////////////////////////////////////////*/
    constructor(
        address trustedForwarder,
        address _owner,
        address _feeCollector
    ) ERC2771Context(trustedForwarder) Ownable(_owner) {
        if (_owner == address(0)) revert ZeroAddress();
        if (_feeCollector == address(0)) revert ZeroAddress();
        feeCollector = _feeCollector;
    }

    /*//////////////////////////////////////////////////////////////
                        OWNER ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function manageToken(
        address token,
        string calldata symbol,
        bool activate
    ) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (bytes(symbol).length == 0) revert ZeroAmount(); // re-use error

        bool wasActive = tokenConfig[token].isActive;
        bool isNew = bytes(tokenConfig[token].symbol).length == 0;

        tokenConfig[token] = TokenConfig({isActive: activate, symbol: symbol});

        if (activate && !wasActive) {
            activeTokens.push(token);
            tokenIndex[token] = activeTokens.length;
        } else if (!activate && wasActive) {
            _removeFromActive(token);
        }

        if (isNew) emit TokenAdded(token, symbol);
        if (wasActive != activate) emit TokenStatusChanged(token, activate);
    }

    function toggleTokenActive(address token) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        TokenConfig storage cfg = tokenConfig[token];
        if (bytes(cfg.symbol).length == 0) revert TokenUnknown();

        bool newStatus = !cfg.isActive;
        cfg.isActive = newStatus;

        if (newStatus) {
            activeTokens.push(token);
            tokenIndex[token] = activeTokens.length;
        } else {
            _removeFromActive(token);
        }

        emit TokenStatusChanged(token, newStatus);
    }

    /*//////////////////////////////////////////////////////////////
                        FEE SWEEP (OWNER)
    //////////////////////////////////////////////////////////////*/
    function sweep(address token) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        uint256 fees = accumulatedFees[token];
        if (fees == 0) revert NoFeesToSweep();

        accumulatedFees[token] = 0;
        IERC20(token).safeTransfer(feeCollector, fees);

        emit FeesSwept(token, fees);
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC PAY FUNCTION
    //////////////////////////////////////////////////////////////*/
    function pay(
        address token,
        address receiver,
        uint256 amount,
        uint256 feeBps
    ) external nonReentrant {
        if (token == address(0)) revert ZeroAddress();
        if (receiver == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (feeBps > 10_000) revert FeeTooHigh();
        if (!tokenConfig[token].isActive) revert TokenNotActive();

        uint256 fee;
        uint256 net;
        unchecked {
            fee = (amount * feeBps) / 10_000;
            net = amount - fee;
        }

        IERC20(token).safeTransferFrom(_msgSender(), address(this), amount);
        if (net > 0) IERC20(token).safeTransfer(receiver, net);
        if (fee > 0) accumulatedFees[token] += fee;

        emit Paid(token, _msgSender(), receiver, amount, fee);
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW HELPERS
    //////////////////////////////////////////////////////////////*/
    function getAllActive()
        external
        view
        returns (address[] memory tokens, string[] memory symbols)
    {
        tokens = activeTokens;
        symbols = new string[](tokens.length);
        for (uint256 i; i < tokens.length; ) {
            symbols[i] = tokenConfig[tokens[i]].symbol;
            unchecked {
                ++i;
            }
        }
    }

    function getAccumulatedFees(address token) external view returns (uint256) {
        return accumulatedFees[token];
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL UTILS
    //////////////////////////////////////////////////////////////*/
    function _removeFromActive(address token) internal {
        uint256 idx = tokenIndex[token];
        if (idx == 0 || idx > activeTokens.length) return; // defensive

        address last = activeTokens[activeTokens.length - 1];
        activeTokens[idx - 1] = last;
        tokenIndex[last] = idx;

        activeTokens.pop();
        delete tokenIndex[token];
    }

    /*//////////////////////////////////////////////////////////////
                    EIP-2771 OVERRIDES
    //////////////////////////////////////////////////////////////*/
    function _msgSender()
        internal
        view
        override(ERC2771Context, Context)
        returns (address sender)
    {
        return ERC2771Context._msgSender();
    }

    function _msgData()
        internal
        view
        override(ERC2771Context, Context)
        returns (bytes calldata)
    {
        return ERC2771Context._msgData();
    }

    function _contextSuffixLength()
        internal
        view
        override(ERC2771Context, Context)
        returns (uint256)
    {
        return ERC2771Context._contextSuffixLength();
    }
}
