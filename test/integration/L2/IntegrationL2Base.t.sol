// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IOutbox} from 'interfaces/L2/IOutbox.sol';
import {IStakingRegistry} from 'interfaces/L2/IStakingRegistry.sol';
import {DeployL2Contracts} from 'script/L2/DeployL2Contracts.s.sol';
import {IntegrationMerkleFixtures} from 'test/integration/L2/merkle/IntegrationMerkleFixtures.sol';
import {TestHelper} from 'unit-helpers/TestHelper.sol';

import 'script/Constants.sol' as Constants;

/**
 * @title IntegrationL2Base
 * @notice Arbitrum One fork helpers: deploy incentives stack via `DeployL2Contracts` (WETH as bridged GEO stand-in)
 */
abstract contract IntegrationL2Base is TestHelper, DeployL2Contracts, IntegrationMerkleFixtures {
  IERC20 internal _arbitrumGeoToken;

  address internal _staker = makeAddr('integration_staker');
  address internal _recipient = makeAddr('integration_recipient');
  address internal _payer = makeAddr('integration_payer');

  uint256 internal constant _ARBITRUM_ONE_FORK_BLOCK = 467_600_000;

  function setUp() public virtual {
    vm.createSelectFork(vm.rpcUrl('arbitrum_one'), _ARBITRUM_ONE_FORK_BLOCK);

    _arbitrumGeoToken = IERC20(Constants.ARBITRUM_ONE_GEO_TOKEN);

    _deployArbitrumOneStack();
  }

  function _deployArbitrumOneStack() internal {
    DeployL2Contracts.run();
  }

  function _mockOutboxSender(address _sender) internal {
    vm.mockCall(
      Constants.ARBITRUM_ONE_OUTBOX, abi.encodeWithSelector(IOutbox.l2ToL1Sender.selector), abi.encode(_sender)
    );
  }

  function _fundWithArbitrumGeo(address _to, uint256 _amount) internal {
    deal(Constants.ARBITRUM_ONE_GEO_TOKEN, _to, _amount);
  }

  function _setActiveTarget(bytes32 _targetId) internal {
    vm.prank(Constants.ARBITRUM_ONE_GEO_MULTISIG_COUNCIL);
    stakingRegistryProxy.setTarget(
      _targetId, IStakingRegistry.Target({tType: IStakingRegistry.TargetType.Space, tActive: true})
    );
  }

  function _stakeAndAllocate(address _user, uint256 _stakeAmount, bytes32 _targetId, uint256 _allocAmount) internal {
    _fundWithArbitrumGeo(_user, _stakeAmount);
    vm.startPrank(_user);
    _arbitrumGeoToken.approve(address(stakingManagerProxy), _stakeAmount);
    stakingManagerProxy.stake(_stakeAmount);
    stakingManagerProxy.allocate(_targetId, _allocAmount);
    vm.stopPrank();
  }

  function _publishMerkleRoot(uint256 _epoch, bytes32 _root, uint256 _totalClaimable) internal {
    vm.prank(Constants.ARBITRUM_ONE_GEO_MULTISIG_COUNCIL);
    rewarderProxy.publishMerkleRoot(_epoch, _root, _totalClaimable);
  }

  function _revokeMerkleRoot(uint256 _epoch) internal {
    vm.prank(Constants.ARBITRUM_ONE_GEO_MULTISIG_COUNCIL);
    rewarderProxy.revokeMerkleRoot(_epoch);
  }

  /// @notice Publishes the multi-leaf user fixture root for `_USER_REWARDS_EPOCH`
  function _publishUserRewardsFixture() internal {
    _publishMerkleRoot(_USER_REWARDS_EPOCH, _userRewardsRoot(), _userRewardsTotalClaimable());
  }

  /// @notice Publishes the multi-leaf target fixture root for `_TARGET_REWARDS_EPOCH`
  function _publishTargetRewardsFixture() internal {
    _publishMerkleRoot(_TARGET_REWARDS_EPOCH, _targetRewardsRoot(), _targetRewardsTotalClaimable());
  }

  /// @notice Claims user rewards for the fixture leaf at `_index` (fixture published and escrow funded by caller)
  function _claimUserFixtureLeaf(uint256 _index) internal returns (uint256 _amount) {
    (address _claimer, uint256 _claimAmount, bytes32[] memory _proof) = _userRewardsClaimAt(_index);
    _amount = _claimAmount;

    (uint256[] memory _epochs, uint256[] memory _amounts, bytes32[][] memory _proofs) =
      _epochsAmountsProofs(_USER_REWARDS_EPOCH, _amount, _proof);

    vm.prank(_claimer);
    rewarderProxy.claimUserRewards(_userRewardsSpaceId, _epochs, _amounts, _proofs);
  }

  /// @notice Claims target rewards for the fixture leaf at `_index` (fixture published and escrow funded by caller)
  function _claimTargetFixtureLeaf(uint256 _index) internal returns (uint256 _amount) {
    (bytes32 _targetId, uint256 _claimAmount, bytes32[] memory _proof) = _targetRewardsClaimAt(_index);
    _amount = _claimAmount;

    (uint256[] memory _epochs, uint256[] memory _amounts, bytes32[][] memory _proofs) =
      _epochsAmountsProofs(_TARGET_REWARDS_EPOCH, _amount, _proof);

    rewarderProxy.claimTargetRewards(_targetId, _epochs, _amounts, _proofs);
  }
}
