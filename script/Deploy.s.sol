// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script} from "forge-std/Script.sol";
import {PaymentGateway} from "../src/PaymentGateway.sol";

contract DeployPaymentGateway is Script {
    /// @dev Change these defaults or override via env vars
    address constant TRUSTED_FORWARDER = address(0); // set real forwarder if needed

    function run() external returns (PaymentGateway gateway) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.envAddress("OWNER");
        address feeCollector = vm.envAddress("FEE_COLLECTOR");

        vm.startBroadcast(deployerKey);

        gateway = new PaymentGateway(TRUSTED_FORWARDER, owner, feeCollector);

        vm.stopBroadcast();
    }
}
