// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title MinimalAccount
 * @dev A minimal account abstraction contract that implements the IAccount interface.
 * @notice This contract allows users to execute transactions, validate user operations, and manage funds.
 * It supports validation of signatures and payment of transaction fees through the EntryPoint contract.
 */

// External Library Imports
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Account Abstraction Imports
import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "lib/account-abstraction/contracts/core/Helpers.sol";

contract MinimalAccount is IAccount, Ownable {
    /*//////////////////////////////////////////////////////////////
                                 Errors
    //////////////////////////////////////////////////////////////*/

    error MinimalAccount__CallFailed(bytes);
    error MinimalAccount__NotFromEntryPoint();
    error MinimalAccount__NotFromEntryPointOrOwner();

    /*//////////////////////////////////////////////////////////////
                            State Variables
    //////////////////////////////////////////////////////////////*/

    // address private immutable i_entryPoint;
    IEntryPoint private immutable i_entryPoint;

    /*//////////////////////////////////////////////////////////////
                               Modifiers
    //////////////////////////////////////////////////////////////*/

    modifier requireFromEntryPoiunt() {
        if (msg.sender != address(i_entryPoint)) {
            revert MinimalAccount__NotFromEntryPoint();
        }
        _;
    }

    modifier requireFromEntryPointOrOwner() {
        if (msg.sender != address(i_entryPoint) && msg.sender != owner()) {
            revert MinimalAccount__NotFromEntryPointOrOwner();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Initializes the contract with the EntryPoint address.
     * @param entryPoint The address of the EntryPoint contract.
     */
    constructor(address entryPoint) Ownable(msg.sender) {
        // i_entryPoint = entryPoint
        i_entryPoint = IEntryPoint(entryPoint);
    }

    /**
     * @dev Allows the contract to receive Ether.
     */
    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                           External Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Executes a transaction from this account to a specified destination.
     * @param destination The address to send the transaction to.
     * @param value The amount of Ether to send.
     * @param functionData The data to pass along with the call.
     * @notice Can be called by either the EntryPoint contract or the contract owner.
     * @dev Reverts with `MinimalAccount__CallFailed` if the call fails.
     */
    function execute(address destination, uint256 value, bytes calldata functionData)
        external
        payable
        requireFromEntryPointOrOwner
    {
        (bool success, bytes memory result) = destination.call{value: value}(functionData);
        if (!success) {
            revert MinimalAccount__CallFailed(result);
        }
    }

    /**
     * @dev Validates a user operation and pays the required prefund.
     * @param userOp The packed user operation data.
     * @param userOpHash The hash of the user operation.
     * @param missingAccountFunds The amount of funds required to cover the operation.
     * @return validationData The result of the validation (success or failure).
     * @notice Can only be called by the EntryPoint contract.
     * @dev Calls `_validateSignature` to verify the signature and `_payPrefund` to cover the operation cost.
     */
    // Signature is valid if it is the MinimalAccount contract owner,  otherwise can go wild
    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        requireFromEntryPoiunt
        returns (uint256 validationData)
    {
        validationData = _validateSignature(userOp, userOpHash);
        // _validateNonce(); PackedUserOperation should have a nonce, and we can keep track of it and validate it
        // eg it needs to be sequential, in order, any order, it needs to be in a mapping, do whatever we want
        // nonce uniquiness is managed by the entryPoint itself
        _payPrefund(missingAccountFunds); // or use payMaster
    }

    /*//////////////////////////////////////////////////////////////
                           Internal Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Validates the signature of a user operation.
     * @param userOp The packed user operation data.
     * @param userOpHash The hash of the user operation.
     * @return validationData The result of the validation (success or failure).
     * @dev Uses ECDSA to recover the signer and checks if it matches the contract owner.
     */
    // EIP-191 version of signed hash
    // can customize to anything: make sure faceId approved it, or google session key is correct, etc
    // signature is aggregator?
    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        view
        returns (uint256 validationData)
    {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash); // formats hash into correct format to do ECDSA recover, showing who actually signed the hash
        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature); // returns who actually signed
        if (signer != owner()) {
            return SIG_VALIDATION_FAILED;
        }
        return SIG_VALIDATION_SUCCESS;
    }

    /**
     * @dev Pays the required prefund to the EntryPoint contract.
     * @param missingAccountFunds The amount of funds required to cover the operation.
     * @dev Sends the funds to the EntryPoint contract if `missingAccountFunds` is non-zero.
     */
    function _payPrefund(uint256 missingAccountFunds) internal {
        if (missingAccountFunds != 0) {
            // hardcode msg.sender as entryPoint contract, its the entryPoint contract's job to verify payment is good
            (bool sucess,) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint256).max}("");
            (sucess);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                Getters
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Returns the address of the EntryPoint contract.
     * @return The address of the EntryPoint contract.
     */
    function getEntryPoint() internal view returns (address) {
        return address(i_entryPoint);
    }

    /**
     * @dev Returns the Ether balance of this contract.
     * @return The balance of the contract in wei.
     */
    function getContractBalance() internal view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Returns the address of the current owner.
     * @return The address of the owner.
     */
    function getOwner() internal view returns (address) {
        return owner();
    }

    /**
     * @dev Returns the validation success constant.
     * @return The value representing validation success.
     */
    function getValidationSuccess() internal pure returns (uint256) {
        return SIG_VALIDATION_SUCCESS;
    }

    /**
     * @dev Returns the validation failure constant.
     * @return The value representing validation failure.
     */
    function getValidationFailed() internal pure returns (uint256) {
        return SIG_VALIDATION_FAILED;
    }
}
