// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {SpaceRegistry} from 'contracts/SpaceRegistry.sol';

/**
 * @title MockSpaceRegistry
 * @notice Mock contract for testing SpaceRegistry with additional test helper functions
 */
contract MockSpaceRegistry is SpaceRegistry {
  function workaround_setSpaceIdToAddress(bytes16 _spaceId, address _account) external {
    SpaceRegistryStorage storage $_ = _getSpaceRegistryStorage();
    $_.spaceIdToAddress[_spaceId] = _account;
  }

  function workaround_setSpaceIdToProposedAddress(bytes16 _spaceId, address _account) external {
    SpaceRegistryStorage storage $_ = _getSpaceRegistryStorage();
    $_.spaceIdToProposedAddress[_spaceId] = _account;
  }

  function workaround_setAddressToSpaceId(address _account, bytes16 _spaceId) external {
    SpaceRegistryStorage storage $_ = _getSpaceRegistryStorage();
    $_.addressToSpaceId[_account] = _spaceId;
  }

  function workaround_setArchivedSpaceIds(bytes16 _spaceId, bool _isArchived) external {
    SpaceRegistryStorage storage $_ = _getSpaceRegistryStorage();
    $_.archivedSpaceIds[_spaceId] = _isArchived;
  }

  function workaround_setPaymentManager(address _paymentManager) external {
    SpaceRegistryStorage storage $_ = _getSpaceRegistryStorage();
    $_.paymentManager = _paymentManager;
  }

  function exposed__authorizeUpgrade(address _newImplementation) external {
    _authorizeUpgrade(_newImplementation);
  }

  function exposed__SPACE_REGISTRY_STORAGE_LOCATION() external pure returns (bytes32 _spaceRegistryStorageLocation) {
    _spaceRegistryStorageLocation = _SPACE_REGISTRY_STORAGE_LOCATION;
  }

  function exposed__ARB_SYS() external pure returns (address _arbSys) {
    _arbSys = address(_ARB_SYS);
  }

  function exposed__spaceIdNonce() external view returns (uint256 __spaceIdNonce) {
    SpaceRegistryStorage storage $_ = _getSpaceRegistryStorage();
    __spaceIdNonce = $_._spaceIdNonce;
  }
}
