// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

/**
 * @title ISemver
 * @notice Interface for semantic versioning
 */
interface ISemver {
  /**
   * @notice Returns the semantic version of the contract
   * @return _version The semantic version string
   */
  function version() external pure returns (string memory _version);
}
