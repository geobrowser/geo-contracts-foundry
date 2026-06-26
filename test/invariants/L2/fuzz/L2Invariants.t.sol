// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IStakingManager} from 'interfaces/L2/IStakingManager.sol';

import {L2Setup} from 'test/invariants/L2/fuzz/L2Setup.t.sol';

/// @notice Foundry invariant tests for `StakingManager` accounting
contract L2Invariants is L2Setup {
  /// @notice SM-INV-1: sum of tracked users' `totalUserStake` equals global `totalStaked`
  function invariant_SM_INV_1_global_stake_sum() public view {
    uint256 _sumUserStake;
    uint256 _length = handlerStakingManager.ghost_usersLength();

    for (uint256 _i = 0; _i < _length; _i++) {
      address _user = handlerStakingManager.ghost_users(_i);
      if (!handlerStakingManager.ghost_isUser(_user)) continue;
      _sumUserStake += stakingManagerProxy.totalUserStake(_user);
    }

    assertEq(_sumUserStake, stakingManagerProxy.totalStaked(), 'SM-INV-1: user stake sum != totalStaked');
  }

  /// @notice SM-INV-2: sum of tracked users' `totalUserAllocation` equals global `totalAllocated`
  function invariant_SM_INV_2_global_allocation_sum() public view {
    uint256 _sumUserAllocation;
    uint256 _length = handlerStakingManager.ghost_usersLength();

    for (uint256 _i = 0; _i < _length; _i++) {
      address _user = handlerStakingManager.ghost_users(_i);
      if (!handlerStakingManager.ghost_isUser(_user)) continue;
      _sumUserAllocation += stakingManagerProxy.totalUserAllocation(_user);
    }

    assertEq(
      _sumUserAllocation, stakingManagerProxy.totalAllocated(), 'SM-INV-2: user allocation sum != totalAllocated'
    );
  }

  /// @notice SM-INV-3: allocations cannot exceed stake that is not pending unstake (global and per-user)
  function invariant_SM_INV_3_allocation_bounded_by_free_stake() public view {
    uint256 _totalStaked = stakingManagerProxy.totalStaked();
    uint256 _totalPending = stakingManagerProxy.totalPendingUnstake();
    uint256 _totalAllocated = stakingManagerProxy.totalAllocated();

    assertLe(_totalAllocated + _totalPending, _totalStaked, 'SM-INV-3: totalAllocated exceeds free stake');

    uint256 _length = handlerStakingManager.ghost_usersLength();
    for (uint256 _i = 0; _i < _length; _i++) {
      address _user = handlerStakingManager.ghost_users(_i);
      if (!handlerStakingManager.ghost_isUser(_user)) continue;

      uint256 _userStake = stakingManagerProxy.totalUserStake(_user);
      uint256 _userPending = stakingManagerProxy.totalUserPendingUnstake(_user);
      uint256 _userAllocation = stakingManagerProxy.totalUserAllocation(_user);

      assertLe(_userAllocation + _userPending, _userStake, 'SM-INV-3: user allocation exceeds free stake');
    }
  }

  /// @notice SM-INV-4: per-user sum of per-target `allocations` equals `totalUserAllocation`
  function invariant_SM_INV_4_user_allocation_decomposition() public view {
    uint256 _usersLength = handlerStakingManager.ghost_usersLength();

    for (uint256 _u = 0; _u < _usersLength; _u++) {
      address _user = handlerStakingManager.ghost_users(_u);
      if (!handlerStakingManager.ghost_isUser(_user)) continue;

      uint256 _sumPerTarget;
      uint256 _targetsLength = handlerStakingManager.ghost_userTargetIdsLength(_user);

      for (uint256 _t = 0; _t < _targetsLength; _t++) {
        bytes32 _targetId = handlerStakingManager.ghost_userTargetIdAt(_user, _t);
        if (!handlerStakingManager.ghost_userHasTarget(_user, _targetId)) continue;
        _sumPerTarget += stakingManagerProxy.allocations(_user, _targetId);
      }

      assertEq(
        _sumPerTarget,
        stakingManagerProxy.totalUserAllocation(_user),
        'SM-INV-4: per-target allocations != totalUserAllocation'
      );
    }
  }

  /// @notice SM-INV-5: per-target sum of user `allocations` equals `totalTargetAllocation`
  function invariant_SM_INV_5_target_allocation_decomposition() public view {
    uint256 _targetsLength = handlerStakingManager.ghost_allocatedTargetIdsLength();

    for (uint256 _t = 0; _t < _targetsLength; _t++) {
      bytes32 _targetId = handlerStakingManager.ghost_allocatedTargetIds(_t);
      if (!handlerStakingManager.ghost_isAllocatedTarget(_targetId)) continue;

      uint256 _sumPerUser;
      uint256 _usersOnTargetLength = handlerStakingManager.ghost_targetUsersLength(_targetId);

      for (uint256 _u = 0; _u < _usersOnTargetLength; _u++) {
        address _user = handlerStakingManager.ghost_targetUserAt(_targetId, _u);
        if (!handlerStakingManager.ghost_targetHasUser(_targetId, _user)) continue;
        _sumPerUser += stakingManagerProxy.allocations(_user, _targetId);
      }

      assertEq(
        _sumPerUser,
        stakingManagerProxy.totalTargetAllocation(_targetId),
        'SM-INV-5: per-user allocations != totalTargetAllocation'
      );
    }
  }

  /// @notice SM-INV-6: sum of tracked users' pending unstake equals global `totalPendingUnstake`
  function invariant_SM_INV_6_global_pending_unstake_sum() public view {
    uint256 _sumUserPending;
    uint256 _length = handlerStakingManager.ghost_usersLength();

    for (uint256 _i = 0; _i < _length; _i++) {
      address _user = handlerStakingManager.ghost_users(_i);
      if (!handlerStakingManager.ghost_isUser(_user)) continue;
      _sumUserPending += stakingManagerProxy.totalUserPendingUnstake(_user);
    }

    assertEq(
      _sumUserPending, stakingManagerProxy.totalPendingUnstake(), 'SM-INV-6: user pending sum != totalPendingUnstake'
    );
  }

  /// @notice SM-INV-7: sum of open unstake request amounts equals `totalPendingUnstake`
  function invariant_SM_INV_7_open_unstake_requests_sum() public view {
    uint256 _sumOpenRequests;
    uint256 _length = handlerStakingManager.ghost_openUnstakeIdsLength();

    for (uint256 _i = 0; _i < _length; _i++) {
      uint256 _unstakeId = handlerStakingManager.ghost_openUnstakeIdAt(_i);
      if (!handlerStakingManager.ghost_isOpenUnstake(_unstakeId)) continue;

      IStakingManager.UnstakeRequest memory _request = stakingManagerProxy.unstakeRequests(_unstakeId);
      _sumOpenRequests += _request.amount;
      assertGe(stakingManagerProxy.totalPendingUnstake(), _sumOpenRequests, 'SM-INV-7: pending sum overflowed stake');
    }

    assertEq(_sumOpenRequests, stakingManagerProxy.totalPendingUnstake(), 'SM-INV-7: open requests sum != totalPending');
  }

  /// @notice SM-INV-8: ERC-20 balance in the manager is at least `totalStaked`
  function invariant_SM_INV_8_token_balance_covers_totalStaked() public view {
    assertGe(
      IERC20(address(geoToken)).balanceOf(address(stakingManagerProxy)),
      stakingManagerProxy.totalStaked(),
      'SM-INV-8: token balance < totalStaked'
    );
  }

  /// @notice SM-INV-9: per-user sum of open unstake request amounts equals `totalUserPendingUnstake`
  function invariant_SM_INV_9_user_open_unstake_requests_sum() public view {
    uint256 _usersLength = handlerStakingManager.ghost_usersLength();
    uint256 _openLength = handlerStakingManager.ghost_openUnstakeIdsLength();

    for (uint256 _u = 0; _u < _usersLength; _u++) {
      address _user = handlerStakingManager.ghost_users(_u);
      if (!handlerStakingManager.ghost_isUser(_user)) continue;

      uint256 _sumUserOpenRequests;
      for (uint256 _i = 0; _i < _openLength; _i++) {
        uint256 _unstakeId = handlerStakingManager.ghost_openUnstakeIdAt(_i);
        if (!handlerStakingManager.ghost_isOpenUnstake(_unstakeId)) continue;

        IStakingManager.UnstakeRequest memory _request = stakingManagerProxy.unstakeRequests(_unstakeId);
        if (_request.user != _user) continue;

        _sumUserOpenRequests += _request.amount;
      }

      assertEq(
        _sumUserOpenRequests,
        stakingManagerProxy.totalUserPendingUnstake(_user),
        'SM-INV-9: user open requests sum != totalUserPendingUnstake'
      );
    }
  }

  /// @notice SM-INV-10: sum of tracked targets' `totalTargetAllocation` equals global `totalAllocated`
  function invariant_SM_INV_10_global_target_allocation_sum() public view {
    uint256 _sumTargetAllocation;
    uint256 _targetsLength = handlerStakingManager.ghost_allocatedTargetIdsLength();

    for (uint256 _t = 0; _t < _targetsLength; _t++) {
      bytes32 _targetId = handlerStakingManager.ghost_allocatedTargetIds(_t);
      if (!handlerStakingManager.ghost_isAllocatedTarget(_targetId)) continue;
      _sumTargetAllocation += stakingManagerProxy.totalTargetAllocation(_targetId);
    }

    assertEq(
      _sumTargetAllocation, stakingManagerProxy.totalAllocated(), 'SM-INV-10: target allocation sum != totalAllocated'
    );
  }

  /// @notice SM-INV-11: `reallocate` must not change `totalAllocated` or the caller's `totalUserAllocation`
  function invariant_SM_INV_11_reallocate_conserves_totals() public view {
    assertFalse(
      handlerStakingManager.ghost_reallocateViolatedTotalAllocated(), 'SM-INV-11: reallocate changed totalAllocated'
    );

    uint256 _usersLength = handlerStakingManager.ghost_usersLength();
    for (uint256 _i = 0; _i < _usersLength; _i++) {
      address _user = handlerStakingManager.ghost_users(_i);
      if (!handlerStakingManager.ghost_isUser(_user)) continue;

      assertFalse(
        handlerStakingManager.ghost_reallocateViolatedUserAllocation(_user),
        'SM-INV-11: reallocate changed totalUserAllocation'
      );
    }
  }

  /// @notice SM-INV-12: `stakedGEOTokenProxy.balanceOf(user)` equals `totalUserStake(user)` for tracked users
  function invariant_SM_INV_12_stkgeo_balance_matches_stake() public view {
    uint256 _length = handlerStakingManager.ghost_usersLength();

    for (uint256 _i = 0; _i < _length; _i++) {
      address _user = handlerStakingManager.ghost_users(_i);
      if (!handlerStakingManager.ghost_isUser(_user)) continue;

      assertEq(
        stakedGEOTokenProxy.balanceOf(_user),
        stakingManagerProxy.totalUserStake(_user),
        'SM-INV-12: stkGEO balance != totalUserStake'
      );
    }
  }
}
