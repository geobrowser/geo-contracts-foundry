// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {VerifierSpace} from 'contracts/L3/VerifierSpace.sol';

/**
 * @title MockMigratableVerifierSpace
 * @notice Mock contract for testing VerifierSpace migrations
 */
contract MockMigratableVerifierSpace is VerifierSpace {
  /**
   * @notice Archives its space ID from the registry
   * @dev Must be called by the owner
   */
  function archive() external virtual onlyOwner {
    VerifierSpaceStorage storage $_ = _getVerifierSpaceStorage();
    $_.spaceRegistry.archiveSpaceId();
  }

  /**
   * @notice Clears its space ID from the registry and disconnects it from any address
   * @dev Must be called by the owner
   */
  function clear() external virtual onlyOwner {
    VerifierSpaceStorage storage $_ = _getVerifierSpaceStorage();
    $_.spaceRegistry.clearSpaceId();
  }

  /**
   * @notice Proposes to migrate its space ID to a new address
   * @dev Must be called by the owner
   * @param _newAccount The proposed address of the space
   */
  function proposeMigration(address _newAccount) external virtual onlyOwner {
    VerifierSpaceStorage storage $_ = _getVerifierSpaceStorage();
    $_.spaceRegistry.proposeSpaceMigration(_newAccount);
  }

  /**
   * @notice Accepts to migrate a space ID to itself
   * @dev Must be called by the owner
   * @dev Can only accept proposed migrations in the registry
   * @param _spaceId The ID of the space
   */
  function acceptMigration(bytes16 _spaceId) external virtual onlyOwner {
    VerifierSpaceStorage storage $_ = _getVerifierSpaceStorage();
    $_.spaceRegistry.acceptSpaceMigration(_spaceId, typeId(), abi.encode(version()));
  }
}
