// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IStakingManager} from 'interfaces/L2/IStakingManager.sol';
import {IStakingRegistry} from 'interfaces/L2/IStakingRegistry.sol';

import {L2Setup} from 'test/invariants/L2/fuzz/L2Setup.t.sol';

/// @title ExecutionPaths
/// @notice Validates that invariant handlers can execute their intended paths
/// @dev Indirect code coverage check — all paths must be executable via handlers
contract L2ExecutionPaths is L2Setup {
  uint256 internal constant _STAKE_AMOUNT = 10e18;
  uint256 internal constant _DONATION_AMOUNT = 3e18;
  uint256 internal constant _ALLOC_AMOUNT = 2e18;
  uint256 internal constant _FIRST_OPEN_UNSTAKE_SEED = 0;
  uint256 internal constant _EXPECTED_SINGLE_OPEN_UNSTAKE_COUNT = 1;
  uint256 internal constant _EXECUTION_PATH_WARP_DELTA = 1 days;

  function test_setup() public view {
    assertGt(address(stakingManagerProxy).code.length, 0);
    assertEq(stakingManagerProxy.owner(), council);
    assertEq(address(stakingManagerProxy.arbitrumGeoToken()), address(geoToken));
    assertEq(stakingManagerProxy.minAmount(), _INVARIANT_MIN_AMOUNT);
    assertTrue(stakingRegistryProxy.targets(handlerStakingRegistry.PRESEED_TARGET_A()).tActive);
  }

  function test_handler_preseeded_targets_tracked() public view {
    assertEq(handlerStakingRegistry.ghost_activeTargetIdsLength(), handlerStakingRegistry.PRESEED_TARGET_COUNT());
    assertTrue(handlerStakingRegistry.ghost_isActiveTarget(handlerStakingRegistry.PRESEED_TARGET_A()));
  }

  function test_handler_stake() public {
    address _staker = stakers[_PRIMARY_STAKER_INDEX];
    uint256 _amount = _STAKE_AMOUNT;

    vm.prank(_staker);
    handlerStakingManager.handler_stake(_amount);
    assertTrue(handlerStakingManager.lastTxSucceeded(), 'stake should succeed');

    assertEq(stakingManagerProxy.totalUserStake(_staker), _amount);
    assertEq(stakingManagerProxy.totalStaked(), _amount);
    assertEq(stakedGEOTokenProxy.balanceOf(_staker), _amount);
    assertEq(IERC20(address(geoToken)).balanceOf(address(stakingManagerProxy)), _amount);
    assertTrue(handlerStakingManager.ghost_isUser(_staker));
  }

  function test_handler_stakeFor() public {
    address _staker = stakers[_PRIMARY_STAKER_INDEX];
    address _recipient = stakers[_SECONDARY_STAKER_INDEX];
    uint256 _amount = _STAKE_AMOUNT;

    vm.prank(_staker);
    handlerStakingManager.handler_stakeFor(_SECONDARY_STAKER_INDEX, _amount);
    assertTrue(handlerStakingManager.lastTxSucceeded(), 'stakeFor should succeed');

    assertEq(stakingManagerProxy.totalUserStake(_recipient), _amount);
    assertEq(stakingManagerProxy.totalStaked(), _amount);
    assertEq(stakedGEOTokenProxy.balanceOf(_recipient), _amount);
    assertEq(IERC20(address(geoToken)).balanceOf(address(stakingManagerProxy)), _amount);
    assertTrue(handlerStakingManager.ghost_isUser(_recipient));
  }

  function test_handler_transferGeoToManager() public {
    address _donor = stakers[_PRIMARY_STAKER_INDEX];

    vm.prank(_donor);
    handlerStakingManager.handler_transferGeoToManager(_DONATION_AMOUNT);
    assertTrue(handlerStakingManager.lastTxSucceeded(), 'transferGeoToManager should succeed');

    assertEq(
      IERC20(address(geoToken)).balanceOf(address(stakingManagerProxy)),
      _DONATION_AMOUNT,
      'donation should increase manager balance'
    );
  }

  function test_handler_allocate() public {
    address _staker = stakers[_PRIMARY_STAKER_INDEX];
    uint256 _targetAIndex = handlerStakingRegistry.PRESEED_TARGET_A_INDEX();

    vm.prank(_staker);
    handlerStakingManager.handler_stake(_STAKE_AMOUNT);
    assertTrue(handlerStakingManager.lastTxSucceeded());

    vm.prank(_staker);
    handlerStakingManager.handler_allocate(_targetAIndex, _ALLOC_AMOUNT);
    assertTrue(handlerStakingManager.lastTxSucceeded(), 'allocate should succeed');

    assertEq(stakingManagerProxy.totalUserAllocation(_staker), _ALLOC_AMOUNT);
    assertEq(stakingManagerProxy.allocations(_staker, handlerStakingRegistry.PRESEED_TARGET_A()), _ALLOC_AMOUNT);
    assertTrue(handlerStakingManager.ghost_userHasTarget(_staker, handlerStakingRegistry.PRESEED_TARGET_A()));
  }

  function test_handler_requestUnstake_and_unstake() public {
    address _staker = stakers[_PRIMARY_STAKER_INDEX];

    vm.prank(_staker);
    handlerStakingManager.handler_stake(_STAKE_AMOUNT);
    assertTrue(handlerStakingManager.lastTxSucceeded());

    vm.prank(_staker);
    handlerStakingManager.handler_requestUnstake(_ALLOC_AMOUNT);
    assertTrue(handlerStakingManager.lastTxSucceeded(), 'requestUnstake should succeed');

    assertEq(stakingManagerProxy.totalUserPendingUnstake(_staker), _ALLOC_AMOUNT);
    assertEq(handlerStakingManager.ghost_openUnstakeIdsLength(), _EXPECTED_SINGLE_OPEN_UNSTAKE_COUNT);

    vm.prank(_staker);
    handlerStakingManager.handler_unstake(_FIRST_OPEN_UNSTAKE_SEED);
    assertFalse(handlerStakingManager.lastTxSucceeded(), 'unstake before delay should be skipped');

    handlerBlockchain.handler_warp(_INVARIANT_UNSTAKE_REQUEST_DELAY);

    vm.prank(_staker);
    handlerStakingManager.handler_unstake(_FIRST_OPEN_UNSTAKE_SEED);
    assertTrue(handlerStakingManager.lastTxSucceeded(), 'unstake after delay should succeed');

    assertEq(stakingManagerProxy.totalUserStake(_staker), _STAKE_AMOUNT - _ALLOC_AMOUNT);
    assertEq(stakedGEOTokenProxy.balanceOf(_staker), _STAKE_AMOUNT - _ALLOC_AMOUNT);
    assertEq(IERC20(address(geoToken)).balanceOf(_staker), _ALLOC_AMOUNT);
    assertEq(stakingManagerProxy.totalPendingUnstake(), 0);
    assertEq(handlerStakingManager.ghost_openUnstakeIdsLength(), 0);
  }

  function test_handler_deallocate() public {
    address _staker = stakers[_PRIMARY_STAKER_INDEX];
    uint256 _targetAIndex = handlerStakingRegistry.PRESEED_TARGET_A_INDEX();

    vm.prank(_staker);
    handlerStakingManager.handler_stake(_STAKE_AMOUNT);
    vm.prank(_staker);
    handlerStakingManager.handler_allocate(_targetAIndex, _ALLOC_AMOUNT);

    vm.prank(_staker);
    handlerStakingManager.handler_deallocate(_targetAIndex, _ALLOC_AMOUNT);
    assertTrue(handlerStakingManager.lastTxSucceeded(), 'deallocate should succeed');

    assertEq(stakingManagerProxy.totalUserAllocation(_staker), 0);
    assertEq(stakingManagerProxy.allocations(_staker, handlerStakingRegistry.PRESEED_TARGET_A()), 0);
  }

  function test_handler_reallocate() public {
    address _staker = stakers[_PRIMARY_STAKER_INDEX];
    uint256 _targetAIndex = handlerStakingRegistry.PRESEED_TARGET_A_INDEX();
    uint256 _targetBIndex = handlerStakingRegistry.PRESEED_TARGET_B_INDEX();

    vm.prank(_staker);
    handlerStakingManager.handler_stake(_STAKE_AMOUNT);
    vm.prank(_staker);
    handlerStakingManager.handler_allocate(_targetAIndex, _ALLOC_AMOUNT);

    vm.prank(_staker);
    handlerStakingManager.handler_reallocate(_targetAIndex, _targetBIndex, _ALLOC_AMOUNT);
    assertTrue(handlerStakingManager.lastTxSucceeded(), 'reallocate should succeed');

    assertEq(stakingManagerProxy.allocations(_staker, handlerStakingRegistry.PRESEED_TARGET_A()), 0);
    assertEq(stakingManagerProxy.allocations(_staker, handlerStakingRegistry.PRESEED_TARGET_B()), _ALLOC_AMOUNT);
    assertEq(stakingManagerProxy.totalUserAllocation(_staker), _ALLOC_AMOUNT);
    assertFalse(handlerStakingManager.ghost_reallocateViolatedTotalAllocated());
    assertFalse(handlerStakingManager.ghost_reallocateViolatedUserAllocation(_staker));
  }

  function test_handler_setTargetActive() public {
    bytes32 _newTarget = keccak256('execution_paths_new_target');

    vm.prank(council);
    handlerStakingRegistry.handler_setTargetActive(uint256(_newTarget), true);
    assertTrue(handlerStakingRegistry.lastTxSucceeded(), 'setTarget active should succeed');
    assertTrue(stakingRegistryProxy.targets(_newTarget).tActive);
    assertTrue(handlerStakingRegistry.ghost_isActiveTarget(_newTarget));
  }

  function test_handler_allocate_without_stake_skipped() public {
    address _staker = stakers[_PRIMARY_STAKER_INDEX];
    uint256 _targetAIndex = handlerStakingRegistry.PRESEED_TARGET_A_INDEX();

    vm.prank(_staker);
    handlerStakingManager.handler_allocate(_targetAIndex, _ALLOC_AMOUNT);
    assertFalse(handlerStakingManager.lastTxSucceeded(), 'allocate without stake should be skipped');
  }

  function test_allocate_inactive_target_reverts() public {
    address _staker = stakers[_PRIMARY_STAKER_INDEX];
    bytes32 _inactiveTarget = keccak256('execution_paths_inactive_target');

    vm.prank(council);
    stakingRegistryProxy.setTarget(
      _inactiveTarget, IStakingRegistry.Target({tType: IStakingRegistry.TargetType.Space, tActive: false})
    );

    deal(address(geoToken), _staker, _STAKE_AMOUNT);
    vm.startPrank(_staker);
    geoToken.approve(address(stakingManagerProxy), _STAKE_AMOUNT);
    stakingManagerProxy.stake(_STAKE_AMOUNT);
    vm.expectRevert(IStakingManager.InactiveAllocationTarget.selector);
    stakingManagerProxy.allocate(_inactiveTarget, _ALLOC_AMOUNT);
    vm.stopPrank();
  }

  function test_handler_warp() public {
    uint256 _before = vm.getBlockTimestamp();
    handlerBlockchain.handler_warp(_EXECUTION_PATH_WARP_DELTA);
    assertEq(vm.getBlockTimestamp(), _before + _EXECUTION_PATH_WARP_DELTA);
  }
}
