// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {console2, Test} from "forge-std/Test.sol";
import {ZkMinimalAccount} from "../../../src/zkSync/ZkMinimalAccount.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ACCOUNT_VALIDATION_SUCCESS_MAGIC} from
    "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";
import {BOOTLOADER_FORMAL_ADDRESS} from "lib/foundry-era-contracts/src/system-contracts/contracts/Constants.sol";
import {
    MemoryTransactionHelper,
    Transaction
} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";

contract zkMinimalAccountTest is Test {
    using MessageHashUtils for bytes32;

    ZkMinimalAccount zkMinAcc;
    ERC20Mock usdc;

    uint256 constant AMOUNT = 1e18;
    bytes32 constant EMPTY_BYTES32 = bytes32(0);
    address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public NOT_OWNER = makeAddr("notOwner");

    function setUp() public {
        zkMinAcc = new ZkMinimalAccount();
        zkMinAcc.transferOwnership(ANVIL_DEFAULT_ACCOUNT);
        usdc = new ERC20Mock();
        vm.deal(address(zkMinAcc), AMOUNT);
    }

    function testZkOwnerCanExecuteCommands() public {
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(zkMinAcc), AMOUNT);

        Transaction memory transaction = _createUnsignedTransaction(zkMinAcc.owner(), 113, dest, value, functionData);

        vm.prank(zkMinAcc.owner());
        zkMinAcc.executeTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);

        assertEq(usdc.balanceOf(address(zkMinAcc)), AMOUNT);
    }

    function test_RevertIf_NotOwnerCannotExecuteCommands() public {
        address dest = address(zkMinAcc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(zkMinAcc), AMOUNT);

        Transaction memory transaction = _createUnsignedTransaction(address(zkMinAcc), 113, dest, value, functionData);

        vm.prank(NOT_OWNER);
        vm.expectRevert(ZkMinimalAccount.ZkMinimalAccount__NotFromBootLoaderNorOwner.selector);
        zkMinAcc.executeTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);

        assertEq(usdc.balanceOf(address(zkMinAcc)), 0);
    }

    function testZkValidateTransaction() public {
        address dest = address(zkMinAcc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(zkMinAcc), AMOUNT);

        Transaction memory transaction = _createUnsignedTransaction(address(zkMinAcc), 113, dest, value, functionData);
        transaction = _signedTransaction(transaction);
        console2.log("Transaction Signature:");
        console2.logBytes(transaction.signature);
        console2.log("Transaction Data:");
        console2.logBytes(transaction.data);

        vm.prank(BOOTLOADER_FORMAL_ADDRESS);
        bytes4 magic = zkMinAcc.validateTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);

        assertEq(magic, ACCOUNT_VALIDATION_SUCCESS_MAGIC);
    }

    function test_RevertIf_ZkValidateTransactionIsNotFromBootloader() public {
        address dest = address(zkMinAcc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(zkMinAcc), AMOUNT);

        Transaction memory transaction = _createUnsignedTransaction(address(zkMinAcc), 113, dest, value, functionData);

        vm.expectRevert(ZkMinimalAccount.ZkMinimalAccount__NotFromBootLoader.selector);
        bytes4 magic = zkMinAcc.validateTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);

        assert(magic != ACCOUNT_VALIDATION_SUCCESS_MAGIC);
    }

    function test_ValidateTransaction_WhenCallerIsBootloader_WhenSignatureIsValid() public {}

    function test_RevertWhen_ValidateTransaction_WhenCallerIsBootloader_WhenSignatureIsInvalid() public {}

    function test_RevertWhen_ExecuteTransaction_WhenInsufficientBalance() public {}

    function test_ExecuteTransaction_WhenSystemContractCall() public {}

    /*//////////////////////////////////////////////////////////////
                                Helpers
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev scripting currently broken, testing only on local chain for now
     */
    function _signedTransaction(Transaction memory transaction /* address account */ )
        internal
        view
        returns (Transaction memory)
    {
        bytes32 unsignedTransactionHash = MemoryTransactionHelper.encodeHash(transaction);
        // bytes32 digest = unsignedTransactionHash.toEthSignedMessageHash();
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        /*         if (block.chainid == 31337) { */
        (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, unsignedTransactionHash);
        /*         } else {
            (v, r, s) = vm.sign(address(zkMinAcc), digest);
        } */
        Transaction memory signedTransaction = transaction;
        signedTransaction.signature = abi.encodePacked(r, s, v);
        return signedTransaction;
    }

    function _createUnsignedTransaction(
        address from,
        uint8 transactionType,
        address to,
        uint256 value,
        bytes memory data
    ) internal view returns (Transaction memory) {
        uint256 nonce = vm.getNonce(address(zkMinAcc)); // it might not work with zkSync, tbc
        bytes32[] memory factoryDeps = new bytes32[](0);
        // --via-ir intermediate representantion: flag to solidity compiler to compile to yul/assembly
        return Transaction({
            txType: transactionType,
            from: uint256(uint160(from)),
            to: uint256(uint160(to)),
            gasLimit: 16777216,
            gasPerPubdataByteLimit: 16777216,
            maxFeePerGas: 16777216,
            maxPriorityFeePerGas: 16777216,
            paymaster: 0,
            nonce: nonce,
            value: value,
            reserved: [uint256(0), uint256(0), uint256(0), uint256(0)],
            data: data,
            signature: hex"",
            factoryDeps: factoryDeps,
            paymasterInput: hex"",
            reservedDynamic: hex""
        });
    }
}
