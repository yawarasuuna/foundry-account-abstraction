// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {console2, Test} from "forge-std/Test.sol";
import {ZkMinimalAccount} from "../../src/zkSync/ZkMinimalAccount.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Transaction} from
    "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";

contract zkMinimalAccountTest is Test {
    ZkMinimalAccount zkMinAcc;
    ERC20Mock usdc;

    uint256 constant AMOUNT = 1e18;
    bytes32 constant EMPTY_BYTES32 = bytes32(0);

    address public NOT_OWNER = makeAddr("notOwner");

    function setUp() public {
        zkMinAcc = new ZkMinimalAccount();
        usdc = new ERC20Mock();
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

    /*//////////////////////////////////////////////////////////////
                                Helpers
    //////////////////////////////////////////////////////////////*/

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
