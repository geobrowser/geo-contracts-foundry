// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';

import {ISpaceAccessControl} from 'interfaces/ISpaceAccessControl.sol';
import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';

/**
 * @title SpaceAccessControl
 * @notice Manages a nested mapping to allow for space ids to be granted roles
 * @dev Inspired by the Openzeppelin's AccessControlUpgradeable implementation
 * https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/master/contracts/access/AccessControlUpgradeable.sol
 */
abstract contract SpaceAccessControl is Initializable, ISpaceAccessControl {
  /**
   * @notice The storage location of the Space Access Control contract
   * @custom:storage-location erc7201:geo.storage.SpaceAccessControl
   */
  bytes32 internal constant _SPACE_ACCESS_CONTROL_STORAGE_LOCATION =
    0x2ecb2b2cb0272cfecbe1c3011e1b6356b5ce9fc13d93226dfee5064ba9cec500;

  /// @inheritdoc ISpaceAccessControl
  function spaceRegistry() public view returns (ISpaceRegistry _spaceRegistry) {
    SpaceAccessControlStorage storage $ = _getSpaceAccessControlStorage();
    _spaceRegistry = $.spaceRegistry;
  }

  /// @inheritdoc ISpaceAccessControl
  function hasRole(bytes32 _role, address _account) public view virtual returns (bool _hasRole) {
    SpaceAccessControlStorage storage $ = _getSpaceAccessControlStorage();
    bytes16 _spaceId = $.spaceRegistry.addressToSpaceId(_account);
    return $.hasRole[_role][_spaceId];
  }

  /**
   * @notice Attempts to grant `role` to `space` and returns a boolean indicating if `role` was granted
   * @param _role The role to grant to the space id
   * @param _account The account associated with the space id to receive the new role
   * @return _spaceId The space id associated with the account receiving the new role
   */
  function _grantRole(bytes32 _role, address _account) internal virtual returns (bytes16 _spaceId) {
    SpaceAccessControlStorage storage $ = _getSpaceAccessControlStorage();
    _spaceId = $.spaceRegistry.addressToSpaceId(_account);
    if (_spaceId == bytes16(0)) revert SpaceNotRegistered();
    if (!$.hasRole[_role][_spaceId]) $.hasRole[_role][_spaceId] = true;
  }

  /**
   * @notice Attempts to revoke `role` from `space` and returns a boolean indicating if `role` was revoked
   * @param _role The role to revoke from the space id
   * @param _account The account associated with the space id to have their role revoked
   * @return _spaceId The space id associated with the account receiving the new role
   */
  function _revokeRole(bytes32 _role, address _account) internal virtual returns (bytes16 _spaceId) {
    SpaceAccessControlStorage storage $ = _getSpaceAccessControlStorage();
    _spaceId = $.spaceRegistry.addressToSpaceId(_account);
    if (_spaceId == bytes16(0)) revert SpaceNotRegistered();
    if ($.hasRole[_role][_spaceId]) $.hasRole[_role][_spaceId] = false;
  }

  /**
   * @notice Records the space registry address into storage
   * @param _spaceRegistry The space registry address
   * @dev Should be called in the initializer
   */
  function __spaceAccessControlControl_init(ISpaceRegistry _spaceRegistry) internal virtual onlyInitializing {
    SpaceAccessControlStorage storage $ = _getSpaceAccessControlStorage();
    $.spaceRegistry = _spaceRegistry;
  }

  /**
   * @notice Returns the Space Access Control contract storage
   * @return $ The storage of the Space Access Control contract
   * @custom:storage-location erc7201:geo.storage.SpaceAccessControl
   */
  function _getSpaceAccessControlStorage() private pure returns (SpaceAccessControlStorage storage $) {
    assembly {
      $.slot := _SPACE_ACCESS_CONTROL_STORAGE_LOCATION
    }
  }
}
