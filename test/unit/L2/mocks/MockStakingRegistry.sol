// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {StakingRegistry} from 'contracts/L2/StakingRegistry.sol';

/**
 * @title MockStakingRegistry
 * @notice Test helper exposing ERC-7201 storage location for `StakingRegistry` unit tests
 */
contract MockStakingRegistry is StakingRegistry {
  /// @notice Exposes the ERC-7201 namespaced storage slot for `StakingRegistry`
  function exposed__STAKING_REGISTRY_STORAGE_LOCATION()
    external
    pure
    returns (bytes32 _stakingRegistryStorageLocation)
  {
    _stakingRegistryStorageLocation = _STAKING_REGISTRY_STORAGE_LOCATION;
  }
}
