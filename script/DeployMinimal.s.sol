// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {MinimalAccount} from "../src/ethereum/MinimalAccount.sol";

/// @title Minimal Account Deployment Script
/// @author Your Name
/// @notice Deploys a Minimal Account implementation compatible with ERC-4337
/// @dev Uses HelperConfig to handle chain-specific EntryPoint addresses and deployment accounts
///      - For local chains: Deploys new EntryPoint and uses Anvil's default account
///      - For testnets: Uses existing EntryPoint and a burner wallet
///      - For zkSync: Handles native AA without EntryPoint
contract DeployMinimal is Script {
    /// @notice Default script execution function
    /// @dev Can be extended to include post-deployment verification and setup

    function run() public {}

    /// @notice Deploys a new MinimalAccount using chain-specific configuration
    /// @dev Automatically handles different network configurations:
    ///      - Uses pre-deployed EntryPoint on testnets
    ///      - Deploys new EntryPoint on local network
    ///      - Transfers ownership to the chain-specific account from HelperConfig
    /// @return helperConfig The configuration contract containing network-specific settings
    /// @return minimalAccount The deployed account contract, initialized with proper EntryPoint
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
