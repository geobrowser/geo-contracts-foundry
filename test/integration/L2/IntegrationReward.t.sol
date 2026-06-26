// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {IRewarder} from 'interfaces/L2/IRewarder.sol';
import {IntegrationL2Base} from 'test/integration/L2/IntegrationL2Base.t.sol';

/**
 * @title IntegrationReward
 * @notice Fork tests for reward end-to-end flows and fixture-backed Merkle proof validation
 */
contract IntegrationReward is IntegrationL2Base {
  function test_PublishMerkleRoot() external {
    uint256 _epoch = 42;
    uint256 _total = 1000e18;
    bytes32 _root = keccak256('integration_root');

    vm.expectEmit();
    emit IRewarder.MerkleRootPublished(_epoch, _root, _total);
    _publishMerkleRoot(_epoch, _root, _total);

    assertEq(rewarderProxy.merkleRoot(_epoch), _root);
    assertEq(rewarderProxy.totalClaimableRewards(_epoch), _total);
  }

  function test_ClaimUserRewards_singleFixtureLeaf() external {
    _publishUserRewardsFixture();
    _fundWithArbitrumGeo(address(escrowProxy), _userRewardsTotalClaimable());

    uint256 _escrowBefore = _arbitrumGeoToken.balanceOf(address(escrowProxy));
    uint256 _balanceBefore = _arbitrumGeoToken.balanceOf(_userRewardsClaimer0);
    uint256 _amount = _claimUserFixtureLeaf(_USER_REWARDS_PRIMARY_INDEX);

    assertTrue(rewarderProxy.userClaimed(_userRewardsClaimer0, _userRewardsSpaceId, _USER_REWARDS_EPOCH));
    assertEq(_arbitrumGeoToken.balanceOf(_userRewardsClaimer0), _balanceBefore + _amount);
    assertEq(_arbitrumGeoToken.balanceOf(address(escrowProxy)), _escrowBefore - _amount);
    assertEq(rewarderProxy.totalClaimableRewards(_USER_REWARDS_EPOCH), _userRewardsTotalClaimable() - _amount);
  }

  function test_ClaimUserRewards_multipleFixtureLeaves_withMultiProof() external {
    _publishUserRewardsFixture();
    _fundWithArbitrumGeo(address(escrowProxy), _userRewardsTotalClaimable());

    (address _claimer0, uint256 _amount0) = _userRewardsClaimData(_USER_REWARDS_PRIMARY_INDEX);
    (address _claimer2, uint256 _amount2) = _userRewardsClaimData(_USER_REWARDS_PRIMARY_INDEX + 2);
    uint256 _escrowBefore = _arbitrumGeoToken.balanceOf(address(escrowProxy));
    uint256 _balance0Before = _arbitrumGeoToken.balanceOf(_claimer0);
    uint256 _balance2Before = _arbitrumGeoToken.balanceOf(_claimer2);

    uint256 _remaining = _userRewardsTotalClaimable();
    _remaining -= _claimUserFixtureLeaf(_USER_REWARDS_PRIMARY_INDEX);
    assertEq(rewarderProxy.totalClaimableRewards(_USER_REWARDS_EPOCH), _remaining);
    assertTrue(rewarderProxy.userClaimed(_claimer0, _userRewardsSpaceId, _USER_REWARDS_EPOCH));
    assertEq(_arbitrumGeoToken.balanceOf(_claimer0), _balance0Before + _amount0);
    assertEq(_arbitrumGeoToken.balanceOf(address(escrowProxy)), _escrowBefore - _amount0);

    _remaining -= _claimUserFixtureLeaf(_USER_REWARDS_PRIMARY_INDEX + 2);
    assertEq(rewarderProxy.totalClaimableRewards(_USER_REWARDS_EPOCH), _remaining);
    assertTrue(rewarderProxy.userClaimed(_claimer2, _userRewardsSpaceId, _USER_REWARDS_EPOCH));
    assertEq(_arbitrumGeoToken.balanceOf(_claimer2), _balance2Before + _amount2);
    assertEq(_arbitrumGeoToken.balanceOf(address(escrowProxy)), _escrowBefore - _amount0 - _amount2);
  }

  function test_ClaimUserRewards_revertsOnInvalidProof() external {
    _publishUserRewardsFixture();
    _fundWithArbitrumGeo(address(escrowProxy), _userRewardsTotalClaimable());

    (address _claimer, uint256 _amount,) = _userRewardsClaimAt(_USER_REWARDS_PRIMARY_INDEX);
    bytes32[] memory _badProof = new bytes32[](1);
    _badProof[0] = keccak256('integration_bad_proof_sibling');

    (uint256[] memory _epochs, uint256[] memory _amounts, bytes32[][] memory _proofs) =
      _epochsAmountsProofs(_USER_REWARDS_EPOCH, _amount, _badProof);

    vm.prank(_claimer);
    vm.expectRevert(IRewarder.InvalidProof.selector);
    rewarderProxy.claimUserRewards(_userRewardsSpaceId, _epochs, _amounts, _proofs);
  }

  function test_ClaimUserRewards_revertsWhenProofIsForAnotherLeaf() external {
    _publishUserRewardsFixture();
    _fundWithArbitrumGeo(address(escrowProxy), _userRewardsTotalClaimable());

    (address _claimer,,) = _userRewardsClaimAt(_USER_REWARDS_PRIMARY_INDEX);
    (, uint256 _otherAmount, bytes32[] memory _otherProof) = _userRewardsClaimAt(_USER_REWARDS_PRIMARY_INDEX + 1);

    (uint256[] memory _epochs, uint256[] memory _amounts, bytes32[][] memory _proofs) =
      _epochsAmountsProofs(_USER_REWARDS_EPOCH, _otherAmount, _otherProof);

    vm.prank(_claimer);
    vm.expectRevert(IRewarder.InvalidProof.selector);
    rewarderProxy.claimUserRewards(_userRewardsSpaceId, _epochs, _amounts, _proofs);
  }

  function test_ClaimTargetRewards() external {
    _publishTargetRewardsFixture();
    _fundWithArbitrumGeo(address(escrowProxy), _targetRewardsTotalClaimable());

    uint256 _escrowBefore = _arbitrumGeoToken.balanceOf(address(escrowProxy));
    uint256 _targetBalanceBefore = paymentManagerProxy.totalTargetBalance(_targetRewardsSpaceId0);
    uint256 _paymentManagerTokenBefore = _arbitrumGeoToken.balanceOf(address(paymentManagerProxy));
    uint256 _amount = _claimTargetFixtureLeaf(_TARGET_REWARDS_PRIMARY_INDEX);

    assertTrue(rewarderProxy.targetClaimed(_targetRewardsSpaceId0, _TARGET_REWARDS_EPOCH));
    assertEq(paymentManagerProxy.totalTargetBalance(_targetRewardsSpaceId0), _targetBalanceBefore + _amount);
    assertEq(_arbitrumGeoToken.balanceOf(address(paymentManagerProxy)), _paymentManagerTokenBefore + _amount);
    assertEq(_arbitrumGeoToken.balanceOf(address(escrowProxy)), _escrowBefore - _amount);
    assertEq(rewarderProxy.totalClaimableRewards(_TARGET_REWARDS_EPOCH), _targetRewardsTotalClaimable() - _amount);
  }

  function test_ClaimTargetRewards_revertsOnInvalidProof() external {
    _publishTargetRewardsFixture();
    _fundWithArbitrumGeo(address(escrowProxy), _targetRewardsTotalClaimable());

    (bytes32 _targetId, uint256 _amount,) = _targetRewardsClaimAt(_TARGET_REWARDS_PRIMARY_INDEX);
    bytes32[] memory _badProof = new bytes32[](1);
    _badProof[0] = keccak256('integration_bad_target_proof');

    (uint256[] memory _epochs, uint256[] memory _amounts, bytes32[][] memory _proofs) =
      _epochsAmountsProofs(_TARGET_REWARDS_EPOCH, _amount, _badProof);

    vm.expectRevert(IRewarder.InvalidProof.selector);
    rewarderProxy.claimTargetRewards(_targetId, _epochs, _amounts, _proofs);
  }

  function test_RevokeMerkleRoot() external {
    _publishUserRewardsFixture();
    _fundWithArbitrumGeo(address(escrowProxy), _userRewardsTotalClaimable());
    bytes32 _root = rewarderProxy.merkleRoot(_USER_REWARDS_EPOCH);

    vm.expectEmit();
    emit IRewarder.MerkleRootRevoked(_USER_REWARDS_EPOCH);
    _revokeMerkleRoot(_USER_REWARDS_EPOCH);

    assertTrue(rewarderProxy.merkleRootRevoked(_USER_REWARDS_EPOCH));
    assertEq(rewarderProxy.merkleRoot(_USER_REWARDS_EPOCH), _root);
    assertEq(rewarderProxy.totalClaimableRewards(_USER_REWARDS_EPOCH), 0);

    (address _claimer, uint256 _amount, bytes32[] memory _proof) = _userRewardsClaimAt(_USER_REWARDS_PRIMARY_INDEX);
    (uint256[] memory _epochs, uint256[] memory _amounts, bytes32[][] memory _proofs) =
      _epochsAmountsProofs(_USER_REWARDS_EPOCH, _amount, _proof);

    vm.prank(_claimer);
    vm.expectRevert(IRewarder.MerkleRootIsRevoked.selector);
    rewarderProxy.claimUserRewards(_userRewardsSpaceId, _epochs, _amounts, _proofs);
  }
}
