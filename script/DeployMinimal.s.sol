// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {MinimalAccount} from "../src/ethereum/MinimalAccount.sol";

contract DeployMinimal is Script {
    function run() public {}

    function deployMinimalAccount() public returns (HelperConfig, MinimalAccount) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast(config.account);
        MinimalAccount minimalAccount = new MinimalAccount(config.entryPoint);
        // minimalAccount.transferOwnership(msg.sender);
        minimalAccount.transferOwnership(config.account);
        vm.stopBroadcast();

        return (helperConfig, minimalAccount);
    }
}
