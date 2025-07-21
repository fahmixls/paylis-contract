// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";

/**
 * @title Stablecoin Payment Gateway (EIP-2771)
 * @dev Supports multiple stablecoins with dynamic activation and fee management
 *      Fixes: re-entrancy, overflow, unbounded array, duplicate events, 0-address, etc.
 */
contract StablecoinPaymentGateway is ERC2771Context, Ownable, ReentrancyGuard {
    struct TokenConfig {
        bool isActive;
        uint256 fixedFee;
        uint16 percentageFeeBps;
        string symbol;
    }

    mapping(address => TokenConfig) public tokenConfigs;
    address[] public activeTokens;
    mapping(address => uint256) public tokenIndex; // 1-based index, 0 means non-existent
    mapping(address => uint256) public collectedFees;

    /* --------------- EVENTS --------------- */
    event TokenAdded(
        address indexed token,
        string symbol,
        uint256 fixedFee,
        uint16 percentageFeeBps
    );
    event TokenStatusChanged(address indexed token, bool isActive);
    event TokenFeeUpdated(
        address indexed token,
        uint256 newFixedFee,
        uint16 newPercentageFeeBps
    );
    event PaymentProcessed(
        address indexed payer,
        address indexed recipient,
        address indexed token,
        uint256 amount,
        uint256 fee
    );
    event FeesWithdrawn(
        address indexed token,
        address indexed owner,
        uint256 amount
    );

    /* --------------- ERROR --------------- */
    error InvalidToken();
    error EmptySymbol();
    error FixedFeeTooHigh();
    error PercentageFeeTooHigh();
    error TokenUnknown();
    error TokenNotActive();
    error InsufficientBalance();
    error InvalidRecipient();
    error AmountTooSmall();
    error IndexOutOfRange();

    constructor(
        address trustedForwarder
    ) ERC2771Context(trustedForwarder) Ownable(_msgSender()) {}

    /* --------------- OWNER FUNCTIONS --------------- */

    /**
     * @notice Add or update a stablecoin configuration
     */
    function manageToken(
        address token,
        string calldata symbol,
        uint256 fixedFee,
        uint16 percentageFeeBps,
        bool activate
    ) external onlyOwner {
        if (token == address(0)) revert InvalidToken();
        if (bytes(symbol).length == 0) revert EmptySymbol();
        if (fixedFee > 1_000_000 * 10 ** 18) revert FixedFeeTooHigh();
        if (percentageFeeBps > 500) revert PercentageFeeTooHigh();

        bool wasActive = tokenConfigs[token].isActive;
        bool isNew = bytes(tokenConfigs[token].symbol).length == 0;

        tokenConfigs[token] = TokenConfig({
            isActive: activate,
            fixedFee: fixedFee,
            percentageFeeBps: percentageFeeBps,
            symbol: symbol
        });

        // Maintain activeTokens list
        if (activate && !wasActive) {
            activeTokens.push(token);
            tokenIndex[token] = activeTokens.length; // 1-based
        } else if (!activate && wasActive) {
            _removeFromActiveTokens(token);
        }

        if (isNew) emit TokenAdded(token, symbol, fixedFee, percentageFeeBps);
        if (wasActive != activate) emit TokenStatusChanged(token, activate);
    }

    /**
     * @notice Toggle token activation status
     */
    function toggleTokenActive(address token) external onlyOwner {
        if (token == address(0)) revert InvalidToken();
        TokenConfig storage cfg = tokenConfigs[token];
        if (bytes(cfg.symbol).length == 0) revert TokenUnknown();
        bool newStatus = !cfg.isActive;
        cfg.isActive = newStatus;

        if (newStatus) {
            activeTokens.push(token);
            tokenIndex[token] = activeTokens.length;
        } else {
            _removeFromActiveTokens(token);
        }

        emit TokenStatusChanged(token, newStatus);
    }

    /**
     * @notice Update token fees
     */
    function updateTokenFees(
        address token,
        uint256 newFixedFee,
        uint16 newPercentageFeeBps
    ) external onlyOwner {
        if (token == address(0)) revert InvalidToken();
        TokenConfig storage cfg = tokenConfigs[token];
        if (!cfg.isActive) revert TokenNotActive();
        if (newPercentageFeeBps > 500) revert PercentageFeeTooHigh();
        if (newFixedFee > 1_000_000 * 10 ** 18) revert FixedFeeTooHigh();

        cfg.fixedFee = newFixedFee;
        cfg.percentageFeeBps = newPercentageFeeBps;

        emit TokenFeeUpdated(token, newFixedFee, newPercentageFeeBps);
    }

    /**
     * @notice Withdraw collected fees
     * @param token Token address to withdraw
     * @param amount Amount to withdraw (0 = full balance)
     */
    function withdrawFees(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) revert InvalidToken();
        uint256 balance = collectedFees[token];
        uint256 withdrawAmount = amount == 0 ? balance : amount;
        if (withdrawAmount > balance) revert InsufficientBalance();

        collectedFees[token] -= withdrawAmount;
        IERC20(token).transfer(owner(), withdrawAmount);

        emit FeesWithdrawn(token, owner(), withdrawAmount);
    }

    /* --------------- PUBLIC FUNCTIONS --------------- */

    /**
     * @notice Get all active stablecoins with their fee structures
     */
    function getAllActiveTokens()
        external
        view
        returns (address[] memory tokens, TokenConfig[] memory configs)
    {
        tokens = activeTokens;
        configs = new TokenConfig[](tokens.length);
        for (uint256 i = 0; i < tokens.length; ) {
            configs[i] = tokenConfigs[tokens[i]];
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Process stablecoin payment
     */
    function pay(
        address token,
        address recipient,
        uint256 amount
    ) external nonReentrant {
        if (token == address(0)) revert InvalidToken();
        if (recipient == address(0)) revert InvalidRecipient();
        TokenConfig memory cfg = tokenConfigs[token];
        if (!cfg.isActive) revert TokenNotActive();

        uint256 fee = calculateFee(token, amount);
        if (amount <= calculateFee(token, amount)) revert AmountTooSmall();

        // Pull full amount in one call, then split internally
        IERC20(token).transferFrom(_msgSender(), address(this), amount);

        // Forward net amount to recipient
        IERC20(token).transfer(recipient, amount - fee);

        // Account for fee
        collectedFees[token] += fee;

        emit PaymentProcessed(_msgSender(), recipient, token, amount, fee);
    }

    /**
     * @notice Calculate payment fee
     */
    function calculateFee(
        address token,
        uint256 amount
    ) public view returns (uint256) {
        TokenConfig memory cfg = tokenConfigs[token];
        // Use mulDiv to prevent intermediate overflow
        return (amount * cfg.percentageFeeBps) / 10_000 + cfg.fixedFee;
    }

    /* --------------- INTERNAL --------------- */

    /**
     * @dev Remove token from activeTokens array in O(1)
     */
    function _removeFromActiveTokens(address token) internal {
        uint256 idx = tokenIndex[token];
        if (idx == 0 || idx > activeTokens.length) revert IndexOutOfRange(); // Swap with last element

        address last = activeTokens[activeTokens.length - 1];
        activeTokens[idx - 1] = last;
        tokenIndex[last] = idx;

        activeTokens.pop();
        delete tokenIndex[token];
    }

    /* --------------- EIP-2771 OVERRIDES --------------- */
    function _msgSender()
        internal
        view
        virtual
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
