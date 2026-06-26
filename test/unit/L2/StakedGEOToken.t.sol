// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

import {UnsafeUpgrades} from '@openzeppelin/foundry-upgrades/Upgrades.sol';
import {StakedGEOToken} from 'contracts/L2/StakedGEOToken.sol';
import {IStakedGEOToken} from 'interfaces/L2/IStakedGEOToken.sol';
import {MockStakedGEOToken} from 'test/unit/L2/mocks/MockStakedGEOToken.sol';
import {TestHelper} from 'unit-helpers/TestHelper.sol';

contract UnitStakedGEOToken is TestHelper {
  uint256 internal constant _MAX_BALANCE_AMOUNT = type(uint208).max;
  uint256 internal constant _TIME_STEP = 5 days;
  uint256 internal constant _STAKE_TIME_OFFSET = _TIME_STEP * 2;

  uint32 internal constant _FIRST_CHECKPOINT_INDEX = 0;
  uint32 internal constant _SECOND_CHECKPOINT_INDEX = 1;
  uint32 internal constant _THIRD_CHECKPOINT_INDEX = 2;

  address public council = makeAddr('council');
  address public stakingManagerAddr = makeAddr('stakingManager');
  address public alice = makeAddr('alice');
  address public bob = makeAddr('bob');

  MockStakedGEOToken public stakedGEOTokenImplementation;
  MockStakedGEOToken public stakedGEOTokenProxy;

  function setUp() external {
    stakedGEOTokenImplementation = new MockStakedGEOToken();
    stakedGEOTokenProxy = MockStakedGEOToken(
      payable(UnsafeUpgrades.deployUUPSProxy(
          address(stakedGEOTokenImplementation),
          abi.encodeCall(
            StakedGEOToken.initialize,
            (IStakedGEOToken.StakedGEOTokenInitializationParams({council: council, stakingManager: stakingManagerAddr}))
          )
        ))
    );
  }

  // -------- constants --------
  function test_Constants_WhenDeployed() external view {
    assertEq(
      stakedGEOTokenImplementation.exposed__STAKED_GEO_TOKEN_STORAGE_LOCATION(),
      keccak256(abi.encode(uint256(keccak256('geo.storage.StakedGEOToken')) - 1)) & ~bytes32(uint256(0xff))
    );
  }

  // -------- constructor --------
  function test_Constructor_WhenCalled() external {
    StakedGEOToken newImplementation = new StakedGEOToken();
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    newImplementation.initialize(
      IStakedGEOToken.StakedGEOTokenInitializationParams({council: council, stakingManager: stakingManagerAddr})
    );
  }

  // -------- initialize --------
  function test_Initialize_WhenPassingValidParameters() external {
    stakedGEOTokenImplementation = new MockStakedGEOToken();
    MockStakedGEOToken freshStakedGEOToken = MockStakedGEOToken(
      payable(UnsafeUpgrades.deployUUPSProxy(
          address(stakedGEOTokenImplementation),
          abi.encodeCall(
            StakedGEOToken.initialize,
            (IStakedGEOToken.StakedGEOTokenInitializationParams({council: council, stakingManager: stakingManagerAddr}))
          )
        ))
    );

    assertEq(freshStakedGEOToken.owner(), council);
    assertEq(freshStakedGEOToken.stakingManager(), stakingManagerAddr);
    assertEq(freshStakedGEOToken.name(), 'Staked GEO Token');
    assertEq(freshStakedGEOToken.symbol(), 'stkGEO');
  }

  function test_Initialize_WhenCalledTwice() external {
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    stakedGEOTokenProxy.initialize(
      IStakedGEOToken.StakedGEOTokenInitializationParams({council: council, stakingManager: stakingManagerAddr})
    );
  }

  function test_Initialize_WhenStakingManagerIsZero() external {
    stakedGEOTokenImplementation = new MockStakedGEOToken();
    vm.expectRevert(IStakedGEOToken.InvalidAddress.selector);
    UnsafeUpgrades.deployUUPSProxy(
      address(stakedGEOTokenImplementation),
      abi.encodeCall(
        StakedGEOToken.initialize,
        (IStakedGEOToken.StakedGEOTokenInitializationParams({council: council, stakingManager: address(0)}))
      )
    );
  }

  function test_Initialize_WhenCouncilIsZero() external {
    stakedGEOTokenImplementation = new MockStakedGEOToken();
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
    UnsafeUpgrades.deployUUPSProxy(
      address(stakedGEOTokenImplementation),
      abi.encodeCall(
        StakedGEOToken.initialize,
        (IStakedGEOToken.StakedGEOTokenInitializationParams({council: address(0), stakingManager: stakingManagerAddr}))
      )
    );
  }

  // -------- clock --------
  function test_Clock_WhenCalled(uint256 _timestamp) external {
    _timestamp = bound(_timestamp, 1, type(uint48).max);
    vm.warp(_timestamp);
    assertEq(stakedGEOTokenProxy.clock(), _timestamp);
  }

  // -------- CLOCK_MODE --------
  function test_CLOCK_MODE_WhenCalled() external view {
    assertEq(stakedGEOTokenProxy.CLOCK_MODE(), 'mode=timestamp');
  }

  // -------- mint --------
  function test_Mint_WhenCalledByStakingManager(uint256 _amount) external {
    _amount = bound(_amount, 1, _MAX_BALANCE_AMOUNT);

    vm.prank(stakingManagerAddr);
    stakedGEOTokenProxy.mint(alice, _amount);

    assertEq(stakedGEOTokenProxy.balanceOf(alice), _amount);
    assertEq(stakedGEOTokenProxy.getVotes(alice), _amount);
  }

  function test_Mint_WhenAmountIsZero() external {
    vm.prank(stakingManagerAddr);
    vm.expectRevert(IStakedGEOToken.ZeroAmount.selector);
    stakedGEOTokenProxy.mint(alice, 0);
  }

  function test_Mint_WhenCallerIsNotStakingManager(address _caller, uint256 _amount) external {
    _assumeFuzzable(_caller);
    vm.assume(_caller != stakingManagerAddr);
    _amount = bound(_amount, 1, _MAX_BALANCE_AMOUNT);

    vm.prank(_caller);
    vm.expectRevert(IStakedGEOToken.OnlyStakingManager.selector);
    stakedGEOTokenProxy.mint(alice, _amount);
  }

  // -------- burn --------
  function test_Burn_WhenCalledByStakingManager(uint256 _balanceAmount, uint256 _burnAmount) external {
    _balanceAmount = bound(_balanceAmount, 1, _MAX_BALANCE_AMOUNT);
    _burnAmount = bound(_burnAmount, 1, _balanceAmount);

    stakedGEOTokenProxy.workaround_mintBalance(alice, _balanceAmount);

    vm.prank(stakingManagerAddr);
    stakedGEOTokenProxy.burn(alice, _burnAmount);

    assertEq(stakedGEOTokenProxy.balanceOf(alice), _balanceAmount - _burnAmount);
    assertEq(stakedGEOTokenProxy.getVotes(alice), _balanceAmount - _burnAmount);
  }

  function test_Burn_WhenAmountIsZero() external {
    vm.prank(stakingManagerAddr);
    vm.expectRevert(IStakedGEOToken.ZeroAmount.selector);
    stakedGEOTokenProxy.burn(alice, 0);
  }

  function test_Burn_WhenCallerIsNotStakingManager(address _caller, uint256 _amount) external {
    _assumeFuzzable(_caller);
    vm.assume(_caller != stakingManagerAddr);
    _amount = bound(_amount, 1, _MAX_BALANCE_AMOUNT);

    stakedGEOTokenProxy.workaround_mintBalance(alice, _amount);

    vm.prank(_caller);
    vm.expectRevert(IStakedGEOToken.OnlyStakingManager.selector);
    stakedGEOTokenProxy.burn(alice, _amount);
  }

  // -------- soulbound --------
  function test_Transfer_WhenCalled(uint256 _amount) external {
    _amount = bound(_amount, 1, _MAX_BALANCE_AMOUNT);

    stakedGEOTokenProxy.workaround_mintBalance(alice, _amount);

    vm.prank(alice);
    vm.expectRevert(IStakedGEOToken.SoulboundTransfer.selector);
    stakedGEOTokenProxy.transfer(bob, _amount);
  }

  function test_TransferFrom_WhenCalled(uint256 _amount) external {
    _amount = bound(_amount, 1, _MAX_BALANCE_AMOUNT);

    stakedGEOTokenProxy.workaround_mintBalance(alice, _amount);
    stakedGEOTokenProxy.workaround_seedAllowance(alice, bob, _amount);

    vm.prank(bob);
    vm.expectRevert(IStakedGEOToken.SoulboundTransfer.selector);
    stakedGEOTokenProxy.transferFrom(alice, bob, _amount);
  }

  // -------- delegate --------
  function test_Delegate_WhenCalled(address _delegatee) external {
    _assumeFuzzable(_delegatee);

    vm.prank(alice);
    vm.expectRevert(IStakedGEOToken.DelegationDisabled.selector);
    stakedGEOTokenProxy.delegate(_delegatee);
  }

  function test_DelegateBySig_WhenCalled(
    address _delegatee,
    uint256 _nonce,
    uint256 _expiry,
    uint8 _v,
    bytes32 _r,
    bytes32 _s
  ) external {
    _assumeFuzzable(_delegatee);

    vm.expectRevert(IStakedGEOToken.DelegationDisabled.selector);
    stakedGEOTokenProxy.delegateBySig(_delegatee, _nonce, _expiry, _v, _r, _s);
  }

  // -------- getPastVotes --------
  function test_GetPastVotes_WhenStaked(uint256 _mintAmount) external {
    _mintAmount = bound(_mintAmount, 1, _MAX_BALANCE_AMOUNT);

    uint256 _stakeTimestamp = _STAKE_TIME_OFFSET;
    vm.warp(_stakeTimestamp);

    stakedGEOTokenProxy.workaround_mintBalance(alice, _mintAmount);

    uint256 _queryTimestamp = _stakeTimestamp + _STAKE_TIME_OFFSET;
    vm.warp(_queryTimestamp + 1);
    assertEq(stakedGEOTokenProxy.getPastVotes(alice, _queryTimestamp), _mintAmount);
  }

  function test_GetPastVotes_WhenPartiallyBurned(uint256 _mintAmount, uint256 _burnAmount) external {
    _mintAmount = bound(_mintAmount, 2, _MAX_BALANCE_AMOUNT);
    _burnAmount = bound(_burnAmount, 1, _mintAmount - 1);

    uint256 _stakeTimestamp = _STAKE_TIME_OFFSET;
    vm.warp(_stakeTimestamp);

    stakedGEOTokenProxy.workaround_mintBalance(alice, _mintAmount);

    vm.warp(_stakeTimestamp + _TIME_STEP);
    stakedGEOTokenProxy.workaround_burnBalance(alice, _burnAmount);

    uint256 _queryTimestamp = _stakeTimestamp + _STAKE_TIME_OFFSET;
    vm.warp(_queryTimestamp + 1);
    assertEq(stakedGEOTokenProxy.getPastVotes(alice, _queryTimestamp), _mintAmount - _burnAmount);
  }

  // -------- getStakeEligibleSince --------
  function test_GetStakeEligibleSince_WhenNeverStaked() external {
    vm.warp(_TIME_STEP);

    assertEq(stakedGEOTokenProxy.getStakeEligibleSince(alice), 0);
    assertEq(
      stakedGEOTokenProxy.exposed__findCheckpointAtOrBefore(alice, stakedGEOTokenProxy.clock()), _FIRST_CHECKPOINT_INDEX
    );
  }

  function test_GetStakeEligibleSince_WhenStaked(uint256 _mintAmount) external {
    _mintAmount = bound(_mintAmount, 1, _MAX_BALANCE_AMOUNT);

    uint256 _stakeTimestamp = _STAKE_TIME_OFFSET;
    vm.warp(_stakeTimestamp);

    stakedGEOTokenProxy.workaround_mintBalance(alice, _mintAmount);

    assertEq(stakedGEOTokenProxy.getStakeEligibleSince(alice), _stakeTimestamp);
    assertEq(stakedGEOTokenProxy.exposed__findStakeEligibleSince(alice, stakedGEOTokenProxy.clock()), _stakeTimestamp);
    assertEq(
      stakedGEOTokenProxy.exposed__findCheckpointAtOrBefore(alice, stakedGEOTokenProxy.clock()), _FIRST_CHECKPOINT_INDEX
    );
  }

  function test_GetStakeEligibleSince_WhenPartiallyBurned(uint256 _mintAmount, uint256 _burnAmount) external {
    _mintAmount = bound(_mintAmount, 2, _MAX_BALANCE_AMOUNT);
    _burnAmount = bound(_burnAmount, 1, _mintAmount - 1);

    uint256 _stakeTimestamp = _STAKE_TIME_OFFSET;
    vm.warp(_stakeTimestamp);

    stakedGEOTokenProxy.workaround_mintBalance(alice, _mintAmount);

    vm.warp(_stakeTimestamp + _TIME_STEP);
    stakedGEOTokenProxy.workaround_burnBalance(alice, _burnAmount);

    assertEq(stakedGEOTokenProxy.getStakeEligibleSince(alice), _stakeTimestamp);
    assertEq(stakedGEOTokenProxy.exposed__findStakeEligibleSince(alice, stakedGEOTokenProxy.clock()), _stakeTimestamp);
    assertEq(
      stakedGEOTokenProxy.exposed__findCheckpointAtOrBefore(alice, stakedGEOTokenProxy.clock()),
      _SECOND_CHECKPOINT_INDEX
    );
  }

  function test_GetStakeEligibleSince_WhenFullyBurned(uint256 _mintAmount) external {
    _mintAmount = bound(_mintAmount, 1, _MAX_BALANCE_AMOUNT);

    uint256 _stakeTimestamp = _STAKE_TIME_OFFSET;
    vm.warp(_stakeTimestamp);

    stakedGEOTokenProxy.workaround_mintBalance(alice, _mintAmount);

    vm.warp(_stakeTimestamp + _TIME_STEP);
    stakedGEOTokenProxy.workaround_burnBalance(alice, _mintAmount);

    assertEq(stakedGEOTokenProxy.getStakeEligibleSince(alice), 0);
    assertEq(
      stakedGEOTokenProxy.exposed__findCheckpointAtOrBefore(alice, stakedGEOTokenProxy.clock()),
      _SECOND_CHECKPOINT_INDEX
    );
  }

  function test_GetStakeEligibleSince_WhenRestaked(uint256 _mintAmount) external {
    _mintAmount = bound(_mintAmount, 1, _MAX_BALANCE_AMOUNT);

    uint256 _firstStakeTimestamp = _STAKE_TIME_OFFSET;
    vm.warp(_firstStakeTimestamp);

    stakedGEOTokenProxy.workaround_mintBalance(alice, _mintAmount);

    vm.warp(_firstStakeTimestamp + _TIME_STEP);
    stakedGEOTokenProxy.workaround_burnBalance(alice, _mintAmount);

    uint256 _restakeTimestamp = _firstStakeTimestamp + _STAKE_TIME_OFFSET;
    vm.warp(_restakeTimestamp);
    stakedGEOTokenProxy.workaround_mintBalance(alice, _mintAmount);

    assertEq(stakedGEOTokenProxy.getStakeEligibleSince(alice), _restakeTimestamp);
    assertEq(stakedGEOTokenProxy.exposed__findStakeEligibleSince(alice, stakedGEOTokenProxy.clock()), _restakeTimestamp);
    assertEq(
      stakedGEOTokenProxy.exposed__findCheckpointAtOrBefore(alice, stakedGEOTokenProxy.clock()), _THIRD_CHECKPOINT_INDEX
    );
  }

  function test_GetStakeEligibleSince_WhenToppedUp(uint256 _mintAmount) external {
    _mintAmount = bound(_mintAmount, 1, _MAX_BALANCE_AMOUNT / 2);

    uint256 _firstStakeTimestamp = _STAKE_TIME_OFFSET;
    vm.warp(_firstStakeTimestamp);
    stakedGEOTokenProxy.workaround_mintBalance(alice, _mintAmount);

    uint256 _secondStakeTimestamp = _firstStakeTimestamp + _STAKE_TIME_OFFSET;
    vm.warp(_secondStakeTimestamp);
    stakedGEOTokenProxy.workaround_mintBalance(alice, _mintAmount);

    assertEq(stakedGEOTokenProxy.getStakeEligibleSince(alice), _firstStakeTimestamp);
    assertEq(
      stakedGEOTokenProxy.exposed__findStakeEligibleSince(alice, stakedGEOTokenProxy.clock()), _firstStakeTimestamp
    );
    assertEq(
      stakedGEOTokenProxy.exposed__findCheckpointAtOrBefore(alice, stakedGEOTokenProxy.clock()),
      _SECOND_CHECKPOINT_INDEX
    );
  }

  // -------- getPastStakeEligibleSince --------
  function test_GetPastStakeEligibleSince_WhenNeverStaked(uint256 _queryTimestamp) external {
    vm.warp(_TIME_STEP);
    _queryTimestamp = bound(_queryTimestamp, 1, _TIME_STEP - 1);

    assertEq(stakedGEOTokenProxy.getPastStakeEligibleSince(alice, _queryTimestamp), 0);
    assertEq(stakedGEOTokenProxy.exposed__findCheckpointAtOrBefore(alice, _queryTimestamp), _FIRST_CHECKPOINT_INDEX);
  }

  function test_GetPastStakeEligibleSince_WhenStakedBeforeQueryTimestamp(uint256 _mintAmount) external {
    _mintAmount = bound(_mintAmount, 1, _MAX_BALANCE_AMOUNT);

    uint256 _stakeTimestamp = _STAKE_TIME_OFFSET;
    vm.warp(_stakeTimestamp);

    stakedGEOTokenProxy.workaround_mintBalance(alice, _mintAmount);

    uint256 _queryTimestamp = _stakeTimestamp + _STAKE_TIME_OFFSET;
    vm.warp(_queryTimestamp + 1);
    assertEq(stakedGEOTokenProxy.getPastStakeEligibleSince(alice, _queryTimestamp), _stakeTimestamp);
    assertEq(stakedGEOTokenProxy.exposed__findStakeEligibleSince(alice, _queryTimestamp), _stakeTimestamp);
    assertEq(stakedGEOTokenProxy.exposed__findCheckpointAtOrBefore(alice, _queryTimestamp), _FIRST_CHECKPOINT_INDEX);
  }

  function test_GetPastStakeEligibleSince_WhenStakedAfterQueryTimestamp(uint256 _mintAmount) external {
    _mintAmount = bound(_mintAmount, 1, _MAX_BALANCE_AMOUNT);

    uint256 _stakeTimestamp = _STAKE_TIME_OFFSET;
    vm.warp(_stakeTimestamp);

    stakedGEOTokenProxy.workaround_mintBalance(alice, _mintAmount);

    uint256 _beforeStakeTimestamp = _stakeTimestamp - _TIME_STEP;
    assertEq(stakedGEOTokenProxy.getPastStakeEligibleSince(alice, _beforeStakeTimestamp), 0);
    assertEq(stakedGEOTokenProxy.exposed__findStakeEligibleSince(alice, _beforeStakeTimestamp), 0);
    assertEq(
      stakedGEOTokenProxy.exposed__findCheckpointAtOrBefore(alice, _beforeStakeTimestamp), _FIRST_CHECKPOINT_INDEX
    );
  }

  function test_GetPastStakeEligibleSince_WhenPartiallyBurned(uint256 _mintAmount, uint256 _burnAmount) external {
    _mintAmount = bound(_mintAmount, 2, _MAX_BALANCE_AMOUNT);
    _burnAmount = bound(_burnAmount, 1, _mintAmount - 1);

    uint256 _stakeTimestamp = _STAKE_TIME_OFFSET;
    vm.warp(_stakeTimestamp);

    stakedGEOTokenProxy.workaround_mintBalance(alice, _mintAmount);

    vm.warp(_stakeTimestamp + _TIME_STEP);
    stakedGEOTokenProxy.workaround_burnBalance(alice, _burnAmount);

    uint256 _queryTimestamp = _stakeTimestamp + _STAKE_TIME_OFFSET;
    vm.warp(_queryTimestamp + 1);
    assertEq(stakedGEOTokenProxy.getPastStakeEligibleSince(alice, _queryTimestamp), _stakeTimestamp);
    assertEq(stakedGEOTokenProxy.exposed__findStakeEligibleSince(alice, _queryTimestamp), _stakeTimestamp);
    assertEq(stakedGEOTokenProxy.exposed__findCheckpointAtOrBefore(alice, _queryTimestamp), _SECOND_CHECKPOINT_INDEX);
  }

  function test_GetPastStakeEligibleSince_WhenFullyBurned(uint256 _mintAmount) external {
    _mintAmount = bound(_mintAmount, 1, _MAX_BALANCE_AMOUNT);

    uint256 _stakeTimestamp = _STAKE_TIME_OFFSET;
    vm.warp(_stakeTimestamp);

    stakedGEOTokenProxy.workaround_mintBalance(alice, _mintAmount);

    vm.warp(_stakeTimestamp + _TIME_STEP);
    stakedGEOTokenProxy.workaround_burnBalance(alice, _mintAmount);

    uint256 _queryTimestamp = _stakeTimestamp + _STAKE_TIME_OFFSET;
    vm.warp(_queryTimestamp + 1);
    assertEq(stakedGEOTokenProxy.getPastStakeEligibleSince(alice, _queryTimestamp), 0);
    assertEq(stakedGEOTokenProxy.exposed__findCheckpointAtOrBefore(alice, _queryTimestamp), _SECOND_CHECKPOINT_INDEX);
  }

  function test_GetPastStakeEligibleSince_WhenRestaked(uint256 _mintAmount) external {
    _mintAmount = bound(_mintAmount, 1, _MAX_BALANCE_AMOUNT);

    uint256 _firstStakeTimestamp = _STAKE_TIME_OFFSET;
    vm.warp(_firstStakeTimestamp);

    stakedGEOTokenProxy.workaround_mintBalance(alice, _mintAmount);

    vm.warp(_firstStakeTimestamp + _TIME_STEP);
    stakedGEOTokenProxy.workaround_burnBalance(alice, _mintAmount);

    uint256 _restakeTimestamp = _firstStakeTimestamp + _STAKE_TIME_OFFSET;
    vm.warp(_restakeTimestamp);
    stakedGEOTokenProxy.workaround_mintBalance(alice, _mintAmount);

    uint256 _queryTimestamp = _restakeTimestamp + _STAKE_TIME_OFFSET;
    vm.warp(_queryTimestamp + 1);
    assertEq(stakedGEOTokenProxy.getPastStakeEligibleSince(alice, _queryTimestamp), _restakeTimestamp);
    assertEq(stakedGEOTokenProxy.exposed__findStakeEligibleSince(alice, _queryTimestamp), _restakeTimestamp);
    assertEq(stakedGEOTokenProxy.exposed__findCheckpointAtOrBefore(alice, _queryTimestamp), _THIRD_CHECKPOINT_INDEX);
  }

  function test_GetPastStakeEligibleSince_WhenToppedUpBeforeQueryTimestamp(uint256 _mintAmount) external {
    _mintAmount = bound(_mintAmount, 1, _MAX_BALANCE_AMOUNT / 2);

    uint256 _firstStakeTimestamp = _STAKE_TIME_OFFSET;
    vm.warp(_firstStakeTimestamp);
    stakedGEOTokenProxy.workaround_mintBalance(alice, _mintAmount);

    uint256 _secondStakeTimestamp = _firstStakeTimestamp + _STAKE_TIME_OFFSET;
    vm.warp(_secondStakeTimestamp);
    stakedGEOTokenProxy.workaround_mintBalance(alice, _mintAmount);

    uint256 _queryTimestamp = _secondStakeTimestamp + _TIME_STEP;
    vm.warp(_queryTimestamp + 1);
    assertEq(stakedGEOTokenProxy.getPastStakeEligibleSince(alice, _queryTimestamp), _firstStakeTimestamp);
    assertEq(stakedGEOTokenProxy.exposed__findStakeEligibleSince(alice, _queryTimestamp), _firstStakeTimestamp);
    assertEq(stakedGEOTokenProxy.exposed__findCheckpointAtOrBefore(alice, _queryTimestamp), _SECOND_CHECKPOINT_INDEX);
  }

  function test_GetPastStakeEligibleSince_WhenToppedUpAfterQueryTimestamp(uint256 _mintAmount) external {
    _mintAmount = bound(_mintAmount, 1, _MAX_BALANCE_AMOUNT / 2);

    uint256 _firstStakeTimestamp = _STAKE_TIME_OFFSET;
    vm.warp(_firstStakeTimestamp);
    stakedGEOTokenProxy.workaround_mintBalance(alice, _mintAmount);

    uint256 _secondStakeTimestamp = _firstStakeTimestamp + _STAKE_TIME_OFFSET;
    vm.warp(_secondStakeTimestamp);
    stakedGEOTokenProxy.workaround_mintBalance(alice, _mintAmount);

    uint256 _queryTimestamp = _secondStakeTimestamp - _TIME_STEP;
    vm.warp(_secondStakeTimestamp + 1);
    assertEq(stakedGEOTokenProxy.getPastStakeEligibleSince(alice, _queryTimestamp), _firstStakeTimestamp);
    assertEq(stakedGEOTokenProxy.exposed__findStakeEligibleSince(alice, _queryTimestamp), _firstStakeTimestamp);
    assertEq(stakedGEOTokenProxy.exposed__findCheckpointAtOrBefore(alice, _queryTimestamp), _FIRST_CHECKPOINT_INDEX);
  }

  // -------- typeId --------
  function test_TypeId_WhenCalled() external view {
    // when called

    // it returns the type
    assertEq(stakedGEOTokenProxy.typeId(), keccak256('STAKED_GEO_TOKEN'));
  }

  // -------- version --------
  function test_Version_WhenCalled() external view {
    // when called

    // it returns semantic version
    assertEq(stakedGEOTokenProxy.version(), '1.0.0');
  }

  // -------- _authorizeUpgrade --------
  function test__authorizeUpgrade_WhenCalledByOwner() external {
    address _newImplementation = address(new StakedGEOToken());
    vm.prank(council);
    stakedGEOTokenProxy.upgradeToAndCall(_newImplementation, '');
  }

  function test__authorizeUpgrade_WhenCalledByNon_owner(address _caller) external {
    _assumeFuzzable(_caller);
    vm.assume(_caller != council);
    address _newImplementation = address(new StakedGEOToken());
    vm.prank(_caller);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
    stakedGEOTokenProxy.upgradeToAndCall(_newImplementation, '');
  }
}
