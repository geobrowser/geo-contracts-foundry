// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {StakingManager} from 'contracts/L2/StakingManager.sol';
import {IStakingManager} from 'interfaces/L2/IStakingManager.sol';

/**
 * @title MockStakingManager
 * @notice Test helper exposing ERC-7201 storage location for unit tests.
 */
contract MockStakingManager is StakingManager {
  /// @notice Exposes the ERC-7201 namespaced storage slot for `StakingManager`
  function exposed__STAKING_MANAGER_STORAGE_LOCATION() external pure returns (bytes32 _stakingManagerStorageLocation) {
    _stakingManagerStorageLocation = _STAKING_MANAGER_STORAGE_LOCATION;
  }

  /**
   * @notice Test-only seed for `unstake` scenarios without exercising `stake` / `requestUnstake`
   * @param _unstakeId Unstake request id to populate
   * @param _user Requester recorded on the pending unstake
   * @param _amount Amount recorded on the pending unstake
   * @param _unlockTime Unlock timestamp for the pending unstake
   * @param _totalUserStake `totalUserStake[_user]` to set (omit prior `stake` when testing `unstake` finalization)
   * @param _totalStaked Global `totalStaked` to set
   * @param _userPendingUnstake `totalUserPendingUnstake[_user]` to set
   * @param _pendingUnstake Global `totalPendingUnstake` to set
   */
  function workaround_seedUnstakeRequest(
    uint256 _unstakeId,
    address _user,
    uint256 _amount,
    uint256 _unlockTime,
    uint256 _totalUserStake,
    uint256 _totalStaked,
    uint256 _userPendingUnstake,
    uint256 _pendingUnstake
  ) external {
    StakingManagerStorage storage $_ = _getStakingManagerStorage();
    $_.unstakeRequests[_unstakeId] =
      IStakingManager.UnstakeRequest({user: _user, amount: _amount, unlockTime: _unlockTime});
    $_.totalUserStake[_user] = _totalUserStake;
    $_.totalStaked = _totalStaked;
    $_.totalUserPendingUnstake[_user] = _userPendingUnstake;
    $_.totalPendingUnstake = _pendingUnstake;
  }

  /**
   * @notice Seeds stake ledger fields for a user without calling `stake`
   * @dev Disposable stake equals `_totalUserStake - _totalUserPendingUnstake - _totalUserAllocation`
   */
  function workaround_seedStakeOnly(
    address _user,
    uint256 _totalUserStake,
    uint256 _totalStaked,
    uint256 _totalUserPendingUnstake,
    uint256 _totalUserAllocation
  ) external {
    StakingManagerStorage storage $_ = _getStakingManagerStorage();
    $_.totalUserStake[_user] = _totalUserStake;
    $_.totalStaked = _totalStaked;
    $_.totalUserPendingUnstake[_user] = _totalUserPendingUnstake;
    $_.totalUserAllocation[_user] = _totalUserAllocation;
  }

  /// @notice Seeds a single-target allocation for `_user` (totals match one active target)
  function workaround_seedSingleTargetAllocation(address _user, bytes32 _targetId, uint256 _allocOnTarget) external {
    StakingManagerStorage storage $_ = _getStakingManagerStorage();
    $_.allocations[_user][_targetId] = _allocOnTarget;
    $_.totalUserAllocation[_user] = _allocOnTarget;
    $_.totalTargetAllocation[_targetId] = _allocOnTarget;
    $_.totalAllocated = _allocOnTarget;
  }
}
