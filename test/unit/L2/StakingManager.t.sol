// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {UnsafeUpgrades} from '@openzeppelin/foundry-upgrades/Upgrades.sol';
import {StakingManager} from 'contracts/L2/StakingManager.sol';
import {IStakedGEOToken} from 'interfaces/L2/IStakedGEOToken.sol';
import {IStakingManager} from 'interfaces/L2/IStakingManager.sol';
import {IStakingRegistry} from 'interfaces/L2/IStakingRegistry.sol';
import {MockStakingManager} from 'test/unit/L2/mocks/MockStakingManager.sol';
import {TestHelper} from 'unit-helpers/TestHelper.sol';

contract UnitStakingManager is TestHelper {
  uint256 internal constant _MAX_STAKE_AMOUNT = type(uint208).max;

  address public council = makeAddr('council');
  address public alice = makeAddr('alice');
  address public distributor = makeAddr('distributor');

  uint256 public minAmount = 100e18;
  uint256 public unstakeDelay = 1 days;

  address public arbitrumGeoToken = makeAddr('arbitrumGeoToken');
  address public stakingRegistry = makeAddr('stakingRegistry');
  address public stakedGEOToken = makeAddr('stakedGEOToken');

  MockStakingManager public stakingManagerImplementation;
  MockStakingManager public stakingManagerProxy;

  bytes32 public targetA = keccak256('targetA');
  bytes32 public targetB = keccak256('targetB');
  bytes32 public targetInactive = keccak256('targetInactive');

  function setUp() external {
    stakingManagerImplementation = new MockStakingManager();
    stakingManagerProxy = MockStakingManager(
      payable(UnsafeUpgrades.deployUUPSProxy(
          address(stakingManagerImplementation),
          abi.encodeCall(
            StakingManager.initialize,
            (IStakingManager.StakingManagerInitializationParams({
                arbitrumGeoToken: arbitrumGeoToken,
                council: council,
                stakingRegistry: stakingRegistry,
                stakedGEOToken: stakedGEOToken,
                minAmount: minAmount,
                unstakeRequestDelay: unstakeDelay
              }))
          )
        ))
    );
  }

  // -------- constants --------
  function test_Constants_WhenDeployed() external view {
    // when deployed
    // it sets _STAKING_MANAGER_STORAGE_LOCATION to keccak256(abi.encode(uint256(keccak256("geo.storage.StakingManager")) - 1)) & ~bytes32(uint256(0xff))
    assertEq(
      stakingManagerImplementation.exposed__STAKING_MANAGER_STORAGE_LOCATION(),
      keccak256(abi.encode(uint256(keccak256('geo.storage.StakingManager')) - 1)) & ~bytes32(uint256(0xff))
    );
    // it sets MAX_UNSTAKE_REQUEST_DELAY to 30 days
    assertEq(stakingManagerImplementation.MAX_UNSTAKE_REQUEST_DELAY(), 30 days);
  }

  // -------- constructor --------
  function test_Constructor_WhenCalled() external {
    // it disables initializers
    StakingManager newImplementation = new StakingManager();
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    newImplementation.initialize(
      IStakingManager.StakingManagerInitializationParams({
        arbitrumGeoToken: arbitrumGeoToken,
        council: council,
        stakingRegistry: stakingRegistry,
        stakedGEOToken: stakedGEOToken,
        minAmount: minAmount,
        unstakeRequestDelay: unstakeDelay
      })
    );
  }

  // -------- initialize --------
  function test_Initialize_WhenPassingValidParameters() external {
    // when passing valid parameters
    stakingManagerImplementation = new MockStakingManager();
    // it emits MinAmountSet
    vm.expectEmit();
    emit IStakingManager.MinAmountSet(minAmount);
    // it emits UnstakeRequestDelaySet
    vm.expectEmit();
    emit IStakingManager.UnstakeRequestDelaySet(unstakeDelay);
    MockStakingManager freshStakingManager = MockStakingManager(
      payable(UnsafeUpgrades.deployUUPSProxy(
          address(stakingManagerImplementation),
          abi.encodeCall(
            StakingManager.initialize,
            (IStakingManager.StakingManagerInitializationParams({
                arbitrumGeoToken: arbitrumGeoToken,
                council: council,
                stakingRegistry: stakingRegistry,
                stakedGEOToken: stakedGEOToken,
                minAmount: minAmount,
                unstakeRequestDelay: unstakeDelay
              }))
          )
        ))
    );

    // it sets the owner
    assertEq(freshStakingManager.owner(), council);
    // it sets arbitrumGeoToken
    assertEq(address(freshStakingManager.arbitrumGeoToken()), arbitrumGeoToken);
    // it sets the min amount
    assertEq(freshStakingManager.minAmount(), minAmount);
    // it sets the unstake delay
    assertEq(freshStakingManager.unstakeRequestDelay(), unstakeDelay);
    // it sets the staking registry
    assertEq(address(freshStakingManager.stakingRegistry()), stakingRegistry);
    // it sets stakedGEOToken
    assertEq(address(freshStakingManager.stakedGEOToken()), stakedGEOToken);
  }

  function test_Initialize_WhenCalledTwice() external {
    // it reverts with InvalidInitialization
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    stakingManagerProxy.initialize(
      IStakingManager.StakingManagerInitializationParams({
        arbitrumGeoToken: arbitrumGeoToken,
        council: council,
        stakingRegistry: stakingRegistry,
        stakedGEOToken: stakedGEOToken,
        minAmount: minAmount,
        unstakeRequestDelay: unstakeDelay
      })
    );
  }

  function test_Initialize_WhenArbitrumGeoTokenIsZero() external {
    // it reverts with InvalidAddress
    stakingManagerImplementation = new MockStakingManager();
    vm.expectRevert(IStakingManager.InvalidAddress.selector);
    MockStakingManager(
      payable(UnsafeUpgrades.deployUUPSProxy(
          address(stakingManagerImplementation),
          abi.encodeCall(
            StakingManager.initialize,
            (IStakingManager.StakingManagerInitializationParams({
                arbitrumGeoToken: address(0),
                council: council,
                stakingRegistry: stakingRegistry,
                stakedGEOToken: stakedGEOToken,
                minAmount: minAmount,
                unstakeRequestDelay: unstakeDelay
              }))
          )
        ))
    );
  }

  function test_Initialize_WhenOwnerIsZero() external {
    // it reverts with OwnableInvalidOwner
    stakingManagerImplementation = new MockStakingManager();
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
    MockStakingManager(
      payable(UnsafeUpgrades.deployUUPSProxy(
          address(stakingManagerImplementation),
          abi.encodeCall(
            StakingManager.initialize,
            (IStakingManager.StakingManagerInitializationParams({
                arbitrumGeoToken: arbitrumGeoToken,
                council: address(0),
                stakingRegistry: stakingRegistry,
                stakedGEOToken: stakedGEOToken,
                minAmount: minAmount,
                unstakeRequestDelay: unstakeDelay
              }))
          )
        ))
    );
  }

  function test_Initialize_WhenStakingRegistryIsZero() external {
    // when staking registry is zero
    // it reverts with InvalidAddress
    stakingManagerImplementation = new MockStakingManager();
    vm.expectRevert(IStakingManager.InvalidAddress.selector);
    MockStakingManager(
      payable(UnsafeUpgrades.deployUUPSProxy(
          address(stakingManagerImplementation),
          abi.encodeCall(
            StakingManager.initialize,
            (IStakingManager.StakingManagerInitializationParams({
                arbitrumGeoToken: arbitrumGeoToken,
                council: council,
                stakingRegistry: address(0),
                stakedGEOToken: stakedGEOToken,
                minAmount: minAmount,
                unstakeRequestDelay: unstakeDelay
              }))
          )
        ))
    );
  }

  function test_Initialize_WhenStakedGEOTokenIsZero() external {
    // it reverts with InvalidAddress
    stakingManagerImplementation = new MockStakingManager();
    vm.expectRevert(IStakingManager.InvalidAddress.selector);
    MockStakingManager(
      payable(UnsafeUpgrades.deployUUPSProxy(
          address(stakingManagerImplementation),
          abi.encodeCall(
            StakingManager.initialize,
            (IStakingManager.StakingManagerInitializationParams({
                arbitrumGeoToken: arbitrumGeoToken,
                council: council,
                stakingRegistry: stakingRegistry,
                stakedGEOToken: address(0),
                minAmount: minAmount,
                unstakeRequestDelay: unstakeDelay
              }))
          )
        ))
    );
  }

  function test_Initialize_WhenMinAmountIsZero() external {
    // when min amount is zero
    // it reverts with ZeroAmount
    stakingManagerImplementation = new MockStakingManager();
    vm.expectRevert(IStakingManager.ZeroAmount.selector);
    MockStakingManager(
      payable(UnsafeUpgrades.deployUUPSProxy(
          address(stakingManagerImplementation),
          abi.encodeCall(
            StakingManager.initialize,
            (IStakingManager.StakingManagerInitializationParams({
                arbitrumGeoToken: arbitrumGeoToken,
                council: council,
                stakingRegistry: stakingRegistry,
                stakedGEOToken: stakedGEOToken,
                minAmount: 0,
                unstakeRequestDelay: unstakeDelay
              }))
          )
        ))
    );
  }

  function test_Initialize_WhenUnstakeRequestDelayExceedsMaximum() external {
    // when unstake request delay exceeds maximum
    // it reverts with UnstakeRequestDelayExceedsMaximum
    stakingManagerImplementation = new MockStakingManager();
    vm.expectRevert(IStakingManager.UnstakeRequestDelayExceedsMaximum.selector);
    MockStakingManager(
      payable(UnsafeUpgrades.deployUUPSProxy(
          address(stakingManagerImplementation),
          abi.encodeCall(
            StakingManager.initialize,
            (IStakingManager.StakingManagerInitializationParams({
                arbitrumGeoToken: arbitrumGeoToken,
                council: council,
                stakingRegistry: stakingRegistry,
                stakedGEOToken: stakedGEOToken,
                minAmount: minAmount,
                unstakeRequestDelay: 30 days + 1
              }))
          )
        ))
    );
  }

  // -------- setMinAmount --------
  function test_SetMinAmount_WhenCalledByOwner(uint256 _newMin) external {
    _newMin = bound(_newMin, 1, _MAX_STAKE_AMOUNT);
    vm.assume(_newMin != minAmount);

    // it emits MinAmountSet
    vm.expectEmit();
    emit IStakingManager.MinAmountSet(_newMin);
    vm.prank(council);
    stakingManagerProxy.setMinAmount(_newMin);

    // it sets the new minimum amount
    assertEq(stakingManagerProxy.minAmount(), _newMin);
  }

  function test_SetMinAmount_WhenMinAmountIsZero() external {
    // when min amount is zero
    // it reverts with ZeroAmount
    vm.prank(council);
    vm.expectRevert(IStakingManager.ZeroAmount.selector);
    stakingManagerProxy.setMinAmount(0);
  }

  function test_SetMinAmount_WhenCalledByNon_owner(address _caller, uint256 _newMin) external {
    vm.assume(_caller != council);

    // it reverts with OwnableUnauthorizedAccount
    vm.prank(_caller);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
    stakingManagerProxy.setMinAmount(_newMin);
  }

  // -------- setUnstakeRequestDelay --------
  function test_SetUnstakeRequestDelay_WhenCalledByOwner(uint256 _newDelay) external {
    _newDelay = bound(_newDelay, 0, stakingManagerProxy.MAX_UNSTAKE_REQUEST_DELAY());
    vm.assume(_newDelay != unstakeDelay);

    // it emits UnstakeRequestDelaySet
    vm.expectEmit();
    emit IStakingManager.UnstakeRequestDelaySet(_newDelay);
    vm.prank(council);
    stakingManagerProxy.setUnstakeRequestDelay(_newDelay);

    // it sets the new delay
    assertEq(stakingManagerProxy.unstakeRequestDelay(), _newDelay);
  }

  function test_SetUnstakeRequestDelay_WhenDelayExceedsMaximum() external {
    // when delay exceeds maximum
    // it reverts with UnstakeRequestDelayExceedsMaximum
    uint256 _tooLarge = stakingManagerProxy.MAX_UNSTAKE_REQUEST_DELAY() + 1;
    vm.prank(council);
    vm.expectRevert(IStakingManager.UnstakeRequestDelayExceedsMaximum.selector);
    stakingManagerProxy.setUnstakeRequestDelay(_tooLarge);
  }

  function test_SetUnstakeRequestDelay_WhenCalledByNon_owner(address _caller, uint256 _newDelay) external {
    vm.assume(_caller != council);

    // it reverts with OwnableUnauthorizedAccount
    vm.prank(_caller);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
    stakingManagerProxy.setUnstakeRequestDelay(_newDelay);
  }

  // -------- totalUserDisposableStake --------
  function test_TotalUserDisposableStake_WhenCalled(
    address _user,
    uint256 _totalUserStake,
    uint256 _totalUserPendingUnstake,
    uint256 _totalUserAllocation
  ) external {
    _assumeFuzzable(_user);
    _totalUserStake = bound(_totalUserStake, minAmount, _MAX_STAKE_AMOUNT);
    _totalUserPendingUnstake = bound(_totalUserPendingUnstake, 0, _totalUserStake);
    uint256 _maxAlloc = _totalUserStake - _totalUserPendingUnstake;
    _totalUserAllocation = bound(_totalUserAllocation, 0, _maxAlloc);

    stakingManagerProxy.workaround_seedStakeOnly(
      _user, _totalUserStake, _totalUserStake, _totalUserPendingUnstake, _totalUserAllocation
    );

    // it returns stake minus pending unstake minus allocation
    assertEq(
      stakingManagerProxy.totalUserDisposableStake(_user),
      _totalUserStake - _totalUserPendingUnstake - _totalUserAllocation
    );
  }

  // -------- stake --------
  function test_Stake_WhenAmountIsBelowMinimum(uint256 _amount) external {
    _amount = bound(_amount, 1, minAmount - 1);

    // it reverts with AmountBelowMinimum
    vm.prank(alice);
    vm.expectRevert(IStakingManager.AmountBelowMinimum.selector);
    stakingManagerProxy.stake(_amount);
  }

  function test_Stake_WhenAmountIsAtLeastMinimum(uint256 _amount) external {
    _amount = bound(_amount, minAmount, _MAX_STAKE_AMOUNT);

    vm.clearMockedCalls();
    // it transfers GEO from the user to the staking manager
    _mockAndExpect(
      arbitrumGeoToken,
      abi.encodeCall(IERC20.transferFrom, (alice, address(stakingManagerProxy), _amount)),
      abi.encode(true)
    );
    // it mints staked GEO to the user
    _mockAndExpect(stakedGEOToken, abi.encodeCall(IStakedGEOToken.mint, (alice, _amount)), abi.encode());

    // it emits Staked
    vm.expectEmit();
    emit IStakingManager.Staked(alice, alice, _amount);
    vm.prank(alice);
    stakingManagerProxy.stake(_amount);

    // it updates total user stake for the user
    assertEq(stakingManagerProxy.totalUserStake(alice), _amount);
    // it updates total staked
    assertEq(stakingManagerProxy.totalStaked(), _amount);
  }

  // -------- stakeFor --------
  function test_StakeFor_WhenRecipientIsZeroAddress(uint256 _amount) external {
    // it reverts with InvalidAddress
    vm.prank(distributor);
    vm.expectRevert(IStakingManager.InvalidAddress.selector);
    stakingManagerProxy.stakeFor(address(0), _amount);
  }

  function test_StakeFor_WhenAmountIsBelowMinimum(uint256 _amount) external {
    _amount = bound(_amount, 1, minAmount - 1);

    // it reverts with AmountBelowMinimum
    vm.prank(distributor);
    vm.expectRevert(IStakingManager.AmountBelowMinimum.selector);
    stakingManagerProxy.stakeFor(alice, _amount);
  }

  function test_StakeFor_WhenAmountIsAtLeastMinimum(uint256 _amount) external {
    _amount = bound(_amount, minAmount, _MAX_STAKE_AMOUNT);

    vm.clearMockedCalls();
    _mockAndExpect(
      arbitrumGeoToken,
      abi.encodeCall(IERC20.transferFrom, (distributor, address(stakingManagerProxy), _amount)),
      abi.encode(true)
    );
    _mockAndExpect(stakedGEOToken, abi.encodeCall(IStakedGEOToken.mint, (alice, _amount)), abi.encode());

    // it emits Staked
    vm.expectEmit();
    emit IStakingManager.Staked(distributor, alice, _amount);
    vm.prank(distributor);
    stakingManagerProxy.stakeFor(alice, _amount);

    // it updates total user stake for the recipient
    assertEq(stakingManagerProxy.totalUserStake(alice), _amount);
    // it updates total staked
    assertEq(stakingManagerProxy.totalStaked(), _amount);
  }

  // -------- requestUnstake --------
  function test_RequestUnstake_WhenAmountIsZero() external {
    vm.prank(alice);
    vm.expectRevert(IStakingManager.ZeroAmount.selector);
    stakingManagerProxy.requestUnstake(0);
  }

  function test_RequestUnstake_WhenAmountExceedsDisposableStake(uint256 _stakeAmount) external {
    _stakeAmount = bound(_stakeAmount, minAmount, _MAX_STAKE_AMOUNT);

    stakingManagerProxy.workaround_seedStakeOnly(alice, _stakeAmount, _stakeAmount, 0, 0);

    vm.prank(alice);
    vm.expectRevert(IStakingManager.InsufficientDisposableStake.selector);
    stakingManagerProxy.requestUnstake(_stakeAmount + 1);
  }

  function test_RequestUnstake_WhenAmountIsBelowMinimumAndNotAFullDisposableExit(
    uint256 _stakeAmount,
    uint256 _belowMin
  ) external {
    _stakeAmount = bound(_stakeAmount, 2 * minAmount, _MAX_STAKE_AMOUNT);
    _belowMin = bound(_belowMin, 1, minAmount - 1);

    stakingManagerProxy.workaround_seedStakeOnly(alice, _stakeAmount, _stakeAmount, 0, 0);

    vm.prank(alice);
    vm.expectRevert(IStakingManager.AmountBelowMinimum.selector);
    stakingManagerProxy.requestUnstake(_belowMin);
  }

  function test_RequestUnstake_WhenDisposableStakeRemainderIsNon_zeroAndBelowMinimum(uint256 _delta) external {
    _delta = bound(_delta, 1, minAmount - 1);
    uint256 _disposableStake = 2 * minAmount + _delta;

    stakingManagerProxy.workaround_seedStakeOnly(alice, _disposableStake, _disposableStake, 0, 0);

    vm.prank(alice);
    vm.expectRevert(IStakingManager.DisposableStakeRemainderBelowMinimum.selector);
    stakingManagerProxy.requestUnstake(2 * minAmount);
  }

  function test_RequestUnstake_WhenAmountIsValid(uint256 _stakeAmount, uint256 _requestAmount) external {
    _stakeAmount = bound(_stakeAmount, minAmount, _MAX_STAKE_AMOUNT);
    _requestAmount = bound(_requestAmount, minAmount, _stakeAmount);
    uint256 _remainderDisposable = _stakeAmount - _requestAmount;
    vm.assume(_remainderDisposable == 0 || _remainderDisposable >= minAmount);

    stakingManagerProxy.workaround_seedStakeOnly(alice, _stakeAmount, _stakeAmount, 0, 0);

    uint256 _nonceBefore = stakingManagerProxy.unstakeRequestNonce();

    // it emits UnstakeRequested
    vm.expectEmit();
    emit IStakingManager.UnstakeRequested(_nonceBefore, alice, _requestAmount, block.timestamp + unstakeDelay);
    vm.prank(alice);
    uint256 _unstakeId = stakingManagerProxy.requestUnstake(_requestAmount);

    assertEq(_unstakeId, _nonceBefore);

    // it preserves total user stake for the user
    assertEq(stakingManagerProxy.totalUserStake(alice), _stakeAmount);
    // it preserves total staked
    assertEq(stakingManagerProxy.totalStaked(), _stakeAmount);
    // it records the amount in total user pending unstake for the user
    assertEq(stakingManagerProxy.totalUserPendingUnstake(alice), _requestAmount);
    // it records the amount in total pending unstake
    assertEq(stakingManagerProxy.totalPendingUnstake(), _requestAmount);
    // it increments the unstake request nonce
    assertEq(stakingManagerProxy.unstakeRequestNonce(), _nonceBefore + 1);
  }

  // -------- unstake --------
  function test_Unstake_WhenRequestIsMissing(uint256 _unstakeId) external {
    vm.prank(alice);
    vm.expectRevert(IStakingManager.UnstakeRequestNotFound.selector);
    stakingManagerProxy.unstake(_unstakeId);
  }

  function test_Unstake_WhenCallerIsNotTheRequester(
    uint256 _stakeAmount,
    uint256 _requestAmount,
    address _bob
  ) external {
    _assumeFuzzable(_bob);
    vm.assume(_bob != alice);

    _stakeAmount = bound(_stakeAmount, minAmount, _MAX_STAKE_AMOUNT);
    _requestAmount = bound(_requestAmount, minAmount, _stakeAmount);

    uint256 _unstakeId = 0;
    stakingManagerProxy.workaround_seedUnstakeRequest(_unstakeId, alice, _requestAmount, 0, 0, 0, 0, 0);

    vm.prank(_bob);
    vm.expectRevert(IStakingManager.UnstakeRequestUnauthorized.selector);
    stakingManagerProxy.unstake(_unstakeId);
  }

  function test_Unstake_WhenDelayHasNotElapsed(uint256 _stakeAmount, uint256 _requestAmount) external {
    _stakeAmount = bound(_stakeAmount, minAmount, _MAX_STAKE_AMOUNT);
    _requestAmount = bound(_requestAmount, minAmount, _stakeAmount);

    uint256 _unstakeId = 0;
    stakingManagerProxy.workaround_seedUnstakeRequest(
      _unstakeId, alice, _requestAmount, block.timestamp + unstakeDelay, 0, 0, 0, 0
    );

    vm.prank(alice);
    vm.expectRevert(IStakingManager.UnstakeRequestLocked.selector);
    stakingManagerProxy.unstake(_unstakeId);
  }

  function test_Unstake_WhenDelayHasElapsedAndCallerIsTheRequester(
    uint256 _stakeAmount,
    uint256 _requestAmount
  ) external {
    _stakeAmount = bound(_stakeAmount, minAmount, _MAX_STAKE_AMOUNT);
    _requestAmount = bound(_requestAmount, minAmount, _stakeAmount);

    uint256 _unstakeId = 0;
    stakingManagerProxy.workaround_seedUnstakeRequest(
      _unstakeId,
      alice,
      _requestAmount,
      block.timestamp + unstakeDelay,
      _stakeAmount,
      _stakeAmount,
      _requestAmount,
      _requestAmount
    );

    vm.warp(block.timestamp + unstakeDelay);

    vm.clearMockedCalls();
    _mockAndExpect(stakedGEOToken, abi.encodeCall(IStakedGEOToken.burn, (alice, _requestAmount)), abi.encode());
    // it transfers unstaked GEO to the user
    _mockAndExpect(arbitrumGeoToken, abi.encodeCall(IERC20.transfer, (alice, _requestAmount)), abi.encode(true));

    // it emits Unstaked
    vm.expectEmit();
    emit IStakingManager.Unstaked(_unstakeId);
    vm.prank(alice);
    stakingManagerProxy.unstake(_unstakeId);

    // it reduces total user stake for the user by the unstaked amount
    assertEq(stakingManagerProxy.totalUserStake(alice), _stakeAmount - _requestAmount);
    // it reduces total staked by the unstaked amount
    assertEq(stakingManagerProxy.totalStaked(), _stakeAmount - _requestAmount);
    // it clears total user pending unstake for the user
    assertEq(stakingManagerProxy.totalUserPendingUnstake(alice), 0);
    // it clears total pending unstake
    assertEq(stakingManagerProxy.totalPendingUnstake(), 0);
    // it clears the unstake request record for the unstake id
    assertEq(stakingManagerProxy.unstakeRequests(_unstakeId).user, address(0));
  }

  // -------- allocate --------
  function test_Allocate_WhenAmountExceedsDisposableStake(uint256 _stakeAmount, uint256 _firstAlloc) external {
    _stakeAmount = bound(_stakeAmount, 10 * minAmount, _MAX_STAKE_AMOUNT);
    _firstAlloc = bound(_firstAlloc, minAmount, _stakeAmount - 2 * minAmount);
    uint256 _secondAlloc = _stakeAmount - _firstAlloc + 1;

    stakingManagerProxy.workaround_seedStakeOnly(alice, _stakeAmount, _stakeAmount, 0, 0);
    stakingManagerProxy.workaround_seedSingleTargetAllocation(alice, targetA, _firstAlloc);

    vm.prank(alice);
    vm.expectRevert(IStakingManager.InsufficientDisposableStake.selector);
    stakingManagerProxy.allocate(targetB, _secondAlloc);
  }

  function test_Allocate_WhenAmountIsBelowMinimum(uint256 _stakeAmount, uint256 _disposableAfter) external {
    _stakeAmount = bound(_stakeAmount, 5 * minAmount, _MAX_STAKE_AMOUNT);
    _disposableAfter = bound(_disposableAfter, minAmount, 2 * minAmount - 2);
    uint256 _firstAlloc = _stakeAmount - _disposableAfter;
    vm.assume(_firstAlloc >= minAmount);

    stakingManagerProxy.workaround_seedStakeOnly(alice, _stakeAmount, _stakeAmount, 0, 0);
    stakingManagerProxy.workaround_seedSingleTargetAllocation(alice, targetA, _firstAlloc);

    vm.prank(alice);
    vm.expectRevert(IStakingManager.AmountBelowMinimum.selector);
    stakingManagerProxy.allocate(targetB, minAmount - 1);
  }

  function test_Allocate_WhenTargetIsInactiveInRegistry(uint256 _stakeAmount, uint256 _allocAmount) external {
    // when target is inactive in registry
    _stakeAmount = bound(_stakeAmount, minAmount, _MAX_STAKE_AMOUNT);
    _allocAmount = bound(_allocAmount, minAmount, _stakeAmount);

    vm.clearMockedCalls();
    _mockAndExpectTarget(targetInactive, false);
    stakingManagerProxy.workaround_seedStakeOnly(alice, _stakeAmount, _stakeAmount, 0, 0);

    // it reverts with InactiveAllocationTarget
    vm.prank(alice);
    vm.expectRevert(IStakingManager.InactiveAllocationTarget.selector);
    stakingManagerProxy.allocate(targetInactive, _allocAmount);
  }

  function test_Allocate_WhenAmountIsValid(uint256 _stakeAmount, uint256 _allocAmount) external {
    _stakeAmount = bound(_stakeAmount, minAmount, _MAX_STAKE_AMOUNT);
    _allocAmount = bound(_allocAmount, minAmount, _stakeAmount);

    vm.clearMockedCalls();
    _mockAndExpectTarget(targetA, true);
    stakingManagerProxy.workaround_seedStakeOnly(alice, _stakeAmount, _stakeAmount, 0, 0);

    // it emits Allocated
    vm.expectEmit();
    emit IStakingManager.Allocated(alice, targetA, _allocAmount);
    vm.prank(alice);
    stakingManagerProxy.allocate(targetA, _allocAmount);

    // it records allocation for the user and target
    assertEq(stakingManagerProxy.allocations(alice, targetA), _allocAmount);
    // it records total user allocation for the user
    assertEq(stakingManagerProxy.totalUserAllocation(alice), _allocAmount);
    // it records total target allocation for the target
    assertEq(stakingManagerProxy.totalTargetAllocation(targetA), _allocAmount);
    // it records total allocated across targets
    assertEq(stakingManagerProxy.totalAllocated(), _allocAmount);
  }

  // -------- deallocate --------
  function test_Deallocate_WhenAmountExceedsAllocation(
    uint256 _stakeAmount,
    uint256 _allocAmount,
    uint256 _excess
  ) external {
    _stakeAmount = bound(_stakeAmount, minAmount, _MAX_STAKE_AMOUNT);
    _allocAmount = bound(_allocAmount, minAmount, _stakeAmount);
    _excess = bound(_excess, 1, type(uint256).max - _allocAmount);
    stakingManagerProxy.workaround_seedStakeOnly(alice, _stakeAmount, _stakeAmount, 0, 0);
    stakingManagerProxy.workaround_seedSingleTargetAllocation(alice, targetA, _allocAmount);

    vm.prank(alice);
    vm.expectRevert(IStakingManager.InsufficientAllocation.selector);
    stakingManagerProxy.deallocate(targetA, _allocAmount + _excess);
  }

  function test_Deallocate_WhenAmountIsZero(uint256 _stakeAmount) external {
    // when amount is zero
    _stakeAmount = bound(_stakeAmount, minAmount, _MAX_STAKE_AMOUNT);
    stakingManagerProxy.workaround_seedStakeOnly(alice, _stakeAmount, _stakeAmount, 0, 0);

    vm.prank(alice);
    vm.expectRevert(IStakingManager.ZeroAmount.selector);
    stakingManagerProxy.deallocate(targetA, 0);
  }

  function test_Deallocate_WhenAmountIsBelowMinimumAndNotAFullTargetExit(
    uint256 _stakeAmount,
    uint256 _allocAmount
  ) external {
    _stakeAmount = bound(_stakeAmount, 3 * minAmount, _MAX_STAKE_AMOUNT);
    _allocAmount = bound(_allocAmount, 2 * minAmount, _stakeAmount);
    stakingManagerProxy.workaround_seedStakeOnly(alice, _stakeAmount, _stakeAmount, 0, 0);
    stakingManagerProxy.workaround_seedSingleTargetAllocation(alice, targetA, _allocAmount);

    vm.prank(alice);
    vm.expectRevert(IStakingManager.AmountBelowMinimum.selector);
    stakingManagerProxy.deallocate(targetA, minAmount - 1);
  }

  function test_Deallocate_WhenAllocationRemainderIsNon_zeroAndBelowMinimum(
    uint256 _stakeAmount,
    uint256 _delta
  ) external {
    _stakeAmount = bound(_stakeAmount, 4 * minAmount, _MAX_STAKE_AMOUNT);
    _delta = bound(_delta, 1, minAmount - 1);
    uint256 _allocOnTarget = minAmount + _delta;
    vm.assume(_allocOnTarget <= _stakeAmount);

    stakingManagerProxy.workaround_seedStakeOnly(alice, _stakeAmount, _stakeAmount, 0, 0);
    stakingManagerProxy.workaround_seedSingleTargetAllocation(alice, targetA, _allocOnTarget);

    vm.prank(alice);
    vm.expectRevert(IStakingManager.AllocationRemainderBelowMinimum.selector);
    stakingManagerProxy.deallocate(targetA, minAmount);
  }

  function test_Deallocate_WhenAmountIsValid(
    uint256 _stakeAmount,
    uint256 _allocAmount,
    uint256 _deallocAmount
  ) external {
    _stakeAmount = bound(_stakeAmount, minAmount, _MAX_STAKE_AMOUNT);
    _allocAmount = bound(_allocAmount, 1, _stakeAmount);
    _deallocAmount = bound(_deallocAmount, 1, _allocAmount);
    vm.assume(_deallocAmount == _allocAmount || _deallocAmount >= minAmount);
    uint256 _remainderOnTarget = _allocAmount - _deallocAmount;
    vm.assume(_remainderOnTarget == 0 || _remainderOnTarget >= minAmount);

    stakingManagerProxy.workaround_seedStakeOnly(alice, _stakeAmount, _stakeAmount, 0, 0);
    stakingManagerProxy.workaround_seedSingleTargetAllocation(alice, targetA, _allocAmount);

    // it emits Deallocated
    vm.expectEmit();
    emit IStakingManager.Deallocated(alice, targetA, _deallocAmount);
    vm.prank(alice);
    stakingManagerProxy.deallocate(targetA, _deallocAmount);

    // it updates allocation for the user and target
    assertEq(stakingManagerProxy.allocations(alice, targetA), _allocAmount - _deallocAmount);
    // it updates total user allocation for the user
    assertEq(stakingManagerProxy.totalUserAllocation(alice), _allocAmount - _deallocAmount);
    // it updates total target allocation for the target
    assertEq(stakingManagerProxy.totalTargetAllocation(targetA), _allocAmount - _deallocAmount);
    // it updates total allocated across targets
    assertEq(stakingManagerProxy.totalAllocated(), _allocAmount - _deallocAmount);
  }

  // -------- reallocate --------
  function test_Reallocate_WhenSourceEqualsDestination(uint256 _stakeAmount, uint256 _allocAmount) external {
    _stakeAmount = bound(_stakeAmount, minAmount, _MAX_STAKE_AMOUNT);
    _allocAmount = bound(_allocAmount, minAmount, _stakeAmount);
    stakingManagerProxy.workaround_seedStakeOnly(alice, _stakeAmount, _stakeAmount, 0, 0);
    stakingManagerProxy.workaround_seedSingleTargetAllocation(alice, targetA, _allocAmount);

    vm.prank(alice);
    vm.expectRevert(IStakingManager.SameReallocationTargets.selector);
    stakingManagerProxy.reallocate(targetA, targetA, _allocAmount);
  }

  function test_Reallocate_WhenAmountExceedsSourceAllocation(
    uint256 _stakeAmount,
    uint256 _allocAmount,
    uint256 _excess
  ) external {
    _stakeAmount = bound(_stakeAmount, minAmount, _MAX_STAKE_AMOUNT);
    _allocAmount = bound(_allocAmount, minAmount, _stakeAmount);
    _excess = bound(_excess, 1, type(uint256).max - _allocAmount);
    stakingManagerProxy.workaround_seedStakeOnly(alice, _stakeAmount, _stakeAmount, 0, 0);
    stakingManagerProxy.workaround_seedSingleTargetAllocation(alice, targetA, _allocAmount);

    vm.prank(alice);
    vm.expectRevert(IStakingManager.InsufficientAllocation.selector);
    stakingManagerProxy.reallocate(targetA, targetB, _allocAmount + _excess);
  }

  function test_Reallocate_WhenAmountIsBelowMinimum(uint256 _stakeAmount, uint256 _allocAmount) external {
    _stakeAmount = bound(_stakeAmount, 3 * minAmount, _MAX_STAKE_AMOUNT);
    _allocAmount = bound(_allocAmount, 2 * minAmount, _stakeAmount);
    stakingManagerProxy.workaround_seedStakeOnly(alice, _stakeAmount, _stakeAmount, 0, 0);
    stakingManagerProxy.workaround_seedSingleTargetAllocation(alice, targetA, _allocAmount);

    vm.prank(alice);
    vm.expectRevert(IStakingManager.AmountBelowMinimum.selector);
    stakingManagerProxy.reallocate(targetA, targetB, minAmount - 1);
  }

  function test_Reallocate_WhenSourceAllocationRemainderIsNon_zeroAndBelowMinimum(
    uint256 _stakeAmount,
    uint256 _delta
  ) external {
    _stakeAmount = bound(_stakeAmount, 4 * minAmount, _MAX_STAKE_AMOUNT);
    _delta = bound(_delta, 1, minAmount - 1);
    uint256 _allocOnSource = minAmount + _delta;
    vm.assume(_allocOnSource <= _stakeAmount);

    stakingManagerProxy.workaround_seedStakeOnly(alice, _stakeAmount, _stakeAmount, 0, 0);
    stakingManagerProxy.workaround_seedSingleTargetAllocation(alice, targetA, _allocOnSource);

    vm.prank(alice);
    vm.expectRevert(IStakingManager.AllocationRemainderBelowMinimum.selector);
    stakingManagerProxy.reallocate(targetA, targetB, minAmount);
  }

  function test_Reallocate_WhenDestinationTargetIsInactiveInRegistry(
    uint256 _stakeAmount,
    uint256 _allocAmount,
    uint256 _moveAmount
  ) external {
    // when destination target is inactive in registry
    _stakeAmount = bound(_stakeAmount, minAmount, _MAX_STAKE_AMOUNT);
    _allocAmount = bound(_allocAmount, minAmount, _stakeAmount);
    _moveAmount = bound(_moveAmount, 1, _allocAmount);
    vm.assume(_moveAmount >= minAmount);
    uint256 _remainderOnSource = _allocAmount - _moveAmount;
    vm.assume(_remainderOnSource == 0 || _remainderOnSource >= minAmount);
    vm.clearMockedCalls();
    _mockAndExpectTarget(targetInactive, false);
    stakingManagerProxy.workaround_seedStakeOnly(alice, _stakeAmount, _stakeAmount, 0, 0);
    stakingManagerProxy.workaround_seedSingleTargetAllocation(alice, targetA, _allocAmount);

    // it reverts with InactiveAllocationTarget
    vm.prank(alice);
    vm.expectRevert(IStakingManager.InactiveAllocationTarget.selector);
    stakingManagerProxy.reallocate(targetA, targetInactive, _moveAmount);
  }

  function test_Reallocate_WhenAmountIsValid(uint256 _stakeAmount, uint256 _allocAmount, uint256 _moveAmount) external {
    _stakeAmount = bound(_stakeAmount, minAmount, _MAX_STAKE_AMOUNT);
    _allocAmount = bound(_allocAmount, minAmount, _stakeAmount);
    _moveAmount = bound(_moveAmount, 1, _allocAmount);
    vm.assume(_moveAmount >= minAmount);
    uint256 _remainderOnSource = _allocAmount - _moveAmount;
    vm.assume(_remainderOnSource == 0 || _remainderOnSource >= minAmount);
    vm.clearMockedCalls();
    _mockAndExpectTarget(targetB, true);
    stakingManagerProxy.workaround_seedStakeOnly(alice, _stakeAmount, _stakeAmount, 0, 0);
    stakingManagerProxy.workaround_seedSingleTargetAllocation(alice, targetA, _allocAmount);

    // it emits Reallocated
    vm.expectEmit();
    emit IStakingManager.Reallocated(alice, targetA, targetB, _moveAmount);
    vm.prank(alice);
    stakingManagerProxy.reallocate(targetA, targetB, _moveAmount);

    // it updates allocation for the user on the source target
    assertEq(stakingManagerProxy.allocations(alice, targetA), _allocAmount - _moveAmount);
    // it updates allocation for the user on the destination target
    assertEq(stakingManagerProxy.allocations(alice, targetB), _moveAmount);
    // it updates total target allocation for the source target
    assertEq(stakingManagerProxy.totalTargetAllocation(targetA), _allocAmount - _moveAmount);
    // it updates total target allocation for the destination target
    assertEq(stakingManagerProxy.totalTargetAllocation(targetB), _moveAmount);
    // it preserves total allocated across targets
    assertEq(stakingManagerProxy.totalAllocated(), _allocAmount);
  }

  // -------- typeId --------
  function test_TypeId_WhenCalled() external view {
    // when called

    // it returns the type
    assertEq(stakingManagerProxy.typeId(), keccak256('STAKING_MANAGER'));
  }

  // -------- name --------
  function test_Name_WhenCalled() external view {
    // when called

    // it returns the name
    assertEq(stakingManagerProxy.name(), 'STAKING_MANAGER');
  }

  // -------- version --------
  function test_Version_WhenCalled() external view {
    // when called

    // it returns semantic version
    assertEq(stakingManagerProxy.version(), '1.0.0');
  }

  // -------- _authorizeUpgrade --------
  function test__authorizeUpgrade_WhenCalledByOwner() external {
    address newImplementation = address(new StakingManager());
    vm.prank(council);

    // it authorizes the upgrade
    stakingManagerProxy.upgradeToAndCall(newImplementation, '');
  }

  function test__authorizeUpgrade_WhenCalledByNon_owner(address _caller) external {
    vm.assume(_caller != council);
    address newImplementation = address(new StakingManager());
    vm.prank(_caller);

    // it reverts with OwnableUnauthorizedAccount
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
    stakingManagerProxy.upgradeToAndCall(newImplementation, '');
  }

  /**
   * @notice Mocks `IStakingRegistry.targets(_targetId)` on the `stakingRegistry` mock address and registers an
   * `expectCall` so the test asserts the StakingManager queried the registry for that target
   */
  function _mockAndExpectTarget(bytes32 _targetId, bool _tActive) internal {
    _mockAndExpect(
      stakingRegistry,
      abi.encodeCall(IStakingRegistry.targets, (_targetId)),
      abi.encode(IStakingRegistry.Target({tType: IStakingRegistry.TargetType.Space, tActive: _tActive}))
    );
  }
}
