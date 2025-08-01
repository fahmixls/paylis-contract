// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "./MockToken.sol";

/**
 * @title MockIDRX
 * @dev IDRX mock with 2 decimals
 */
contract MockIDRX is MockToken {
    constructor(address _owner) MockToken(_owner, "Mock Indonesian Rupiah Token", "IDRX", 2) {}
}