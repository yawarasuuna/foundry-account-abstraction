// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

// Open Zeppelin Imports
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// zkSync Era Imports
import {
    ACCOUNT_VALIDATION_SUCCESS_MAGIC,
    IAccount
} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";
import {
    BOOTLOADER_FORMAL_ADDRESS,
    DEPLOYER_SYSTEM_CONTRACT,
    NONCE_HOLDER_SYSTEM_CONTRACT
} from "lib/foundry-era-contracts/src/system-contracts/contracts/Constants.sol";
import {INonceHolder} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/INonceHolder.sol";
import {
    MemoryTransactionHelper,
    Transaction
} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {SystemContractsCaller} from
    "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/SystemContractsCaller.sol";
import {Utils} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/Utils.sol";

/**
 * @title ZkMinimalAccount
 * @dev A minimal account abstraction contract for zkSync Era, supporting transaction validation and execution.
 * @notice This contract allows users to execute transactions and validate signatures.
 * @notice For demo purposes only.
 */
contract ZkMinimalAccount is IAccount, Ownable {
    using MemoryTransactionHelper for Transaction;

    /*//////////////////////////////////////////////////////////////
                                 Errors
    //////////////////////////////////////////////////////////////*/

    error ZkMinimalAccount__FailedExecution();
    error ZkMinimalAccount__FailedToPay();
    error ZkMinimalAccount__InvalidSignature();
    error ZkMinimalAccount__NotEnoughBalance();
    error ZkMinimalAccount__NotFromBootLoader();
    error ZkMinimalAccount__NotFromBootLoaderNorOwner();

    /*//////////////////////////////////////////////////////////////
                               Modifiers
    //////////////////////////////////////////////////////////////*/

    modifier requireFromBootloader() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS) {
            revert ZkMinimalAccount__NotFromBootLoader();
        }
        _;
    }

    modifier requireFromBootLoaderOrOwner() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS && msg.sender != owner()) {
            revert ZkMinimalAccount__NotFromBootLoaderNorOwner();
        }
        _;
    }

    /**
     * @dev Initializes the contract and sets the deployer as the owner.
     */
    constructor() Ownable(msg.sender) {}

    /**
     * @dev Allows the contract to receive Ether.
     */
    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                           External Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Validates a transaction and returns a magic value if successful.
     * @param _transaction The transaction to validate.
     * @return magic The magic value indicating success or failure.
     * @notice Can only be called by the bootloader.
     */
    function validateTransaction(
        bytes32, /* _txHash */
        bytes32, /* _suggestedSignedHash */
        Transaction memory _transaction
    ) external payable requireFromBootloader returns (bytes4 magic) {
        return _validateTransaction(_transaction);
    }

    /**
     * @dev Executes a validated transaction.
     * @param _transaction The transaction to execute.
     * @notice Can only be called by the bootloader or the owner.
     */
    function executeTransaction(
        bytes32, /* _txHash */
        bytes32, /* _suggestedSignedHash */
        Transaction memory _transaction
    ) external payable requireFromBootLoaderOrOwner {
        _executeTransaction(_transaction);
    }

    /**
     * @dev Executes a transaction from outside the bootloader.
     * @param _transaction The transaction to execute.
     * @notice Validates the transaction before execution.
     */
    function executeTransactionFromOutside(Transaction memory _transaction) external payable {
        // _validateTransaction(_transaction); magic returned should be checked, otherwise it leads to signature security issues
        bytes4 magic = _validateTransaction(_transaction);
        if (magic != ACCOUNT_VALIDATION_SUCCESS_MAGIC) {
            revert ZkMinimalAccount__InvalidSignature();
        }
        _executeTransaction(_transaction);
    }

    /**
     * @dev Pays for a transaction by transferring funds to the bootloader.
     * @param _transaction The transaction to pay for.
     * @notice Reverts if the payment fails.
     */
    function payForTransaction(
        bytes32, /* _txHash */
        bytes32, /* _suggestedSignedHash */
        Transaction memory _transaction
    ) external payable {
        bool success = _transaction.payToTheBootloader();
        if (!success) {
            revert ZkMinimalAccount__FailedToPay();
        }
    }

    /**
     * @dev Prepares for paymaster interaction.
     * @param _txHash The transaction hash.
     * @param _possibleSignedHash The possible signed hash.
     * @param _transaction The transaction data.
     */
    function prepareForPaymaster(bytes32 _txHash, bytes32 _possibleSignedHash, Transaction memory _transaction)
        external
        payable
    {}

    /*//////////////////////////////////////////////////////////////
                           Internal Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Validates a transaction by checking the balance, nonce, and signature.
     * @param _transaction The transaction to validate.
     * @return magic The magic value indicating success or failure.
     */
    function _validateTransaction(Transaction memory _transaction) internal returns (bytes4 magic) {
        uint256 totalRequiredBalance = _transaction.totalRequiredBalance();
        if (totalRequiredBalance > address(this).balance) {
            revert ZkMinimalAccount__NotEnoughBalance();
        }

        SystemContractsCaller.systemCallWithPropagatedRevert(
            uint32(gasleft()),
            address(NONCE_HOLDER_SYSTEM_CONTRACT),
            0,
            abi.encodeCall(INonceHolder.incrementMinNonceIfEquals, (_transaction.nonce)) // similar to encodeWithSignature, cooler nowadays
        );

        bytes32 txHash = _transaction.encodeHash();
        // bytes32 convertedHash = MessageHashUtils.toEthSignedMessageHash(txHash); // function encodeHash  already puts it in the correct format
        // address signer = ECDSA.recover(convertedHash, _transaction.signature);
        address signer = ECDSA.recover(txHash, _transaction.signature);
        bool isValidSigner = signer == owner();
        if (isValidSigner) {
            magic = ACCOUNT_VALIDATION_SUCCESS_MAGIC;
        } else {
            magic = bytes4(0);
        }

        return magic;
    }

    /**
     * @dev Executes a validated transaction.
     * @param _transaction The transaction to execute.
     * @notice Handles both system contract calls and regular contract calls.
     */
    function _executeTransaction(Transaction memory _transaction) internal {
        address to = address(uint160(_transaction.to)); // converts uint256 to uin160 to address;
        uint128 value = Utils.safeCastToU128(_transaction.value); // value might have to be used as a system  contracts call , so convertion required
        bytes memory data = _transaction.data;

        if (to == address(DEPLOYER_SYSTEM_CONTRACT)) {
            uint32 gas = Utils.safeCastToU32(gasleft());
            SystemContractsCaller.systemCallWithPropagatedRevert(gas, to, value, data);
        } else {
            bool success;
            assembly {
                success := call(gas(), to, value, add(data, 0x20), mload(data), 0, 0)
            }
            if (!success) {
                revert ZkMinimalAccount__FailedExecution();
            }
        }
    }
}
