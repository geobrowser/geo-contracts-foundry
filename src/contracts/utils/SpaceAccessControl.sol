// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {ISpaceAccessControl} from 'interfaces/ISpaceAccessControl.sol';

/**
 * @title SpaceAccessControl
 * @notice Manages a nested mapping to allow for space ids to be granted roles
 * @dev Inspired by the Openzeppelin' AccessControlUpgradeable implementation
 * https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/master/contracts/access/AccessControlUpgradeable.sol
 */
abstract contract SpaceAccessControl is ISpaceAccessControl {
  /**
   * @notice The storage location of the Space Access Control contract
   * @custom:storage-location erc7201:geo.storage.SpaceAccessControl
   */
  bytes32 internal constant _SPACE_ACCESS_CONTROL_STORAGE_LOCATION =
    0x2ecb2b2cb0272cfecbe1c3011e1b6356b5ce9fc13d93226dfee5064ba9cec500;

  /// @inheritdoc ISpaceAccessControl
  function hasRole(bytes32 _role, bytes16 _spaceId) public view virtual returns (bool _hasRole) {
    SpaceAccessControlStorage storage $ = _getSpaceAccessControlStorage();
    return $.hasRole[_role][_spaceId];
  }

  /**
   * @notice Attempts to grant `role` to `space` and returns a boolean indicating if `role` was granted
   * @param _role The role to grant to the space id
   * @param _spaceId The space id to receive the new role
   * @return _wasGranted A boolean indicating whether the attempt to grant the role was succesful or not
   */
  function _grantRole(bytes32 _role, bytes16 _spaceId) internal virtual returns (bool _wasGranted) {
    SpaceAccessControlStorage storage $ = _getSpaceAccessControlStorage();
    if (!hasRole(_role, _spaceId)) {
      $.hasRole[_role][_spaceId] = true;
      return true;
    } else {
      return false;
    }
  }

  /**
   * @notice Attempts to revoke `role` from `space` and returns a boolean indicating if `role` was revoked
   * @param _role The role to revoke from the space id
   * @param _spaceId The space id to have their role revoked
   * @return _wasRevoked A boolean indicating whether the attempt to revoke the role was succesful or not
   */
  function _revokeRole(bytes32 _role, bytes16 _spaceId) internal virtual returns (bool _wasRevoked) {
    SpaceAccessControlStorage storage $ = _getSpaceAccessControlStorage();
    if (hasRole(_role, _spaceId)) {
      $.hasRole[_role][_spaceId] = false;
      return true;
    } else {
      return false;
    }
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
