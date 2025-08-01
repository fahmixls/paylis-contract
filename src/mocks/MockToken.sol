// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockToken
 * @dev Simple mock ERC20 token with permit functionality
 */
contract MockToken is ERC20, ERC20Permit, Ownable {
    uint8 private _decimals;
    uint256 public constant PUBLIC_MINT_LIMIT = 1000; // Max tokens others can mint (considering decimals)
    
    mapping(address => uint256) public mintedByUser;

    constructor(
        address _owner,
        string memory name,
        string memory symbol,
        uint8 decimals_
    ) ERC20(name, symbol) ERC20Permit(name) Ownable(_owner) {
        _decimals = decimals_;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Owner can mint unlimited tokens
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint (with decimals considered)
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount * 10**_decimals);
    }

    /**
     * @dev Public mint with limit for testing
     * @param amount Amount of tokens to mint (with decimals considered)
     */
    function publicMint(uint256 amount) external {
        require(mintedByUser[msg.sender] + amount <= PUBLIC_MINT_LIMIT, "Exceeds public mint limit");
        
        mintedByUser[msg.sender] += amount;
        _mint(msg.sender, amount * 10**_decimals);
    }
}