// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {console2, Test} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {DeployMinimal} from "../../script/DeployMinimal.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IEntryPoint, PackedUserOperation, SendPackedUserOp} from "../../script/SendPackedUserOp.s.sol";
import {MinimalAccount} from "../../src/ethereum/MinimalAccount.sol";

/// @title MinimalAccountTest
/// @notice This contract contains tests for the MinimalAccount contract.
contract MinimalAccountTest is Test {
    using MessageHashUtils for bytes32;

    DeployMinimal deployMinimal;
    HelperConfig helperConfig;
    MinimalAccount minimalAccount;
    ERC20Mock usdc;
    SendPackedUserOp sendPackedUserOp;
    address entryPoint;

    /// @notice The amount of tokens to mint or transfer in tests.
    uint256 constant AMOUNT = 1e18;

    /// @notice A random user address for testing permissions.
    address randomUser = makeAddr("randomUser");

    /// @dev Deploys the MinimalAccount contract, mocks, and helper contracts.
    function setUp() public {
        deployMinimal = new DeployMinimal();
        (helperConfig, minimalAccount) = deployMinimal.deployMinimalAccount();
        usdc = new ERC20Mock();
        sendPackedUserOp = new SendPackedUserOp();
        entryPoint = helperConfig.getConfig().entryPoint;
    }

    /// @dev Verifies that the owner can call the `execute` function to mint tokens to the MinimalAccount.
    function testOwnerCanExecuteCommands() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT); // gets function selector

        vm.prank(minimalAccount.owner());
        minimalAccount.execute(dest, value, functionData);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }

    /// @dev Verifies that a random user cannot call the `execute` function and that the transaction reverts.
    function testNonOwnerCannotExecuteCommands() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        vm.prank(randomUser);
        vm.expectRevert(MinimalAccount.MinimalAccount__NotFromEntryPointOrOwner.selector);
        minimalAccount.execute(dest, value, functionData);
        vm.stopPrank();
    }

    /// @dev Verifies that the signature of a packed user operation can be recovered and matches the owner's address.
    function testRecoverSignedOp() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(
            executeCallData, helperConfig.getConfig(), address(minimalAccount)
        );
        bytes32 userOperationHash = IEntryPoint(entryPoint).getUserOpHash(packedUserOp);

        address actualSigner = ECDSA.recover(userOperationHash.toEthSignedMessageHash(), packedUserOp.signature);

        assertEq(actualSigner, minimalAccount.owner());
    }

    /// @dev Verifies that the `validateUserOp` function returns the expected validation data.
    function testValidationOfUserOps() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionCall = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionCall);
        PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(
            executeCallData, helperConfig.getConfig(), address(minimalAccount)
        );
        bytes32 userOperationHash = IEntryPoint(entryPoint).getUserOpHash(packedUserOp);
        uint256 missingAccountFunds = AMOUNT;

        vm.prank(entryPoint); // pretend to be entryPoint, because validateUserOp() requiresFromEntryPoint
        uint256 validationData = minimalAccount.validateUserOp(packedUserOp, userOperationHash, missingAccountFunds);

        assertEq(validationData, 0);
    }

    /// @dev Verifies that the EntryPoint v0.7.0 can call `handleOps` to execute a user operation and mint tokens to the MinimalAccount.
    function testEntryPointCanExecuteCommands() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);

        uint256 nonceBeforeMinimalAccount = vm.getNonce(address(minimalAccount));
        console2.log("nonceBeforeMinimalAccount: ", nonceBeforeMinimalAccount);

        uint256 nonceBeforeRandomUser = vm.getNonce(address(randomUser));
        console2.log("nonceBeforeRandomUser: ", nonceBeforeRandomUser);

        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionCall = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionCall);
        PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(
            executeCallData, helperConfig.getConfig(), address(minimalAccount)
        );

        vm.deal(address(minimalAccount), AMOUNT);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;

        vm.prank(randomUser);
        IEntryPoint(entryPoint).handleOps(ops, payable(randomUser));

        uint256 nonceAfterMinimalAccount = vm.getNonce(address(minimalAccount));
        console2.log("nonceAfterMinimalAccount: ", nonceAfterMinimalAccount);

        uint256 nonceAfterRandomUser = vm.getNonce(address(randomUser));
        console2.log("nonceAfterRandomUser: ", nonceAfterRandomUser);

        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }
}
