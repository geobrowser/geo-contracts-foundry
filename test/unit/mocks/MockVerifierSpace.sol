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

  function exposed__authorizeUpgrade(address _newImplementation) external {
    _authorizeUpgrade(_newImplementation);
  }
}
