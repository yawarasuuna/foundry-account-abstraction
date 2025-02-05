// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";

import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";

import {HelperConfig} from "../script/HelperConfig.s.sol";
import {MinimalAccount} from "../src/ethereum/MinimalAccount.sol";

/** 
 * @title SendPackedUserOp Script
 * @author Your Name
 * @notice This script is used to send a packed user operation (UserOp) to the EntryPoint v0.7.0 contract.
 * @dev The script generates a signed UserOp, which includes an ERC20 approval transaction, and sends it to the EntryPoint v0.7.0 for processing.
 *      It uses the HelperConfig contract to fetch network-specific configurations and handles both local and testnet environments.
 */
contract SendPackedUserOp is Script {
    using MessageHashUtils for bytes32;

    /** 
     * @notice The amount of tokens to approve in the ERC20 transaction.
     */
    uint256 constant AMOUNT_TO_APPROVE = 1e18;

    /** 
     * @notice Executes the script to send a packed user operation.
     * @dev This function generates a signed UserOp, packages it into an array, and sends it to the EntryPoint v0.7.0 contract.
     *      It uses the HelperConfig contract to fetch network-specific configurations.
     */
    function run() public {
        HelperConfig helperConfig = new HelperConfig();
        // TODO Refactor as helperConfig.getConfig();
        address dest = 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d; // arbitrum sepolia  USDC address
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(IERC20.approve.selector, 0x111, AMOUNT_TO_APPROVE);
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory userOp =
            generateSignedUserOperation(executeCallData, helperConfig.getConfig(), address(0x111));

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);

        ops[0] = userOp;

        vm.startBroadcast();
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops, payable(helperConfig.getConfig().account));
    }

    /** 
     * @notice Generates a signed user operation (UserOp) for execution.
     * @dev This function creates a UserOp, computes its hash, signs it, and returns the signed UserOp.
     *      It handles signing differently for local (Anvil) and testnet environments.
     * @param callData The calldata for the UserOp, typically an encoded function call.
     * @param config The network configuration fetched from HelperConfig.
     * @param minimalAccount The address of the minimal account executing the UserOp.
     * @return PackedUserOperation memory The signed UserOp ready for submission to the EntryPoint v0.7.0.
     */
    function generateSignedUserOperation(
        bytes memory callData,
        HelperConfig.NetworkConfig memory config,
        address minimalAccount
    ) public view returns (PackedUserOperation memory) {
        uint192 key = 0;
        uint256 nonce = IEntryPoint(config.entryPoint).getNonce(minimalAccount, key);
        // uint256 nonce = vm.getNonce(minimalAccount);
        PackedUserOperation memory userOp = _generateUnsignedUserOperation(callData, minimalAccount, nonce);

        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(userOp);
        bytes32 digest = userOpHash.toEthSignedMessageHash();

        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        if (block.chainid == 31337) {
            (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest);
        } else {
            (v, r, s) = vm.sign(minimalAccount, digest);
        }

        // // vm.sign(vm.envUnint(privateKey), digest); // never do this
        // (uint8 v, bytes32 r, bytes32 s) = vm.sign(minimalAccount, digest);
        userOp.signature = abi.encodePacked(r, s, v); // note the order
        return userOp;
    }

    /** 
     * @notice Generates an unsigned user operation (UserOp) with default gas limits and fees.
     * @dev This function creates a UserOp with predefined gas limits and fees, leaving the signature empty.
     * @param callData The calldata for the UserOp, typically an encoded function call.
     * @param sender The address of the sender (minimal account).
     * @param nonce The nonce for the UserOp, fetched from the EntryPoint v0.7.0.
     * @return PackedUserOperation memory The unsigned UserOp with default gas parameters.
     */
    function _generateUnsignedUserOperation(bytes memory callData, address sender, uint256 nonce)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        uint128 verificationGasLimit = 16777216;
        uint128 callGasLimit = verificationGasLimit;
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = maxPriorityFeePerGas;
        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"", // could modularize contract if we were to initialize any contract
            callData: callData,
            accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | callGasLimit), // combines both into one bytes32, play with chisel
            preVerificationGas: verificationGasLimit,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | maxFeePerGas),
            paymasterAndData: hex"",
            signature: hex""
        });
    }
}
