// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {VerifierSpace} from 'contracts/L3/VerifierSpace.sol';

/**
 * @title MockVerifierSpace
 * @notice Mock contract for testing VerifierSpace with additional test helper functions
 */
contract MockVerifierSpace is VerifierSpace {
  function workaround_setValidWriters(bytes16 _spaceId, bool _valid) external {
    VerifierSpaceStorage storage $_ = _getVerifierSpaceStorage();
    $_.validWriters[_spaceId] = _valid;
  }

  function exposed__VERIFIER_SPACE_STORAGE_LOCATION() external pure returns (bytes32 _verifierSpaceStorageLocation) {
    _verifierSpaceStorageLocation = _VERIFIER_SPACE_STORAGE_LOCATION;
  }
}
