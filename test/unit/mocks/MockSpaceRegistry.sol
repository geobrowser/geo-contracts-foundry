// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

import {SpaceRegistry} from 'contracts/registry/SpaceRegistry.sol';

/**
 * @title MockSpaceRegistry
 * @notice Mock contract for testing SpaceRegistry with additional test helper functions
 */
contract MockSpaceRegistry is SpaceRegistry {
  function workaround_setSpaceIdToAddress(bytes16 _spaceId, address _account) external {
    spaceIdToAddress[_spaceId] = _account;
  }

  function workaround_setSpaceIdToProposedAddress(bytes16 _spaceId, address _account) external {
    spaceIdToProposedAddress[_spaceId] = _account;
  }

  function workaround_setAddressToSpaceId(address _account, bytes16 _spaceId) external {
    addressToSpaceId[_account] = _spaceId;
  }

  function exposed__authorizeUpgrade(address _newImplementation) external {
    _authorizeUpgrade(_newImplementation);
  }

  function exposed__spaceIdNonce() external view returns (uint256 __spaceIdNonce) {
    return _spaceIdNonce;
  }
}
