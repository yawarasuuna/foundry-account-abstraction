// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MinimalAccount is IAccount, Ownable {
    /*//////////////////////////////////////////////////////////////
                                 Errors
    //////////////////////////////////////////////////////////////*/

    error MinimalAccount__NotFromEntryPoint();

    // address private immutable i_entryPoint;
    IEntryPoint private immutable i_entryPoint;

    modifier requireFromEntryPoiunt() {
        if (msg.sender != address(i_entryPoint)) {
            revert MinimalAccount__NotFromEntryPoint();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               Functions
    //////////////////////////////////////////////////////////////*/

    constructor(address entryPoint) Ownable(msg.sender) {
        // i_entryPoint = entryPoint
        i_entryPoint = IEntryPoint(entryPoint);
    }

    // Signature is valid if it is the MinimalAccount contract owner,  can go wild
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

    function getEntryPoint() internal view returns (address) {
        return address(i_entryPoint);
    }
}
