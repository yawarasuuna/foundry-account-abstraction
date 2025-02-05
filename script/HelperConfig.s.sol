// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {console2, Script} from "forge-std/Script.sol";
import {EntryPoint} from "lib/account-abstraction/contracts/core/EntryPoint.sol";

/** 
 * @title Helper Configuration for Account Abstraction Deployments
 * @author yawarasuuna
 * @notice Provides network-specific configurations for EntryPoint v0.7.0 and account addresses
 * @dev Handles configuration for Ethereum, Arbitrum, and zkSync chains, with special handling for local development
 */
contract HelperConfig is Script {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        address entryPoint;
        address account;
    }

    /** 
     * @notice Chain IDs for supported networks
     */
    uint256 constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant ARBITRUM_MAINNET_CHAIN_ID = 42161;
    uint256 constant ARBITRUM_SEPOLIA_CHAIN_ID = 421614;
    uint256 constant ZKSYNC_MAINNET_CHAIN_ID = 324;
    uint256 constant ZKSYNC_SEPOLIA_CHAIN_ID = 300;
    uint256 constant LOCAL_CHAIN_ID = 31337;

    /** 
     * @notice Pre-defined wallet addresses
     */
    address constant BURNER_WALLET = 0xaE95d1cd4573c693364E7b52598dDd2C28dA3aFE;
    // address constant FOUNDRY_DEFAULT_WALLET = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
    address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    /** 
     * @notice Configuration for local network deployments
     */
    NetworkConfig public localNetworkConfig;

    /** 
     * @notice Mapping of chainId to network specific configurations
     */
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    /** 
     * @notice Initializes network configurations for test networks
     */
    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaEth();
        networkConfigs[ARBITRUM_SEPOLIA_CHAIN_ID] = getArbitrumSepoliaEth();
        networkConfigs[ZKSYNC_SEPOLIA_CHAIN_ID] = getZkSyncSepoliaEth();
    }

    /** 
     * @notice Gets configuration for the current chain
     * @return NetworkConfig for the current chainId
     */
    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    /** 
     * @notice Gets configuration for a specific chain ID
     * @dev Returns local config for development, stored config for known networks, reverts for unknown chains
     * @param chainId The chain ID to get configuration for
     * @return NetworkConfig memory The network-specific configuration
     */
    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreatAnvilEthConfig();
        } else if (networkConfigs[chainId].account != address(0)) {
            return networkConfigs[chainId];
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    /** 
     * @notice Configuration for Ethereum Sepolia
     * @dev Uses canonical EntryPoint v0.7.0 address and burner wallet
     * @return NetworkConfig for Ethereum Sepolia
     */
    function getEthSepoliaEth() public pure returns (NetworkConfig memory) {
        return NetworkConfig({entryPoint: 0x0000000071727De22E5E9d8BAf0edAc6f37da032, account: BURNER_WALLET});
    }

    /** 
     * @notice Configuration for Arbitrum Sepolia
     * @dev Uses same EntryPoint v0.7.0 address as Ethereum Sepolia
     * @return NetworkConfig for Arbitrum Sepolia
     */
    function getArbitrumSepoliaEth() public pure returns (NetworkConfig memory) {
        return NetworkConfig({entryPoint: 0x0000000071727De22E5E9d8BAf0edAc6f37da032, account: BURNER_WALLET});
    }

    /** 
     * @notice Configuration for zkSync Sepolia
     * @dev Uses zero address for EntryPoint due to native AA support
     * @return NetworkConfig for zkSync Sepolia
     */
    function getZkSyncSepoliaEth() public pure returns (NetworkConfig memory) {
        return NetworkConfig({entryPoint: address(0), account: BURNER_WALLET}); // it has native AA
    }

    /** 
     * @notice Gets or creates local network configuration
     * @dev Deploys new EntryPoint v0.7.0 if not already deployed
     * @return NetworkConfig for local development
     */
    function getOrCreatAnvilEthConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.account != address(0)) {
            return localNetworkConfig;
        }

        console2.log("Deploying mocks:");
        vm.startBroadcast(ANVIL_DEFAULT_ACCOUNT);
        EntryPoint entryPoint = new EntryPoint();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({entryPoint: address(entryPoint), account: ANVIL_DEFAULT_ACCOUNT});

        return localNetworkConfig;
    }
}
