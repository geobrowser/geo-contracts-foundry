// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {Rewarder} from 'contracts/L2/Rewarder.sol';

/**
 * @title MockRewarder
 * @notice Test helper exposing ERC-7201 storage location for unit tests.
 */
contract MockRewarder is Rewarder {
  /// @notice Exposes the ERC-7201 namespaced storage slot for `Rewarder`
  function exposed__REWARDER_STORAGE_LOCATION() external pure returns (bytes32 _rewarderStorageLocation) {
    _rewarderStorageLocation = _REWARDER_STORAGE_LOCATION;
  }

  /// @notice Seeds a published epoch without calling `publishMerkleRoot`
  function workaround_seedPublishedEpoch(uint256 _epoch, bytes32 _root, uint256 _totalClaimableRewards) external {
    RewarderStorage storage $_ = _getRewarderStorage();
    $_.merkleRoot[_epoch] = _root;
    $_.totalClaimableRewards[_epoch] = _totalClaimableRewards;
  }

  /// @notice Sets `userClaimed` for claim-path tests without a prior claim tx
  function workaround_setUserClaimed(address _user, bytes32 _targetId, uint256 _epoch, bool _claimed) external {
    _getRewarderStorage().userClaimed[_user][_targetId][_epoch] = _claimed;
  }

  /// @notice Sets `targetClaimed` for claim-path tests without a prior claim tx
  function workaround_setTargetClaimed(bytes32 _targetId, uint256 _epoch, bool _claimed) external {
    _getRewarderStorage().targetClaimed[_targetId][_epoch] = _claimed;
  }

  /// @notice Sets `merkleRootRevoked` for claim-path tests without calling `revokeMerkleRoot`
  function workaround_setMerkleRootRevoked(uint256 _epoch, bool _revoked) external {
    _getRewarderStorage().merkleRootRevoked[_epoch] = _revoked;
  }
}
