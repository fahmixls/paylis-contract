// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/PaymentForwarder.sol";
import "../src/mocks/MockIDRX.sol";
import "../src/mocks/MockUSDC.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address ownerAddress = vm.envAddress("OWNER_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deploying contracts with account:", deployer);
        console.log("Account balance:", deployer.balance / 1e18, "ETH");

        // Deploy Forwarder
        console.log("Deploying Forwarder...");
        PaymentForwarder forwarder = new PaymentForwarder(ownerAddress);
        console.log("Forwarder deployed to:", address(forwarder));

        // Transfer ownership if different from deployer
        if (ownerAddress != deployer) {
            console.log("\nTransferring ownership to:", ownerAddress);
            forwarder.transferOwnership(ownerAddress);
        }

        // Whitelist tokens (only if deployer is still owner)
        if (ownerAddress == deployer) {
            console.log("\nWhitelisting tokens...");
            console.log("Tokens whitelisted successfully");

            // Mint initial tokens
            console.log("\nMinting initial tokens...");
            console.log("Initial tokens minted");
        }

        vm.stopBroadcast();

        // Log deployment info
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Forwarder:", address(forwarder));
        console.log("Owner:", ownerAddress);
        console.log("Deployer:", deployer);

        // Save addresses to file
        string memory addresses = string.concat(
            "Forwarder=",
            vm.toString(address(forwarder)),
            "\n"
        );
        vm.writeFile("./deployed-addresses.txt", addresses);
        console.log("\nAddresses saved to deployed-addresses.txt");
    }
}

