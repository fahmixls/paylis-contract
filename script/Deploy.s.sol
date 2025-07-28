// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script, console2} from "forge-std/Script.sol";
import {MinimalForwarder} from "../src/MinimalForwarder.sol";
import {PaymentGateway} from "../src/PaymentGateway.sol";

contract DeployScript is Script {
    function run() external {
        // Load addresses from .env file
        address owner = vm.envAddress("OWNER_ADDRESS");
        address feeCollector = vm.envAddress("FEE_COLLECTOR_ADDRESS");

        // Load token addresses from .env
        address mockUSDC = vm.envAddress("MOCK_USDC_ADDRESS");
        address mockIDRX = vm.envAddress("MOCK_IDRX_ADDRESS");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console2.log("=== DEPLOYING TO LISK SEPOLIA ===");

        // Deploy MinimalForwarder
        console2.log("Deploying MinimalForwarder...");
        MinimalForwarder forwarder = new MinimalForwarder();
        console2.log("MinimalForwarder deployed at:", address(forwarder));

        // Deploy PaymentGateway
        console2.log("Deploying PaymentGateway...");
        PaymentGateway paymentGateway = new PaymentGateway(
            address(forwarder),
            owner,
            feeCollector
        );
        console2.log("PaymentGateway deployed at:", address(paymentGateway));

        // Setup initial tokens
        console2.log("Setting up tokens...");

        paymentGateway.manageToken(mockUSDC, "USDC", true);
        console2.log("Mock USDC added and activated");

        paymentGateway.manageToken(mockIDRX, "IDRX", true);
        console2.log("Mock IDRX added and activated");

        vm.stopBroadcast();

        // Log deployment summary
        console2.log("\n=== DEPLOYMENT SUMMARY ===");
        console2.log("Network: Lisk Sepolia");
        console2.log("MinimalForwarder:", address(forwarder));
        console2.log("PaymentGateway:", address(paymentGateway));
        console2.log("Owner:", owner);
        console2.log("Fee Collector:", feeCollector);
        console2.log("Active Tokens:");
        console2.log("  - USDC:", mockUSDC);
        console2.log("  - IDRX:", mockIDRX);
        console2.log("========================\n");

        // Output deployment addresses for manual copying
        console2.log("\n=== COPY THESE TO YOUR .env FILE ===");
        console2.log("FORWARDER_ADDRESS=", vm.toString(address(forwarder)));
        console2.log(
            "PAYMENT_GATEWAY_ADDRESS=",
            vm.toString(address(paymentGateway))
        );
        console2.log("===================================");
    }
}
