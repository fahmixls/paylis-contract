// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "./MockToken.sol";

/**
 * @title MockUSDC
 * @dev IDRX mock with 2 decimals
 */
contract MockUSDC is MockToken {
    constructor(address _owner) MockToken(_owner, "Mock USD Coin", "USDC", 6) {}
}