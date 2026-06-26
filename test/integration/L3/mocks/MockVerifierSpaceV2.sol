// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {VerifierSpace} from 'contracts/L3/VerifierSpace.sol';
import {ISemver} from 'interfaces/utils/ISemver.sol';

/**
 * @title MockVerifierSpaceV2
 * @notice Mock VerifierSpace implementation for beacon upgrade tests (semver bump only)
 */
contract MockVerifierSpaceV2 is VerifierSpace {
  /// @inheritdoc ISemver
  function version() public pure virtual override returns (string memory _version) {
    _version = '2.0.0';
  }
}
