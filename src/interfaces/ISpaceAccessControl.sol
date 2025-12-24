// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

interface ISpaceAccessControl {
  /**
   * @notice The storage struct of the Space Access Control contract
   * @param hasRole A nested mapping from roles and space id to a boolean
   * @custom:storage-location erc7201:geo.storage.SpaceAccessControl
   */
  struct SpaceAccessControlStorage {
    mapping(bytes32 _role => mapping(bytes16 _space => bool)) hasRole;
  }

  /**
   * @notice Returns the boolean for whether a space id has been granted a role
   * @param _role The role to query
   * @param _spaceId The space Id to query
   * @return _hasRole A boolean for whether the space id has the role or not
   */
  function hasRole(bytes32 _role, bytes16 _spaceId) external view returns (bool _hasRole);
}
