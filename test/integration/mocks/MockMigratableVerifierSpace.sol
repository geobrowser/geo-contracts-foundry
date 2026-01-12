// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {VerifierSpace} from 'contracts/VerifierSpace.sol';

/**
 * @title MockMigratableVerifierSpace
 * @notice Mock contract for testing VerifierSpace migrations
 */
contract MockMigratableVerifierSpace is VerifierSpace {
  /**
   * @notice Enters the Space Registry to emit an Action event
   * @dev Must be called by the owner
   * @param _action An action identifier
   * @param _topic A topic identifier
   * @param _data Some extra arbitrary data that may hold additional information
   * @dev _from and _to are always the DAO's address
   */
  function ping(bytes32 _action, bytes32 _topic, bytes calldata _data) external virtual onlyOwner {
    VerifierSpaceStorage storage $ = _getVerifierSpaceStorage();
    bytes16 verifierSpaceId = $.spaceRegistry.addressToSpaceId(address(this));
    $.spaceRegistry.enter(verifierSpaceId, verifierSpaceId, _action, _topic, _data, '');
  }

  /**
   * @notice Creates a new space by registering a space ID for this address
   * @dev Must be called by the owner
   */
  function register() external virtual onlyOwner {
    VerifierSpaceStorage storage $ = _getVerifierSpaceStorage();
    $.spaceRegistry.registerSpaceId(typeId(), abi.encode(version()));
  }

  /**
   * @notice Clears its space ID from the registry and disconnects it from any address
   * @dev Must be called by the owner
   */
  function clear() external virtual onlyOwner {
    VerifierSpaceStorage storage $ = _getVerifierSpaceStorage();
    $.spaceRegistry.clearSpaceId();
  }

  /**
   * @notice Proposes to migrate its space ID to a new address
   * @dev Must be called by the owner
   * @param _newAccount The proposed address of the space
   */
  function proposeMigration(address _newAccount) external virtual onlyOwner {
    VerifierSpaceStorage storage $ = _getVerifierSpaceStorage();
    $.spaceRegistry.proposeSpaceMigration(_newAccount);
  }

  /**
   * @notice Accepts to migrate a space ID to itself
   * @dev Must be called by the owner
   * @dev Can only accept proposed migrations in the registry
   * @param _spaceId The ID of the space
   */
  function acceptMigration(bytes16 _spaceId) external virtual onlyOwner {
    VerifierSpaceStorage storage $ = _getVerifierSpaceStorage();
    $.spaceRegistry.acceptSpaceMigration(_spaceId, typeId(), abi.encode(version()));
  }
}
