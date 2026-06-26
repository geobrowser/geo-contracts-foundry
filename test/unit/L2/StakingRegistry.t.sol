// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

import {UnsafeUpgrades} from '@openzeppelin/foundry-upgrades/Upgrades.sol';
import {StakingRegistry} from 'contracts/L2/StakingRegistry.sol';
import {IStakingRegistry} from 'interfaces/L2/IStakingRegistry.sol';
import {MockStakingRegistry} from 'test/unit/L2/mocks/MockStakingRegistry.sol';
import {TestHelper} from 'unit-helpers/TestHelper.sol';

contract UnitStakingRegistry is TestHelper {
  address public council = makeAddr('council');

  MockStakingRegistry public stakingRegistryImplementation;
  MockStakingRegistry public stakingRegistryProxy;

  function setUp() external {
    stakingRegistryImplementation = new MockStakingRegistry();
    stakingRegistryProxy = MockStakingRegistry(
      payable(UnsafeUpgrades.deployUUPSProxy(
          address(stakingRegistryImplementation),
          abi.encodeCall(
            StakingRegistry.initialize, (IStakingRegistry.StakingRegistryInitializationParams({council: council}))
          )
        ))
    );
  }

  // -------- constants --------
  function test_Constants_WhenDeployed() external view {
    // when deployed
    // it sets _STAKING_REGISTRY_STORAGE_LOCATION to keccak256(abi.encode(uint256(keccak256("geo.storage.StakingRegistry")) - 1)) & ~bytes32(uint256(0xff))
    assertEq(
      stakingRegistryImplementation.exposed__STAKING_REGISTRY_STORAGE_LOCATION(),
      keccak256(abi.encode(uint256(keccak256('geo.storage.StakingRegistry')) - 1)) & ~bytes32(uint256(0xff))
    );
  }

  // -------- constructor --------
  function test_Constructor_WhenCalled() external {
    // it disables initializers
    StakingRegistry newImplementation = new StakingRegistry();
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    newImplementation.initialize(IStakingRegistry.StakingRegistryInitializationParams({council: council}));
  }

  // -------- initialize --------
  function test_Initialize_WhenPassingValidParameters() external {
    // when passing valid parameters
    stakingRegistryImplementation = new MockStakingRegistry();
    MockStakingRegistry freshStakingRegistry = MockStakingRegistry(
      payable(UnsafeUpgrades.deployUUPSProxy(
          address(stakingRegistryImplementation),
          abi.encodeCall(
            StakingRegistry.initialize, (IStakingRegistry.StakingRegistryInitializationParams({council: council}))
          )
        ))
    );
    // it sets the owner
    assertEq(freshStakingRegistry.owner(), council);
  }

  function test_Initialize_WhenCalledTwice() external {
    // when called twice
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    stakingRegistryProxy.initialize(IStakingRegistry.StakingRegistryInitializationParams({council: council}));
  }

  function test_Initialize_WhenCouncilIsZero() external {
    // when council is zero
    stakingRegistryImplementation = new MockStakingRegistry();
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
    MockStakingRegistry(
      payable(UnsafeUpgrades.deployUUPSProxy(
          address(stakingRegistryImplementation),
          abi.encodeCall(
            StakingRegistry.initialize, (IStakingRegistry.StakingRegistryInitializationParams({council: address(0)}))
          )
        ))
    );
  }

  // -------- setTarget --------
  function test_SetTarget_WhenCalledByOwner(bytes32 _targetId, uint8 _tTypeRaw, bool _tActive) external {
    // when called by owner
    vm.assume(_targetId != bytes32(0));
    _tTypeRaw = uint8(bound(_tTypeRaw, 0, 2));
    IStakingRegistry.TargetType _tType = IStakingRegistry.TargetType(_tTypeRaw);
    vm.assume(!(_tType == IStakingRegistry.TargetType.Null && _tActive));
    vm.prank(council);
    // it emits TargetSet
    IStakingRegistry.Target memory _target = IStakingRegistry.Target({tType: _tType, tActive: _tActive});
    vm.expectEmit();
    emit IStakingRegistry.TargetSet(_targetId, _tType, _tActive);
    stakingRegistryProxy.setTarget(_targetId, _target);
    // it stores the target record
    IStakingRegistry.Target memory _stored = stakingRegistryProxy.targets(_targetId);
    assertEq(uint8(_stored.tType), uint8(_tType));
    assertEq(_stored.tActive, _tActive);
  }

  function test_SetTarget_WhenNullTypeIsActive() external {
    // when null type is active
    vm.prank(council);
    vm.expectRevert(IStakingRegistry.NullTargetCannotBeActive.selector);
    stakingRegistryProxy.setTarget(
      bytes32(uint256(1)), IStakingRegistry.Target({tType: IStakingRegistry.TargetType.Null, tActive: true})
    );
  }

  function test_SetTarget_WhenTargetIdIsZero() external {
    // when target id is zero
    vm.prank(council);
    vm.expectRevert(IStakingRegistry.InvalidTargetId.selector);
    stakingRegistryProxy.setTarget(
      bytes32(0), IStakingRegistry.Target({tType: IStakingRegistry.TargetType.Space, tActive: true})
    );
  }

  function test_SetTarget_WhenCalledByNon_owner(address _caller) external {
    // when called by non-owner
    _assumeFuzzable(_caller);
    vm.assume(_caller != council);
    vm.prank(_caller);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
    stakingRegistryProxy.setTarget(
      bytes32(uint256(1)), IStakingRegistry.Target({tType: IStakingRegistry.TargetType.Space, tActive: true})
    );
  }

  // -------- targets --------
  function test_Targets_WhenUnset(bytes32 _targetId) external view {
    // when unset
    // it returns the default record
    IStakingRegistry.Target memory _stored = stakingRegistryProxy.targets(_targetId);
    assertEq(uint8(_stored.tType), uint8(IStakingRegistry.TargetType.Null));
    assertFalse(_stored.tActive);
  }

  // -------- getTargetId --------
  function test_GetTargetId_WhenInterpretingAsASpaceId(bytes16 _spaceId) external view {
    // when interpreting as a space id
    // it matches the space encoding fixtures
    bytes32 _targetId = stakingRegistryProxy.getTargetId(bytes32(_spaceId), false);
    assertEq(_targetId, bytes32(_spaceId));

    _spaceId = bytes16(uint128(1));
    _targetId = stakingRegistryProxy.getTargetId(bytes32(_spaceId), false);
    assertEq(_spaceId, bytes16(uint128(1)));
    assertEq(_targetId, bytes32(bytes16(uint128(1))));

    _spaceId = bytes16(type(uint128).max);
    _targetId = stakingRegistryProxy.getTargetId(bytes32(_spaceId), false);
    assertEq(_spaceId, bytes16(type(uint128).max));
    assertEq(_targetId, bytes32(bytes16(type(uint128).max)));

    _spaceId = bytes16(bytes32(uint256(1)));
    _targetId = stakingRegistryProxy.getTargetId(bytes32(_spaceId), false);
    assertEq(_spaceId, bytes16(0));
    assertEq(_targetId, bytes32(0));

    _spaceId = bytes16(bytes32(uint256(type(uint128).max)));
    _targetId = stakingRegistryProxy.getTargetId(bytes32(_spaceId), false);
    assertEq(_spaceId, bytes16(0));
    assertEq(_targetId, bytes32(0));

    _spaceId = bytes16(bytes32(uint256(type(uint128).max) + 1));
    _targetId = stakingRegistryProxy.getTargetId(bytes32(_spaceId), false);
    assertEq(_spaceId, bytes16(uint128(1)));
    assertEq(_targetId, bytes32(bytes16(uint128(1))));

    _spaceId = bytes16(bytes32(type(uint256).max));
    _targetId = stakingRegistryProxy.getTargetId(bytes32(_spaceId), false);
    assertEq(_spaceId, bytes16(type(uint128).max));
    assertEq(_targetId, bytes32(bytes16(type(uint128).max)));
  }

  function test_GetTargetId_WhenInterpretingAsATopicId(bytes32 _topicId) external view {
    // when interpreting as a topic id
    // it folds the high 128 bits for topic ids
    bytes32 _targetId = stakingRegistryProxy.getTargetId(_topicId, true);
    assertEq(_targetId, _topicId >> 128);

    _topicId = bytes32(uint256(1));
    _targetId = stakingRegistryProxy.getTargetId(_topicId, true);
    assertEq(_topicId, bytes32(uint256(1)));
    assertEq(_targetId, bytes32(0));

    _topicId = bytes32(uint256(type(uint128).max));
    _targetId = stakingRegistryProxy.getTargetId(_topicId, true);
    assertEq(_topicId, bytes32(uint256(type(uint128).max)));
    assertEq(_targetId, bytes32(0));

    _topicId = bytes32(bytes16(uint128(1)));
    _targetId = stakingRegistryProxy.getTargetId(_topicId, true);
    assertEq(_topicId, bytes32(bytes16(uint128(1))));
    assertEq(_targetId, bytes32(uint256(1)));

    _topicId = bytes32(bytes16(type(uint128).max));
    _targetId = stakingRegistryProxy.getTargetId(_topicId, true);
    assertEq(_topicId, bytes32(bytes16(type(uint128).max)));
    assertEq(_targetId, bytes32(uint256(type(uint128).max)));
  }

  function test_GetTargetId_WhenFuzzingInputs(bytes32 _id, bool _isTopic) external view {
    // when fuzzing inputs
    // it matches the pure derivation rules
    bytes32 _derived = stakingRegistryProxy.getTargetId(_id, _isTopic);
    if (_isTopic) {
      assertEq(_derived, _id >> 128);
    } else {
      assertEq(_derived, _id);
    }
  }

  // -------- typeId --------
  function test_TypeId_WhenCalled() external view {
    // when called

    // it returns the type
    assertEq(stakingRegistryProxy.typeId(), keccak256('STAKING_REGISTRY'));
  }

  // -------- name --------
  function test_Name_WhenCalled() external view {
    // when called

    // it returns the name
    assertEq(stakingRegistryProxy.name(), 'STAKING_REGISTRY');
  }

  // -------- version --------
  function test_Version_WhenCalled() external view {
    // when called

    // it returns semantic version
    assertEq(stakingRegistryProxy.version(), '1.0.0');
  }

  // -------- _authorizeUpgrade --------
  function test__authorizeUpgrade_WhenCalledByOwner() external {
    // when called by owner
    address newImplementation = address(new StakingRegistry());
    vm.prank(council);
    // it authorizes the upgrade
    stakingRegistryProxy.upgradeToAndCall(newImplementation, '');
  }

  function test__authorizeUpgrade_WhenCalledByNon_owner(address _caller) external {
    // when called by non-owner
    _assumeFuzzable(_caller);
    vm.assume(_caller != council);
    address newImplementation = address(new StakingRegistry());
    vm.prank(_caller);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
    stakingRegistryProxy.upgradeToAndCall(newImplementation, '');
  }
}
