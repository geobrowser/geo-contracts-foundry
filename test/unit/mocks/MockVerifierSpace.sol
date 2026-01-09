// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {VerifierSpace} from 'contracts/VerifierSpace.sol';

/**
 * @title MockVerifierSpace
 * @notice Mock contract for testing VerifierSpace with additional test helper functions
 */
contract MockVerifierSpace is VerifierSpace {
  function workaround_setValidWriters(bytes16 _spaceId, bool _valid) external {
    VerifierSpaceStorage storage $ = _getVerifierSpaceStorage();
    $.validWriters[_spaceId] = _valid;
  }

  function exposed__EIP712NameHash() external view returns (bytes32 _nameHash) {
    _nameHash = _EIP712NameHash();
  }

  function exposed__EIP712VersionHash() external view returns (bytes32 _versionHash) {
    _versionHash = _EIP712VersionHash();
  }

  function exposed__MESSAGE_TYPEHASH() external pure returns (bytes32 _messageTypeHash) {
    _messageTypeHash = _MESSAGE_TYPEHASH;
  }

  function exposed__VERIFIER_SPACE_STORAGE_LOCATION() external pure returns (bytes32 _verifierSpaceStorageLocation) {
    _verifierSpaceStorageLocation = _VERIFIER_SPACE_STORAGE_LOCATION;
  }
}
