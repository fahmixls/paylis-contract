// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script} from "forge-std/Script.sol";
import {StablecoinPaymentGateway} from "../src/StablecoinPaymentGateway.sol";

contract DeployGateway is Script {
    /// @dev Change this if you already have a trusted-forwarder address.
    address constant TRUSTED_FORWARDER = address(0);

    function run() external returns (StablecoinPaymentGateway gateway) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerKey);

        gateway = new StablecoinPaymentGateway(TRUSTED_FORWARDER);

        vm.stopBroadcast();
    }
}
