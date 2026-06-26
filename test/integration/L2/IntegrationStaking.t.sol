// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {IStakedGEOToken} from 'interfaces/L2/IStakedGEOToken.sol';
import {IStakingManager} from 'interfaces/L2/IStakingManager.sol';
import {IntegrationL2Base} from 'test/integration/L2/IntegrationL2Base.t.sol';

contract IntegrationStaking is IntegrationL2Base {
  function setUp() public override {
    IntegrationL2Base.setUp();
    _setActiveTarget(_targetRewardsSpaceId0);
    _setActiveTarget(_targetRewardsSpaceId1);
  }

  function test_StakeAllocateDeallocateAndReallocate() external {
    uint256 _minAmount = stakingManagerProxy.minAmount();
    uint256 _stakeAmount = _minAmount * 4;
    uint256 _allocAmount = _minAmount * 2;
    uint256 _deallocAmount = _minAmount;
    uint256 _reallocAmount = _minAmount;

    _stakeAndAllocate(_staker, _stakeAmount, _targetRewardsSpaceId0, _allocAmount);
    assertEq(stakingManagerProxy.totalUserStake(_staker), _stakeAmount);
    assertEq(_arbitrumGeoToken.balanceOf(_staker), 0);
    assertEq(_arbitrumGeoToken.balanceOf(address(stakingManagerProxy)), _stakeAmount);
    assertEq(stakedGEOTokenProxy.balanceOf(_staker), _stakeAmount);
    assertEq(stakedGEOTokenProxy.getVotes(_staker), _stakeAmount);
    assertEq(stakingManagerProxy.allocations(_staker, _targetRewardsSpaceId0), _allocAmount);

    vm.prank(_staker);
    stakingManagerProxy.deallocate(_targetRewardsSpaceId0, _deallocAmount);
    assertEq(stakingManagerProxy.allocations(_staker, _targetRewardsSpaceId0), _allocAmount - _deallocAmount);
    assertEq(_arbitrumGeoToken.balanceOf(_staker), 0);
    assertEq(_arbitrumGeoToken.balanceOf(address(stakingManagerProxy)), _stakeAmount);
    assertEq(stakedGEOTokenProxy.balanceOf(_staker), _stakeAmount);

    vm.startPrank(_staker);
    stakingManagerProxy.reallocate(_targetRewardsSpaceId0, _targetRewardsSpaceId1, _reallocAmount);
    assertEq(
      stakingManagerProxy.allocations(_staker, _targetRewardsSpaceId0), _allocAmount - _deallocAmount - _reallocAmount
    );
    assertEq(stakingManagerProxy.allocations(_staker, _targetRewardsSpaceId1), _reallocAmount);
    vm.stopPrank();
    assertEq(_arbitrumGeoToken.balanceOf(_staker), 0);
    assertEq(_arbitrumGeoToken.balanceOf(address(stakingManagerProxy)), _stakeAmount);
    assertEq(stakedGEOTokenProxy.balanceOf(_staker), _stakeAmount);
  }

  function test_UnstakeAfterDelay() external {
    uint256 _minAmount = stakingManagerProxy.minAmount();
    uint256 _stakeAmount = _minAmount * 2;
    uint256 _unstakeAmount = _minAmount;

    _fundWithArbitrumGeo(_staker, _stakeAmount);
    vm.startPrank(_staker);
    _arbitrumGeoToken.approve(address(stakingManagerProxy), _stakeAmount);
    stakingManagerProxy.stake(_stakeAmount);
    assertEq(_arbitrumGeoToken.balanceOf(_staker), 0);
    assertEq(_arbitrumGeoToken.balanceOf(address(stakingManagerProxy)), _stakeAmount);
    assertEq(stakedGEOTokenProxy.balanceOf(_staker), _stakeAmount);

    uint256 _unstakeId = stakingManagerProxy.requestUnstake(_unstakeAmount);
    vm.stopPrank();
    assertEq(_arbitrumGeoToken.balanceOf(_staker), 0);
    assertEq(_arbitrumGeoToken.balanceOf(address(stakingManagerProxy)), _stakeAmount);
    assertEq(stakedGEOTokenProxy.balanceOf(_staker), _stakeAmount);

    IStakingManager.UnstakeRequest memory _request = stakingManagerProxy.unstakeRequests(_unstakeId);
    vm.warp(_request.unlockTime);

    vm.prank(_staker);
    stakingManagerProxy.unstake(_unstakeId);
    assertEq(_arbitrumGeoToken.balanceOf(_staker), _unstakeAmount);
    assertEq(_arbitrumGeoToken.balanceOf(address(stakingManagerProxy)), _stakeAmount - _unstakeAmount);
    assertEq(stakingManagerProxy.totalUserStake(_staker), _stakeAmount - _unstakeAmount);
    assertEq(stakedGEOTokenProxy.balanceOf(_staker), _stakeAmount - _unstakeAmount);
    assertEq(stakedGEOTokenProxy.getVotes(_staker), _stakeAmount - _unstakeAmount);
  }

  function test_StakeForMintsStkGeoToRecipient() external {
    uint256 _minAmount = stakingManagerProxy.minAmount();
    uint256 _stakeAmount = _minAmount * 2;

    _fundWithArbitrumGeo(_staker, _stakeAmount);
    vm.startPrank(_staker);
    _arbitrumGeoToken.approve(address(stakingManagerProxy), _stakeAmount);
    stakingManagerProxy.stakeFor(_recipient, _stakeAmount);
    vm.stopPrank();

    assertEq(stakingManagerProxy.totalUserStake(_recipient), _stakeAmount);
    assertEq(_arbitrumGeoToken.balanceOf(_staker), 0);
    assertEq(_arbitrumGeoToken.balanceOf(_recipient), 0);
    assertEq(_arbitrumGeoToken.balanceOf(address(stakingManagerProxy)), _stakeAmount);
    assertEq(stakedGEOTokenProxy.balanceOf(_recipient), _stakeAmount);
    assertEq(stakedGEOTokenProxy.getVotes(_recipient), _stakeAmount);
    assertEq(stakingManagerProxy.totalUserStake(_staker), 0);
    assertEq(stakedGEOTokenProxy.balanceOf(_staker), 0);
    assertEq(stakedGEOTokenProxy.getVotes(_staker), 0);

    vm.prank(_recipient);
    vm.expectRevert(IStakedGEOToken.SoulboundTransfer.selector);
    stakedGEOTokenProxy.transfer(_staker, _stakeAmount);
  }
}
