// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {SignatureChecker} from '@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol';

import {IAccount} from 'interfaces/core/IAccount.sol';

contract AccountVerifier is Ownable, IAccount {
  uint256 public nonce;

  function verify(
    address _space,
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data,
    bytes calldata _signature
  ) external {
    // Construct the messageHash
    bytes32 messageHash = keccak256(abi.encodePacked(_space, _action, _topic, _data, nonce));

    // Validate that owner is the signer of the message hash, revert if not
    if (!SignatureChecker.isValidSignatureNow(owner(), messageHash, _signature)) revert InvalidSignature();

    // Increment nonce to prevent replay
    nonce++;
  }
}
