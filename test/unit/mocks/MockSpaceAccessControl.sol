// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {SpaceAccessControl} from 'contracts/utils/SpaceAccessControl.sol';

/**
 * @title MockSpaceAccessControl
 * @notice Mock contract for testing SpaceAccessControl with additional test helper functions
 */
contract MockSpaceAccessControl is SpaceAccessControl {
  function workaround_grantRole(bytes32 _role, bytes16 _spaceId) external returns (bool _hasRole) {
    return _grantRole(_role, _spaceId);
  }

  function workaround_revokeRole(bytes32 _role, bytes16 _spaceId) external returns (bool _hasRole) {
    return _revokeRole(_role, _spaceId);
  }

  function exposed__SPACE_ACCESS_CONTROL_STORAGE_LOCATION()
    external
    pure
    returns (bytes32 _spaceAccessControlStorageLocation)
  {
    _spaceAccessControlStorageLocation = _SPACE_ACCESS_CONTROL_STORAGE_LOCATION;
  }
}
