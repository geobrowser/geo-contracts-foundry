// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';

interface ISpaceAccessControl {
  /**
   * @notice The storage struct of the Space Access Control contract
   * @param spaceRegistry The space registry contract
   * @param hasRole A nested mapping from roles and space id to a boolean
   * @custom:storage-location erc7201:geo.storage.SpaceAccessControl
   */
  struct SpaceAccessControlStorage {
    ISpaceRegistry spaceRegistry;
    mapping(bytes32 _role => mapping(bytes16 _space => bool)) hasRole;
  }

  /// @notice Thrown when trying to enter an account without a space id
  error SpaceNotRegistered();

  /**
   * @notice Space Registry contract
   * @return _spaceRegistry The address of the space registry singleton
   */
  function spaceRegistry() external view returns (ISpaceRegistry _spaceRegistry);

  /**
   * @notice Returns the boolean for whether a space id has been granted a role
   * @param _role The role to query
   * @param _account The account associated with the space id
   * @return _hasRole A boolean for whether the space id has the role or not
   */
  function hasRole(bytes32 _role, address _account) external view returns (bool _hasRole);
}
