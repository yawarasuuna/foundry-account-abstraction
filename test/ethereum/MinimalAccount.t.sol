// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {DeployMinimal} from "../../script/DeployMinimal.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IEntryPoint, PackedUserOperation, SendPackedUserOp} from "../../script/SendPackedUserOp.s.sol";
import {MinimalAccount} from "../../src/ethereum/MinimalAccount.sol";

contract MinimalAccountTest is Test {
    using MessageHashUtils for bytes32;

    DeployMinimal deployMinimal;
    HelperConfig helperConfig;
    MinimalAccount minimalAccount;
    ERC20Mock usdc;
    SendPackedUserOp sendPackedUserOp;
    address entryPoint;

    uint256 constant AMOUNT = 1e18;

    address notOwner = makeAddr("notOwner");

    function setUp() public {
        deployMinimal = new DeployMinimal();
        (helperConfig, minimalAccount) = deployMinimal.deployMinimalAccount();
        usdc = new ERC20Mock();
        sendPackedUserOp = new SendPackedUserOp();
        entryPoint = helperConfig.getConfig().entryPoint;
    }

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

    function testNonOwnerCannotExecuteCommands() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        vm.prank(notOwner);
        vm.expectRevert(MinimalAccount.MinimalAccount__NotFromEntryPointOrOwner.selector);
        minimalAccount.execute(dest, value, functionData);
        vm.stopPrank();
    }

    function testRecoverSignedOp() public {
        // cant be view bc we're importing getConfig which could have mocks
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp =
            sendPackedUserOp.generateSignedUserOperation(executeCallData, helperConfig.getConfig());
        bytes32 userOperationHash = IEntryPoint(entryPoint).getUserOpHash(packedUserOp);

        address actualSigner = ECDSA.recover(userOperationHash.toEthSignedMessageHash(), packedUserOp.signature);

        assertEq(actualSigner, minimalAccount.owner());
    }

    function testValidationOfUserOps() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionCall = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionCall);
        PackedUserOperation memory packedUserOp =
            sendPackedUserOp.generateSignedUserOperation(executeCallData, helperConfig.getConfig());
        bytes32 userOperationHash = IEntryPoint(entryPoint).getUserOpHash(packedUserOp);
        uint256 missingAccountFunds = 1e17;

        vm.prank(entryPoint); // pretend to be entryPoint, because validateUserOp() requiresFromEntryPoint
        uint256 validationData = minimalAccount.validateUserOp(packedUserOp, userOperationHash, missingAccountFunds);

        assertEq(validationData, 0);
    }

    function testEntryPointCanExecuteCommands() public {}
}


