// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';

import {ISpaceAccessControl} from 'interfaces/utils/ISpaceAccessControl.sol';

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
   * @dev Computed with: keccak256(abi.encode(uint256(keccak256("geo.storage.SpaceAccessControl")) - 1)) & ~bytes32(uint256(0xff))
   */
  bytes32 internal constant _SPACE_ACCESS_CONTROL_STORAGE_LOCATION =
    0x2ecb2b2cb0272cfecbe1c3011e1b6356b5ce9fc13d93226dfee5064ba9cec500;

  /// @inheritdoc ISpaceAccessControl
  function hasRole(bytes32 _role, bytes16 _spaceId) public view virtual returns (bool _hasRole) {
    SpaceAccessControlStorage storage $ = _getSpaceAccessControlStorage();
    return $.hasRole[_role][_spaceId];
  }

  /**
   * @notice Attempts to grant `role` to `space`
   * @param _role The role to grant to the space id
   * @param _spaceId The space id to receive the new role
   */
  function _grantRole(bytes32 _role, bytes16 _spaceId) internal virtual {
    SpaceAccessControlStorage storage $ = _getSpaceAccessControlStorage();
    if (!$.hasRole[_role][_spaceId]) $.hasRole[_role][_spaceId] = true;
  }

  /**
   * @notice Attempts to revoke `role` from `space`
   * @param _role The role to revoke from the space id
   * @param _spaceId The space id to have their role revoked
   */
  function _revokeRole(bytes32 _role, bytes16 _spaceId) internal virtual {
    SpaceAccessControlStorage storage $ = _getSpaceAccessControlStorage();
    if ($.hasRole[_role][_spaceId]) $.hasRole[_role][_spaceId] = false;
  }

  /**
   * @notice Returns the Space Access Control contract storage
   * @return $ The storage of the Space Access Control contract
   * @custom:storage-location erc7201:geo.storage.SpaceAccessControl
   */
  function _getSpaceAccessControlStorage() internal pure returns (SpaceAccessControlStorage storage $) {
    assembly {
      $.slot := _SPACE_ACCESS_CONTROL_STORAGE_LOCATION
    }
  }
}
