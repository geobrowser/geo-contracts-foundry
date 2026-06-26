// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

import {Hashes} from '@openzeppelin/contracts/utils/cryptography/Hashes.sol';
import {UnsafeUpgrades} from '@openzeppelin/foundry-upgrades/Upgrades.sol';
import {Rewarder} from 'contracts/L2/Rewarder.sol';
import {IEscrow} from 'interfaces/L2/IEscrow.sol';
import {IPaymentManager} from 'interfaces/L2/IPaymentManager.sol';
import {IRewarder} from 'interfaces/L2/IRewarder.sol';
import {MockRewarder} from 'test/unit/L2/mocks/MockRewarder.sol';
import {TestHelper} from 'unit-helpers/TestHelper.sol';

/// @dev Fuzzed epochs use disjoint bands: `base + caseIndex * 1_000 + bound(_epoch, 0, 999)`. Bases are
/// 10_000_000 (`publishMerkleRoot`), 20_000_000 (`revokeMerkleRoot`), 30_000_000 (`claimUserRewards`),
/// 40_000_000 (`claimTargetRewards`). Bump `caseIndex` by 1 per scenario within each entrypoint group.
contract UnitRewarder is TestHelper {
  address public council = makeAddr('council');

  address public alice = makeAddr('alice');
  address public bob = makeAddr('bob');

  address public escrow = makeAddr('escrow');
  address public paymentManager = makeAddr('paymentManager');

  MockRewarder public rewarderImplementation;
  MockRewarder public rewarderProxy;

  address public spaceTargetAddr = makeAddr('spaceTargetA');
  bytes32 public targetA = bytes32(uint256(uint160(spaceTargetAddr)));

  function setUp() external {
    rewarderImplementation = new MockRewarder();
    rewarderProxy = MockRewarder(
      payable(UnsafeUpgrades.deployUUPSProxy(
          address(rewarderImplementation),
          abi.encodeCall(
            Rewarder.initialize,
            (IRewarder.RewarderInitializationParams({escrow: escrow, paymentManager: paymentManager, council: council}))
          )
        ))
    );
  }

  // -------- constants --------
  function test_Constants_WhenDeployed() external view {
    // when deployed
    // it sets _REWARDER_STORAGE_LOCATION to keccak256(abi.encode(uint256(keccak256("geo.storage.Rewarder")) - 1)) & ~bytes32(uint256(0xff))
    assertEq(
      rewarderImplementation.exposed__REWARDER_STORAGE_LOCATION(),
      keccak256(abi.encode(uint256(keccak256('geo.storage.Rewarder')) - 1)) & ~bytes32(uint256(0xff))
    );
    // it sets MAX_TOTAL_CLAIMABLE_REWARDS_PER_EPOCH to 100_000_000e18
    assertEq(rewarderProxy.MAX_TOTAL_CLAIMABLE_REWARDS_PER_EPOCH(), 100_000_000e18);
    // it sets MAX_EPOCHS_PER_CLAIM to 50
    assertEq(rewarderProxy.MAX_EPOCHS_PER_CLAIM(), 50);
  }

  // -------- constructor --------
  function test_Constructor_WhenCalled() external {
    // when called
    // it disables initializers
    MockRewarder newImplementation = new MockRewarder();
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    newImplementation.initialize(
      IRewarder.RewarderInitializationParams({escrow: escrow, paymentManager: paymentManager, council: council})
    );
  }

  // -------- initialize --------
  function test_Initialize_WhenPassingValidParameters() external {
    // when passing valid parameters
    rewarderImplementation = new MockRewarder();
    MockRewarder freshRewarder = MockRewarder(
      payable(UnsafeUpgrades.deployUUPSProxy(
          address(rewarderImplementation),
          abi.encodeCall(
            Rewarder.initialize,
            (IRewarder.RewarderInitializationParams({escrow: escrow, paymentManager: paymentManager, council: council}))
          )
        ))
    );

    // it sets the owner
    assertEq(freshRewarder.owner(), council);
    // it sets escrow
    assertEq(address(freshRewarder.escrow()), escrow);
    // it sets paymentManager
    assertEq(address(freshRewarder.paymentManager()), paymentManager);
  }

  function test_Initialize_WhenCalledTwice() external {
    // when called twice
    // it reverts with InvalidInitialization
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    rewarderProxy.initialize(
      IRewarder.RewarderInitializationParams({escrow: escrow, paymentManager: paymentManager, council: council})
    );
  }

  function test_Initialize_WhenEscrowIsZero() external {
    // when escrow is zero
    // it reverts with InvalidAddress
    rewarderImplementation = new MockRewarder();
    vm.expectRevert(IRewarder.InvalidAddress.selector);
    MockRewarder(
      payable(UnsafeUpgrades.deployUUPSProxy(
          address(rewarderImplementation),
          abi.encodeCall(
            Rewarder.initialize,
            (IRewarder.RewarderInitializationParams({
                escrow: address(0), paymentManager: paymentManager, council: council
              }))
          )
        ))
    );
  }

  function test_Initialize_WhenPaymentManagerIsZero() external {
    // when paymentManager is zero
    // it reverts with InvalidAddress
    rewarderImplementation = new MockRewarder();
    vm.expectRevert(IRewarder.InvalidAddress.selector);
    MockRewarder(
      payable(UnsafeUpgrades.deployUUPSProxy(
          address(rewarderImplementation),
          abi.encodeCall(
            Rewarder.initialize,
            (IRewarder.RewarderInitializationParams({escrow: escrow, paymentManager: address(0), council: council}))
          )
        ))
    );
  }

  function test_Initialize_WhenCouncilIsZero() external {
    // when council is zero
    // it reverts with OwnableInvalidOwner
    rewarderImplementation = new MockRewarder();
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
    MockRewarder(
      payable(UnsafeUpgrades.deployUUPSProxy(
          address(rewarderImplementation),
          abi.encodeCall(
            Rewarder.initialize,
            (IRewarder.RewarderInitializationParams({
                escrow: escrow, paymentManager: paymentManager, council: address(0)
              }))
          )
        ))
    );
  }

  // -------- publishMerkleRoot --------
  function test_PublishMerkleRoot_WhenCalledByOwner(uint256 _epoch, uint256 _total, bytes32 _root) external {
    // when called by owner
    _epoch = 10_000_000 + bound(_epoch, 0, 999);
    _total = bound(_total, 1, rewarderProxy.MAX_TOTAL_CLAIMABLE_REWARDS_PER_EPOCH());
    vm.assume(_root != bytes32(0));

    // it emits MerkleRootPublished
    vm.expectEmit();
    emit IRewarder.MerkleRootPublished(_epoch, _root, _total);
    vm.prank(council);
    rewarderProxy.publishMerkleRoot(_epoch, _root, _total);

    // it stores the root and total claimable
    assertEq(rewarderProxy.merkleRoot(_epoch), _root);
    assertEq(rewarderProxy.totalClaimableRewards(_epoch), _total);
  }

  function test_PublishMerkleRoot_WhenRootIsZero(uint256 _epoch, uint256 _total) external {
    // when root is zero
    _epoch = 10_001_000 + bound(_epoch, 0, 999);
    _total = bound(_total, 1, rewarderProxy.MAX_TOTAL_CLAIMABLE_REWARDS_PER_EPOCH());

    // it reverts with InvalidMerkleRoot
    vm.prank(council);
    vm.expectRevert(IRewarder.InvalidMerkleRoot.selector);
    rewarderProxy.publishMerkleRoot(_epoch, bytes32(0), _total);
  }

  function test_PublishMerkleRoot_WhenTotalClaimableIsZero(uint256 _epoch, bytes32 _root) external {
    // when total claimable is zero
    _epoch = 10_002_000 + bound(_epoch, 0, 999);
    vm.assume(_root != bytes32(0));

    // it reverts with InvalidTotalClaimableRewards
    vm.prank(council);
    vm.expectRevert(IRewarder.InvalidTotalClaimableRewards.selector);
    rewarderProxy.publishMerkleRoot(_epoch, _root, 0);
  }

  function test_PublishMerkleRoot_WhenTotalExceedsCap(uint256 _epoch, uint256 _excess, bytes32 _root) external {
    // when total exceeds cap
    _epoch = 10_003_000 + bound(_epoch, 0, 999);
    uint256 _cap = rewarderProxy.MAX_TOTAL_CLAIMABLE_REWARDS_PER_EPOCH();
    _excess = bound(_excess, 1, 1_000_000e18);
    vm.assume(_root != bytes32(0));

    // it reverts with TotalClaimableRewardsCapExceeded
    vm.expectRevert(IRewarder.TotalClaimableRewardsCapExceeded.selector);
    vm.prank(council);
    rewarderProxy.publishMerkleRoot(_epoch, _root, _cap + _excess);
  }

  function test_PublishMerkleRoot_WhenAlreadyPublished(
    uint256 _epoch,
    uint256 _seedTotal,
    uint256 _secondTotal,
    bytes32 _seedRoot,
    bytes32 _secondRoot
  ) external {
    // when already published
    _epoch = 10_004_000 + bound(_epoch, 0, 999);
    uint256 _cap = rewarderProxy.MAX_TOTAL_CLAIMABLE_REWARDS_PER_EPOCH();
    _seedTotal = bound(_seedTotal, 1, _cap);
    _secondTotal = bound(_secondTotal, 1, _cap);
    vm.assume(_seedRoot != bytes32(0));
    vm.assume(_secondRoot != bytes32(0));

    rewarderProxy.workaround_seedPublishedEpoch(_epoch, _seedRoot, _seedTotal);

    // it reverts with MerkleRootAlreadyPublished on a second publish for the same epoch
    vm.expectRevert(IRewarder.MerkleRootAlreadyPublished.selector);
    vm.prank(council);
    rewarderProxy.publishMerkleRoot(_epoch, _secondRoot, _secondTotal);
  }

  function test_PublishMerkleRoot_WhenCalledByNon_owner(
    address _caller,
    uint256 _epoch,
    uint256 _total,
    bytes32 _root
  ) external {
    // when called by non-owner
    _assumeFuzzable(_caller);
    vm.assume(_caller != council);
    _epoch = 10_005_000 + bound(_epoch, 0, 999);
    _total = bound(_total, 1, rewarderProxy.MAX_TOTAL_CLAIMABLE_REWARDS_PER_EPOCH());
    vm.assume(_root != bytes32(0));

    // it reverts with OwnableUnauthorizedAccount
    vm.prank(_caller);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
    rewarderProxy.publishMerkleRoot(_epoch, _root, _total);
  }

  // -------- revokeMerkleRoot --------
  function test_RevokeMerkleRoot_WhenCalledByOwner(uint256 _epoch, uint256 _totalClaimable) external {
    // when called by owner
    _epoch = 20_000_000 + bound(_epoch, 0, 999);
    _totalClaimable = bound(_totalClaimable, 1, rewarderProxy.MAX_TOTAL_CLAIMABLE_REWARDS_PER_EPOCH());
    bytes32 _root = keccak256(abi.encodePacked(_epoch, _totalClaimable));
    rewarderProxy.workaround_seedPublishedEpoch(_epoch, _root, _totalClaimable);

    // it emits MerkleRootRevoked
    vm.expectEmit();
    emit IRewarder.MerkleRootRevoked(_epoch);
    vm.prank(council);
    rewarderProxy.revokeMerkleRoot(_epoch);

    // it marks the epoch as revoked
    assertTrue(rewarderProxy.merkleRootRevoked(_epoch));

    // it zeros remaining total claimable rewards for the epoch
    assertEq(rewarderProxy.totalClaimableRewards(_epoch), 0);
  }

  function test_RevokeMerkleRoot_WhenMerkleRootIsNotPublished(uint256 _epoch) external {
    // when merkle root is not published
    _epoch = 20_001_000 + bound(_epoch, 0, 999);

    // it reverts with MerkleRootNotPublished
    vm.prank(council);
    vm.expectRevert(IRewarder.MerkleRootNotPublished.selector);
    rewarderProxy.revokeMerkleRoot(_epoch);
  }

  function test_RevokeMerkleRoot_WhenAlreadyRevoked(uint256 _epoch, uint256 _totalClaimable) external {
    // when already revoked
    _epoch = 20_002_000 + bound(_epoch, 0, 999);
    _totalClaimable = bound(_totalClaimable, 1, rewarderProxy.MAX_TOTAL_CLAIMABLE_REWARDS_PER_EPOCH());
    bytes32 _root = keccak256(abi.encodePacked(_epoch, _totalClaimable));
    rewarderProxy.workaround_seedPublishedEpoch(_epoch, _root, _totalClaimable);
    rewarderProxy.workaround_setMerkleRootRevoked(_epoch, true);

    // it reverts with MerkleRootAlreadyRevoked
    vm.prank(council);
    vm.expectRevert(IRewarder.MerkleRootAlreadyRevoked.selector);
    rewarderProxy.revokeMerkleRoot(_epoch);
  }

  function test_RevokeMerkleRoot_WhenCalledByNon_owner(
    address _caller,
    uint256 _epoch,
    uint256 _totalClaimable
  ) external {
    // when called by non-owner
    _assumeFuzzable(_caller);
    vm.assume(_caller != council);
    _epoch = 20_003_000 + bound(_epoch, 0, 999);
    _totalClaimable = bound(_totalClaimable, 1, rewarderProxy.MAX_TOTAL_CLAIMABLE_REWARDS_PER_EPOCH());
    bytes32 _root = keccak256(abi.encodePacked(_epoch, _totalClaimable));
    rewarderProxy.workaround_seedPublishedEpoch(_epoch, _root, _totalClaimable);

    // it reverts with OwnableUnauthorizedAccount
    vm.prank(_caller);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
    rewarderProxy.revokeMerkleRoot(_epoch);
  }

  // -------- claimUserRewards --------
  function test_ClaimUserRewards_WhenTargetIdIsZero(uint256 _epoch, uint256 _amount) external {
    // when target id is zero
    _epoch = 30_000_000 + bound(_epoch, 0, 999);
    _amount = bound(_amount, 1, 1_000_000e18);

    uint256[] memory _epochs = new uint256[](1);
    _epochs[0] = _epoch;
    uint256[] memory _amounts = new uint256[](1);
    _amounts[0] = _amount;
    bytes32[][] memory _proofs = new bytes32[][](1);
    _proofs[0] = new bytes32[](0);

    // it reverts with InvalidTargetId
    vm.prank(alice);
    vm.expectRevert(IRewarder.InvalidTargetId.selector);
    rewarderProxy.claimUserRewards(bytes32(0), _epochs, _amounts, _proofs);
  }

  function test_ClaimUserRewards_WhenProofIsValid(uint256 _epoch, uint256 _amount, uint256 _publishedTotal) external {
    // when proof is valid
    _epoch = 30_000_000 + bound(_epoch, 0, 999);
    _amount = bound(_amount, 1e6, 10e18);
    _publishedTotal = bound(_publishedTotal, _amount, _amount + 1_000_000e18);
    vm.assume(_publishedTotal <= rewarderProxy.MAX_TOTAL_CLAIMABLE_REWARDS_PER_EPOCH());

    bytes32 _leaf = keccak256(abi.encodePacked(alice, targetA, _epoch, _amount));
    bytes32[] memory _siblingProof = new bytes32[](0);

    rewarderProxy.workaround_seedPublishedEpoch(_epoch, _leaf, _publishedTotal);

    uint256[] memory _epochs = new uint256[](1);
    _epochs[0] = _epoch;
    uint256[] memory _amounts = new uint256[](1);
    _amounts[0] = _amount;
    bytes32[][] memory _proofs = new bytes32[][](1);
    _proofs[0] = _siblingProof;

    // it transfers GEO from escrow to the user
    _mockAndExpectEscrowPull(alice, _amount);

    // it emits UserRewardsClaimed
    vm.expectEmit();
    emit IRewarder.UserRewardsClaimed(alice, targetA, _epoch, _amount);

    vm.prank(alice);
    rewarderProxy.claimUserRewards(targetA, _epochs, _amounts, _proofs);

    // it marks the claim and reduces remaining total claimable for the epoch
    assertTrue(rewarderProxy.userClaimed(alice, targetA, _epoch));
    assertEq(rewarderProxy.totalClaimableRewards(_epoch), _publishedTotal - _amount);
  }

  function test_ClaimUserRewards_WhenMerkleRootIsMissing(uint256 _epoch, uint256 _amount) external {
    // when merkle root is missing
    _epoch = 30_001_000 + bound(_epoch, 0, 999);
    _amount = bound(_amount, 1, 1_000_000e18);
    vm.assume(rewarderProxy.merkleRoot(_epoch) == bytes32(0));

    uint256[] memory _epochs = new uint256[](1);
    _epochs[0] = _epoch;
    uint256[] memory _amounts = new uint256[](1);
    _amounts[0] = _amount;
    bytes32[][] memory _proofs = new bytes32[][](1);
    _proofs[0] = new bytes32[](0);

    // it reverts with InvalidMerkleRoot
    vm.prank(alice);
    vm.expectRevert(IRewarder.InvalidMerkleRoot.selector);
    rewarderProxy.claimUserRewards(targetA, _epochs, _amounts, _proofs);
  }

  function test_ClaimUserRewards_WhenMerkleRootIsRevoked(uint256 _epoch, uint256 _amount) external {
    // when merkle root is revoked
    _epoch = 30_002_000 + bound(_epoch, 0, 999);
    _amount = bound(_amount, 1e6, 10e18);
    bytes32 _leaf = keccak256(abi.encodePacked(alice, targetA, _epoch, _amount));

    rewarderProxy.workaround_seedPublishedEpoch(_epoch, _leaf, _amount);
    rewarderProxy.workaround_setMerkleRootRevoked(_epoch, true);

    uint256[] memory _epochs = new uint256[](1);
    _epochs[0] = _epoch;
    uint256[] memory _amounts = new uint256[](1);
    _amounts[0] = _amount;
    bytes32[][] memory _proofs = new bytes32[][](1);
    _proofs[0] = new bytes32[](0);

    // it reverts with MerkleRootIsRevoked
    vm.prank(alice);
    vm.expectRevert(IRewarder.MerkleRootIsRevoked.selector);
    rewarderProxy.claimUserRewards(targetA, _epochs, _amounts, _proofs);
  }

  function test_ClaimUserRewards_WhenEpochsAmountsOrProofsLengthsMismatch(
    uint256 _lenEpochs,
    uint256 _lenOther,
    bool _mismatchIsProofs
  ) external {
    // when epochs amounts or proofs lengths mismatch
    uint256 _maxEpochs = uint256(rewarderProxy.MAX_EPOCHS_PER_CLAIM());
    _lenEpochs = bound(_lenEpochs, 1, _maxEpochs);

    uint256[] memory _epochs = new uint256[](_lenEpochs);
    uint256[] memory _amounts;
    bytes32[][] memory _proofs;

    if (_mismatchIsProofs) {
      _lenOther = bound(_lenOther, 0, _maxEpochs);
      vm.assume(_lenEpochs != _lenOther);
      _amounts = new uint256[](_lenEpochs);
      _proofs = new bytes32[][](_lenOther);
    } else {
      _lenOther = bound(_lenOther, 1, _maxEpochs);
      vm.assume(_lenEpochs != _lenOther);
      _amounts = new uint256[](_lenOther);
      _proofs = new bytes32[][](_lenEpochs);
    }

    // it reverts with InvalidArrayLength
    vm.prank(alice);
    vm.expectRevert(IRewarder.InvalidArrayLength.selector);
    rewarderProxy.claimUserRewards(targetA, _epochs, _amounts, _proofs);
  }

  function test_ClaimUserRewards_WhenEpochsExceedMaxPerClaim() external {
    // when epochs exceed max per claim
    uint256 _n = uint256(rewarderProxy.MAX_EPOCHS_PER_CLAIM()) + 1;
    uint256[] memory _epochs = new uint256[](_n);
    uint256[] memory _amounts = new uint256[](_n);
    bytes32[][] memory _proofs = new bytes32[][](_n);

    // it reverts with TooManyEpochsPerClaim
    vm.prank(alice);
    vm.expectRevert(IRewarder.TooManyEpochsPerClaim.selector);
    rewarderProxy.claimUserRewards(targetA, _epochs, _amounts, _proofs);
  }

  function test_ClaimUserRewards_WhenProofIsInvalid(
    uint256 _epoch,
    uint256 _amount,
    uint256 _publishedTotal,
    bytes32 _badProofNode
  ) external {
    // when proof is invalid
    _epoch = 30_003_000 + bound(_epoch, 0, 999);
    _amount = bound(_amount, 1e6, 100e18);
    _publishedTotal = bound(_publishedTotal, _amount, rewarderProxy.MAX_TOTAL_CLAIMABLE_REWARDS_PER_EPOCH());

    bytes32 _leaf = keccak256(abi.encodePacked(alice, targetA, _epoch, _amount));

    rewarderProxy.workaround_seedPublishedEpoch(_epoch, _leaf, _publishedTotal);

    uint256[] memory _epochs = new uint256[](1);
    _epochs[0] = _epoch;
    uint256[] memory _amounts = new uint256[](1);
    _amounts[0] = _amount;
    bytes32[][] memory _proofs = new bytes32[][](1);
    bytes32[] memory _badProof = new bytes32[](1);
    _badProof[0] = _badProofNode;
    _proofs[0] = _badProof;

    // it reverts with InvalidProof
    vm.prank(alice);
    vm.expectRevert(IRewarder.InvalidProof.selector);
    rewarderProxy.claimUserRewards(targetA, _epochs, _amounts, _proofs);
  }

  function test_ClaimUserRewards_WhenAlreadyClaimed(uint256 _epoch, uint256 _amount, uint256 _publishedTotal) external {
    // when already claimed
    _epoch = 30_004_000 + bound(_epoch, 0, 999);
    _amount = bound(_amount, 1e6, 50e18);
    _publishedTotal = bound(_publishedTotal, _amount, rewarderProxy.MAX_TOTAL_CLAIMABLE_REWARDS_PER_EPOCH());
    bytes32 _leaf = keccak256(abi.encodePacked(alice, targetA, _epoch, _amount));

    rewarderProxy.workaround_seedPublishedEpoch(_epoch, _leaf, _publishedTotal);
    rewarderProxy.workaround_setUserClaimed(alice, targetA, _epoch, true);

    uint256[] memory _epochs = new uint256[](1);
    _epochs[0] = _epoch;
    uint256[] memory _amounts = new uint256[](1);
    _amounts[0] = _amount;
    bytes32[][] memory _proofs = new bytes32[][](1);
    _proofs[0] = new bytes32[](0);

    // it reverts with RewardAlreadyClaimed on a second claim
    vm.prank(alice);
    vm.expectRevert(IRewarder.RewardAlreadyClaimed.selector);
    rewarderProxy.claimUserRewards(targetA, _epochs, _amounts, _proofs);
  }

  function test_ClaimUserRewards_WhenAmountExceedsPublishedTotal(
    uint256 _epoch,
    uint256 _publishedTotal,
    uint256 _amountExcess
  ) external {
    // when amount exceeds published total
    _epoch = 30_005_000 + bound(_epoch, 0, 999);
    _publishedTotal = bound(_publishedTotal, 1e6, 100e18);
    uint256 _amount = _publishedTotal + bound(_amountExcess, 1, 1000e18);
    bytes32 _leaf = keccak256(abi.encodePacked(alice, targetA, _epoch, _amount));

    rewarderProxy.workaround_seedPublishedEpoch(_epoch, _leaf, _publishedTotal);

    uint256[] memory _epochs = new uint256[](1);
    _epochs[0] = _epoch;
    uint256[] memory _amounts = new uint256[](1);
    _amounts[0] = _amount;
    bytes32[][] memory _proofs = new bytes32[][](1);
    _proofs[0] = new bytes32[](0);

    // it reverts with TotalClaimableRewardsExceeded when the claim amount exceeds the published total for the epoch
    vm.prank(alice);
    vm.expectRevert(IRewarder.TotalClaimableRewardsExceeded.selector);
    rewarderProxy.claimUserRewards(targetA, _epochs, _amounts, _proofs);
  }

  function test_ClaimUserRewards_WhenTwoLeavesProof(uint256 _epoch, uint256 _aliceAmount, uint256 _bobAmount) external {
    // when two leaves proof
    _epoch = 30_006_000 + bound(_epoch, 0, 999);
    _aliceAmount = bound(_aliceAmount, 1e6, 40e18);
    _bobAmount = bound(_bobAmount, 1e6, 40e18);
    vm.assume(_aliceAmount + _bobAmount <= 9_000_000e18);
    bytes32 _leafAlice = keccak256(abi.encodePacked(alice, targetA, _epoch, _aliceAmount));
    bytes32 _leafBob = keccak256(abi.encodePacked(bob, targetA, _epoch, _bobAmount));
    bytes32 _root = Hashes.commutativeKeccak256(_leafAlice, _leafBob);

    rewarderProxy.workaround_seedPublishedEpoch(_epoch, _root, _aliceAmount + _bobAmount);

    uint256[] memory _epochs = new uint256[](1);
    _epochs[0] = _epoch;
    uint256[] memory _amounts = new uint256[](1);
    bytes32[][] memory _proofs = new bytes32[][](1);
    _amounts[0] = _aliceAmount;
    _proofs[0] = new bytes32[](1);
    _proofs[0][0] = _leafBob;

    _mockAndExpectEscrowPull(alice, _aliceAmount);
    vm.prank(alice);
    rewarderProxy.claimUserRewards(targetA, _epochs, _amounts, _proofs);

    _amounts[0] = _bobAmount;
    _proofs[0][0] = _leafAlice;
    _mockAndExpectEscrowPull(bob, _bobAmount);
    vm.prank(bob);
    rewarderProxy.claimUserRewards(targetA, _epochs, _amounts, _proofs);

    // it allows both users to claim
    assertTrue(rewarderProxy.userClaimed(alice, targetA, _epoch));
    assertTrue(rewarderProxy.userClaimed(bob, targetA, _epoch));
  }

  // -------- claimTargetRewards --------
  function test_ClaimTargetRewards_WhenTargetIdIsZero(uint256 _epoch, uint256 _amount) external {
    // when target id is zero
    _epoch = 40_000_000 + bound(_epoch, 0, 999);
    _amount = bound(_amount, 1, 1_000_000e18);

    uint256[] memory _epochs = new uint256[](1);
    _epochs[0] = _epoch;
    uint256[] memory _amounts = new uint256[](1);
    _amounts[0] = _amount;
    bytes32[][] memory _proofs = new bytes32[][](1);
    _proofs[0] = new bytes32[](0);

    // it reverts with InvalidTargetId
    vm.prank(alice);
    vm.expectRevert(IRewarder.InvalidTargetId.selector);
    rewarderProxy.claimTargetRewards(bytes32(0), _epochs, _amounts, _proofs);
  }

  function test_ClaimTargetRewards_WhenEpochsAmountsOrProofsLengthsMismatch(
    uint256 _lenEpochs,
    uint256 _lenOther,
    bool _mismatchIsProofs
  ) external {
    // when epochs amounts or proofs lengths mismatch
    uint256 _maxEpochs = uint256(rewarderProxy.MAX_EPOCHS_PER_CLAIM());
    _lenEpochs = bound(_lenEpochs, 1, _maxEpochs);

    uint256[] memory _epochs = new uint256[](_lenEpochs);
    uint256[] memory _amounts;
    bytes32[][] memory _proofs;

    if (_mismatchIsProofs) {
      _lenOther = bound(_lenOther, 0, _maxEpochs);
      vm.assume(_lenEpochs != _lenOther);
      _amounts = new uint256[](_lenEpochs);
      _proofs = new bytes32[][](_lenOther);
    } else {
      _lenOther = bound(_lenOther, 1, _maxEpochs);
      vm.assume(_lenEpochs != _lenOther);
      _amounts = new uint256[](_lenOther);
      _proofs = new bytes32[][](_lenEpochs);
    }

    // it reverts with InvalidArrayLength
    vm.prank(alice);
    vm.expectRevert(IRewarder.InvalidArrayLength.selector);
    rewarderProxy.claimTargetRewards(targetA, _epochs, _amounts, _proofs);
  }

  function test_ClaimTargetRewards_WhenEpochsExceedMaxPerClaim() external {
    // when epochs exceed max per claim
    uint256 _n = uint256(rewarderProxy.MAX_EPOCHS_PER_CLAIM()) + 1;
    uint256[] memory _epochs = new uint256[](_n);
    uint256[] memory _amounts = new uint256[](_n);
    bytes32[][] memory _proofs = new bytes32[][](_n);

    // it reverts with TooManyEpochsPerClaim
    vm.prank(alice);
    vm.expectRevert(IRewarder.TooManyEpochsPerClaim.selector);
    rewarderProxy.claimTargetRewards(targetA, _epochs, _amounts, _proofs);
  }

  function test_ClaimTargetRewards_WhenMerkleRootIsMissing(uint256 _epoch, uint256 _amount) external {
    // when merkle root is missing
    _epoch = 40_000_000 + bound(_epoch, 0, 999);
    _amount = bound(_amount, 1, 1_000_000e18);
    vm.assume(rewarderProxy.merkleRoot(_epoch) == bytes32(0));

    uint256[] memory _epochs = new uint256[](1);
    _epochs[0] = _epoch;
    uint256[] memory _amounts = new uint256[](1);
    _amounts[0] = _amount;
    bytes32[][] memory _proofs = new bytes32[][](1);
    _proofs[0] = new bytes32[](0);

    // it reverts with InvalidMerkleRoot
    vm.prank(alice);
    vm.expectRevert(IRewarder.InvalidMerkleRoot.selector);
    rewarderProxy.claimTargetRewards(targetA, _epochs, _amounts, _proofs);
  }

  function test_ClaimTargetRewards_WhenMerkleRootIsRevoked(uint256 _epoch, uint256 _amount) external {
    // when merkle root is revoked
    _epoch = 40_001_000 + bound(_epoch, 0, 999);
    _amount = bound(_amount, 1e6, 500e18);
    bytes32 _leaf = keccak256(abi.encodePacked(targetA, _epoch, _amount));

    rewarderProxy.workaround_seedPublishedEpoch(_epoch, _leaf, _amount);
    rewarderProxy.workaround_setMerkleRootRevoked(_epoch, true);

    uint256[] memory _epochs = new uint256[](1);
    _epochs[0] = _epoch;
    uint256[] memory _amounts = new uint256[](1);
    _amounts[0] = _amount;
    bytes32[][] memory _proofs = new bytes32[][](1);
    _proofs[0] = new bytes32[](0);

    // it reverts with MerkleRootIsRevoked
    vm.prank(alice);
    vm.expectRevert(IRewarder.MerkleRootIsRevoked.selector);
    rewarderProxy.claimTargetRewards(targetA, _epochs, _amounts, _proofs);
  }

  function test_ClaimTargetRewards_WhenProofIsInvalid(
    uint256 _epoch,
    uint256 _amount,
    uint256 _publishedTotal,
    bytes32 _badProofNode
  ) external {
    // when proof is invalid
    _epoch = 40_002_000 + bound(_epoch, 0, 999);
    _amount = bound(_amount, 1e6, 100e18);
    _publishedTotal = bound(_publishedTotal, _amount, rewarderProxy.MAX_TOTAL_CLAIMABLE_REWARDS_PER_EPOCH());
    bytes32 _leaf = keccak256(abi.encodePacked(targetA, _epoch, _amount));

    rewarderProxy.workaround_seedPublishedEpoch(_epoch, _leaf, _publishedTotal);

    uint256[] memory _epochs = new uint256[](1);
    _epochs[0] = _epoch;
    uint256[] memory _amounts = new uint256[](1);
    _amounts[0] = _amount;
    bytes32[][] memory _proofs = new bytes32[][](1);
    bytes32[] memory _badProof = new bytes32[](1);
    _badProof[0] = _badProofNode;
    _proofs[0] = _badProof;

    // it reverts with InvalidProof
    vm.prank(alice);
    vm.expectRevert(IRewarder.InvalidProof.selector);
    rewarderProxy.claimTargetRewards(targetA, _epochs, _amounts, _proofs);
  }

  function test_ClaimTargetRewards_WhenAmountExceedsPublishedTotal(
    uint256 _epoch,
    uint256 _publishedTotal,
    uint256 _amountExcess
  ) external {
    // when amount exceeds published total
    _epoch = 40_003_000 + bound(_epoch, 0, 999);
    _publishedTotal = bound(_publishedTotal, 1e6, 100e18);
    uint256 _amount = _publishedTotal + bound(_amountExcess, 1, 1000e18);
    bytes32 _leaf = keccak256(abi.encodePacked(targetA, _epoch, _amount));

    rewarderProxy.workaround_seedPublishedEpoch(_epoch, _leaf, _publishedTotal);

    uint256[] memory _epochs = new uint256[](1);
    _epochs[0] = _epoch;
    uint256[] memory _amounts = new uint256[](1);
    _amounts[0] = _amount;
    bytes32[][] memory _proofs = new bytes32[][](1);
    _proofs[0] = new bytes32[](0);

    // it reverts with TotalClaimableRewardsExceeded
    vm.prank(alice);
    vm.expectRevert(IRewarder.TotalClaimableRewardsExceeded.selector);
    rewarderProxy.claimTargetRewards(targetA, _epochs, _amounts, _proofs);
  }

  function test_ClaimTargetRewards_WhenProofIsValid(
    uint256 _epoch,
    uint256 _amount,
    uint256 _publishedTotal,
    bool _nonCanonicalSpaceEncoding
  ) external {
    // when proof is valid
    _epoch = 40_004_000 + bound(_epoch, 0, 999);
    _amount = bound(_amount, 1e6, 500e18);
    _publishedTotal = bound(_publishedTotal, _amount, rewarderProxy.MAX_TOTAL_CLAIMABLE_REWARDS_PER_EPOCH());
    bytes32 _target = _nonCanonicalSpaceEncoding ? bytes32(uint256(type(uint160).max) + 1) : targetA;

    bytes32 _leaf = keccak256(abi.encodePacked(_target, _epoch, _amount));
    rewarderProxy.workaround_seedPublishedEpoch(_epoch, _leaf, _publishedTotal);

    uint256[] memory _epochs = new uint256[](1);
    _epochs[0] = _epoch;
    uint256[] memory _amounts = new uint256[](1);
    _amounts[0] = _amount;
    bytes32[][] memory _proofs = new bytes32[][](1);
    _proofs[0] = new bytes32[](0);

    // it transfers GEO to the PaymentManager
    _mockAndExpectEscrowPull(paymentManager, _amount);
    // it credits the target balance on the PaymentManager once with the total amount
    _mockAndExpectProcessRewards(_target, _amount);

    // it emits TargetRewardsClaimed
    vm.expectEmit();
    emit IRewarder.TargetRewardsClaimed(_target, _epoch, _amount);

    address _stranger = makeAddr('stranger');
    vm.prank(_stranger);
    rewarderProxy.claimTargetRewards(_target, _epochs, _amounts, _proofs);

    assertTrue(rewarderProxy.targetClaimed(_target, _epoch));
  }

  function test_ClaimTargetRewards_WhenMultipleEpochs(uint256 _a1, uint256 _a2) external {
    // when multiple epochs
    uint256 _e1 = 40_005_000;
    uint256 _e2 = 40_005_001;
    _a1 = bound(_a1, 1e6, 200e18);
    _a2 = bound(_a2, 1e6, 200e18);
    vm.assume(_a1 + _a2 <= 9_000_000e18);

    bytes32 _l1 = keccak256(abi.encodePacked(targetA, _e1, _a1));
    bytes32 _l2 = keccak256(abi.encodePacked(targetA, _e2, _a2));

    rewarderProxy.workaround_seedPublishedEpoch(_e1, _l1, _a1);
    rewarderProxy.workaround_seedPublishedEpoch(_e2, _l2, _a2);

    uint256[] memory _epochs = new uint256[](2);
    _epochs[0] = _e1;
    _epochs[1] = _e2;
    uint256[] memory _amounts = new uint256[](2);
    _amounts[0] = _a1;
    _amounts[1] = _a2;
    bytes32[][] memory _proofs = new bytes32[][](2);
    _proofs[0] = new bytes32[](0);
    _proofs[1] = new bytes32[](0);

    _mockAndExpectEscrowPull(paymentManager, _a1 + _a2);
    // it credits the merged Space balance on the PaymentManager
    _mockAndExpectProcessRewards(targetA, _a1 + _a2);

    vm.prank(bob);
    rewarderProxy.claimTargetRewards(targetA, _epochs, _amounts, _proofs);
  }

  function test_ClaimTargetRewards_WhenAlreadyClaimed(
    uint256 _epoch,
    uint256 _amount,
    uint256 _publishedTotal
  ) external {
    // when already claimed
    _epoch = 40_006_000 + bound(_epoch, 0, 999);
    _amount = bound(_amount, 1e6, 40e18);
    _publishedTotal = bound(_publishedTotal, _amount, rewarderProxy.MAX_TOTAL_CLAIMABLE_REWARDS_PER_EPOCH());
    bytes32 _leaf = keccak256(abi.encodePacked(targetA, _epoch, _amount));

    rewarderProxy.workaround_seedPublishedEpoch(_epoch, _leaf, _publishedTotal);
    rewarderProxy.workaround_setTargetClaimed(targetA, _epoch, true);

    uint256[] memory _epochs = new uint256[](1);
    _epochs[0] = _epoch;
    uint256[] memory _amounts = new uint256[](1);
    _amounts[0] = _amount;
    bytes32[][] memory _proofs = new bytes32[][](1);
    _proofs[0] = new bytes32[](0);

    // it reverts with RewardAlreadyClaimed
    vm.prank(alice);
    vm.expectRevert(IRewarder.RewardAlreadyClaimed.selector);
    rewarderProxy.claimTargetRewards(targetA, _epochs, _amounts, _proofs);
  }

  function test_ClaimTargetRewards_WhenEmptyArrays() external {
    // when empty arrays
    uint256[] memory _epochs = new uint256[](0);
    uint256[] memory _amounts = new uint256[](0);
    bytes32[][] memory _proofs = new bytes32[][](0);

    // it performs no PaymentManager balance credit
    vm.expectCall(paymentManager, abi.encodeWithSelector(IPaymentManager.processRewards.selector), 0);
    vm.expectCall(escrow, abi.encodeWithSelector(IEscrow.pull.selector), 0);

    vm.prank(alice);
    rewarderProxy.claimTargetRewards(targetA, _epochs, _amounts, _proofs);
  }

  // -------- typeId --------
  function test_TypeId_WhenCalled() external view {
    // when called

    // it returns the type
    assertEq(rewarderProxy.typeId(), keccak256('REWARDER'));
  }

  // -------- name --------
  function test_Name_WhenCalled() external view {
    // when called

    // it returns the name
    assertEq(rewarderProxy.name(), 'REWARDER');
  }

  // -------- version --------
  function test_Version_WhenCalled() external view {
    // when called

    // it returns semantic version
    assertEq(rewarderProxy.version(), '1.0.0');
  }

  // -------- _authorizeUpgrade --------
  function test__authorizeUpgrade_WhenCalledByOwner() external {
    // when called by owner
    address newImplementation = address(new Rewarder());
    vm.prank(council);

    // it authorizes the upgrade
    rewarderProxy.upgradeToAndCall(newImplementation, '');
  }

  function test__authorizeUpgrade_WhenCalledByNon_owner(address _caller) external {
    // when called by non-owner
    _assumeFuzzable(_caller);
    vm.assume(_caller != council);
    address newImplementation = address(new Rewarder());
    vm.prank(_caller);

    // it reverts with OwnableUnauthorizedAccount
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
    rewarderProxy.upgradeToAndCall(newImplementation, '');
  }

  /**
   * @notice Mocks `IEscrow.pull(_to, _amount)` on the `escrow` mock address and registers an `expectCall` so the test
   * asserts the Rewarder forwarded the pull to escrow with the expected recipient and amount
   */
  function _mockAndExpectEscrowPull(address _to, uint256 _amount) internal {
    _mockAndExpect(escrow, abi.encodeCall(IEscrow.pull, (_to, _amount)), '');
  }

  /**
   * @notice Mocks `IPaymentManager.processRewards(_targetId, _amount)` on the `paymentManager` mock address and
   * registers an `expectCall` so the test asserts the Rewarder notified the PaymentManager of the minted batch
   */
  function _mockAndExpectProcessRewards(bytes32 _targetId, uint256 _amount) internal {
    _mockAndExpect(paymentManager, abi.encodeCall(IPaymentManager.processRewards, (_targetId, _amount)), '');
  }
}
