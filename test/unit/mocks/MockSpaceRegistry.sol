// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {SpaceRegistry} from 'contracts/SpaceRegistry.sol';

/**
 * @title MockSpaceRegistry
 * @notice Mock contract for testing SpaceRegistry with additional test helper functions
 */
contract MockSpaceRegistry is SpaceRegistry {
  function workaround_setSpaceIdToAddress(bytes16 _spaceId, address _account) external {
    SpaceRegistryStorage storage $ = _getSpaceRegistryStorage();
    $.spaceIdToAddress[_spaceId] = _account;
  }

  function workaround_setSpaceIdToProposedAddress(bytes16 _spaceId, address _account) external {
    SpaceRegistryStorage storage $ = _getSpaceRegistryStorage();
    $.spaceIdToProposedAddress[_spaceId] = _account;
  }

  function workaround_setAddressToSpaceId(address _account, bytes16 _spaceId) external {
    SpaceRegistryStorage storage $ = _getSpaceRegistryStorage();
    $.addressToSpaceId[_account] = _spaceId;
  }

  function exposed__authorizeUpgrade(address _newImplementation) external {
    _authorizeUpgrade(_newImplementation);
  }

  function exposed__SPACE_REGISTRY_STORAGE_LOCATION() external pure returns (bytes32 _spaceRegistryStorageLocation) {
    _spaceRegistryStorageLocation = _SPACE_REGISTRY_STORAGE_LOCATION;
  }

  function exposed__spaceIdNonce() external view returns (uint256 __spaceIdNonce) {
    SpaceRegistryStorage storage $ = _getSpaceRegistryStorage();
    __spaceIdNonce = $._spaceIdNonce;
  }
}
