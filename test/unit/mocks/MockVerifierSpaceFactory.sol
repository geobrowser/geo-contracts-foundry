// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {VerifierSpaceFactory} from 'contracts/VerifierSpaceFactory.sol';

/**
 * @title MockVerifierSpaceFactory
 * @notice Mock contract for testing VerifierSpaceFactory with additional test helper functions
 */
contract MockVerifierSpaceFactory is VerifierSpaceFactory {
  function exposed__authorizeUpgrade(address _newImplementation) external {
    _authorizeUpgrade(_newImplementation);
  }
}
