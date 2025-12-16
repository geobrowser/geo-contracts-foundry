// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {VerifierSpace} from 'contracts/VerifierSpace.sol';

/**
 * @title MockVerifierSpace
 * @notice Mock contract for testing VerifierSpace with additional test helper functions
 */
contract MockVerifierSpace is VerifierSpace {
  function workaround_setValidWriters(address _account, bool _valid) external {
    validWriters[_account] = _valid;
  }

  function workaround_exposeEIP712NameHash() external view returns (bytes32) {
    return _EIP712NameHash();
  }

  function workaround_exposeEIP712VersionHash() external view returns (bytes32) {
    return _EIP712VersionHash();
  }
}
