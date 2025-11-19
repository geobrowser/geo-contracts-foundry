// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {TestHelper} from 'test/unit/helpers/TestHelper.t.sol';

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {UnsafeUpgrades} from '@openzeppelin/foundry-upgrades/Upgrades.sol';

import {ISpace} from 'interfaces/ISpace.sol';
import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';
import {MockSpaceRegistry} from 'mocks/MockSpaceRegistry.sol';

import 'src/ActionsConstants.sol' as ActionsConstants;

contract UnitSpaceRegistry is TestHelper {
  MockSpaceRegistry public spaceRegistry;
  MockSpaceRegistry public spaceRegistryProxy;

  address internal _owner = makeAddr('_owner');
  address internal _randomCaller = makeAddr('_randomCaller');

  address internal _fromSpace = makeAddr('_fromSpace');
  address internal _toSpace = makeAddr('_toSpace');

  bytes16 internal _fromSpaceId = bytes16(keccak256('_fromSpaceId'));
  bytes16 internal _toSpaceId = bytes16(keccak256('_toSpaceId'));

  function setUp() external {
    // when deployed
    spaceRegistry = new MockSpaceRegistry();
    // when delegate called
    spaceRegistryProxy = MockSpaceRegistry(
      UnsafeUpgrades.deployUUPSProxy(address(spaceRegistry), abi.encodeCall(ISpaceRegistry.initialize, (_owner)))
    );
  }

  function test_Constructor_WhenCalled() external {
    // it disables initializers
    vm.expectEmit();
    emit Initializable.Initialized(type(uint64).max);

    // when called
    new MockSpaceRegistry();
  }

  modifier whenDelegateCalled() {
    // when delegate called
    _;
  }

  modifier whenOwnerIsNotZeroAddress(address __owner) {
    // when owner is not zero address
    vm.assume(__owner != address(0));
    _;
  }

  function test_Initialize_WhenOwnerIsNotZeroAddress(address __owner)
    external
    whenDelegateCalled
    whenOwnerIsNotZeroAddress(__owner)
  {
    // when delegate called
    spaceRegistryProxy = MockSpaceRegistry(
      UnsafeUpgrades.deployUUPSProxy(address(spaceRegistry), abi.encodeCall(ISpaceRegistry.initialize, (__owner)))
    );

    // it sets owner
    assertEq(spaceRegistryProxy.owner(), __owner);
  }

  function test_Initialize_WhenDelegateCalledAgain(address __owner)
    external
    whenDelegateCalled
    whenOwnerIsNotZeroAddress(__owner)
  {
    // when delegate called
    spaceRegistryProxy = MockSpaceRegistry(
      UnsafeUpgrades.deployUUPSProxy(address(spaceRegistry), abi.encodeCall(ISpaceRegistry.initialize, (__owner)))
    );

    // it reverts with InvalidInitialization
    vm.expectRevert(Initializable.InvalidInitialization.selector);

    // when delegate called again
    spaceRegistryProxy.initialize(__owner);
  }

  function test_Initialize_WhenOwnerIsZeroAddress() external whenDelegateCalled {
    // when owner is zero address
    address __owner = address(0);

    // it reverts with OwnableInvalidOwner
    vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, __owner));

    // when delegate called
    spaceRegistryProxy = MockSpaceRegistry(
      UnsafeUpgrades.deployUUPSProxy(address(spaceRegistry), abi.encodeCall(ISpaceRegistry.initialize, (__owner)))
    );
  }

  function test_Initialize_WhenCalled(address __owner) external {
    // it reverts with InvalidInitialization
    vm.expectRevert(Initializable.InvalidInitialization.selector);

    // when called
    spaceRegistry.initialize(__owner);
  }

  modifier whenSpacesAreRegistered() {
    // when spaces are registered
    _mockAddressToSpaceId(_fromSpace, _fromSpaceId);
    _mockAddressToSpaceId(_toSpace, _toSpaceId);
    _;
  }

  function test_Enter_WhenSpacesAreRegistered(
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data,
    bytes calldata _signature
  ) external whenSpacesAreRegistered {
    vm.startPrank(_randomCaller);

    _mockVerify(_toSpace, _action, _topic, _data, _signature);
    _mockWrite(_fromSpace, _action, _topic, _data);

    // it emits Action
    vm.expectEmit();
    emit ISpaceRegistry.Action(_fromSpaceId, _toSpaceId, _action, _topic, _data);

    spaceRegistryProxy.enter(_fromSpace, _toSpace, _action, _topic, _data, _signature);
  }

  function test_Enter_WhenCallerIsNotFromSpace(
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data,
    bytes calldata _signature
  ) external whenSpacesAreRegistered {
    // when caller is not fromSpace
    vm.startPrank(_toSpace);

    // it calls fromSpace to verify
    _mockVerify(_toSpace, _action, _topic, _data, _signature);

    spaceRegistryProxy.enter(_fromSpace, _toSpace, _action, _topic, _data, _signature);
  }

  function test_Enter_WhenCallerIsNotToSpace(
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data,
    bytes calldata _signature
  ) external whenSpacesAreRegistered {
    // when caller is not toSpace
    vm.startPrank(_fromSpace);

    // it calls toSpace to write
    _mockWrite(_fromSpace, _action, _topic, _data);

    spaceRegistryProxy.enter(_fromSpace, _toSpace, _action, _topic, _data, _signature);
  }

  function test_Enter_WhenSpaceIsNotRegistered(
    address _from,
    address _to,
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data,
    bytes calldata _signature
  ) external {
    // when space is not registered

    // it reverts with SpaceNotRegistered
    vm.expectRevert(ISpaceRegistry.SpaceNotRegistered.selector);

    spaceRegistryProxy.enter(_from, _to, _action, _topic, _data, _signature);
  }

  function test_RegisterSpaceId_WhenSpaceIsNotRegistered(address _account) external {
    // when space is not registered

    uint256 _spaceIdNonce = spaceRegistryProxy.exposed__spaceIdNonce();
    bytes16 _spaceId = bytes16(keccak256(abi.encodePacked('grc20.space', _account, _spaceIdNonce, block.chainid)));

    // it emits Action
    vm.expectEmit();
    emit ISpaceRegistry.Action(
      bytes16(0), _spaceId, ActionsConstants.SPACE_ID_REGISTERED, bytes32(bytes20(_account)), ''
    );

    vm.startPrank(_account);
    spaceRegistryProxy.registerSpaceId();

    // it increments _spaceIdNonce
    assertEq(spaceRegistryProxy.exposed__spaceIdNonce(), _spaceIdNonce + 1);
    // it sets addressToSpaceId
    assertEq(spaceRegistryProxy.addressToSpaceId(_account), _spaceId);
    // it sets spaceIdToAddress
    assertEq(spaceRegistryProxy.spaceIdToAddress(_spaceId), _account);
  }

  function test_RegisterSpaceId_WhenSpaceIsRegistered(address _account, bytes16 _spaceId) external {
    // when space is registered
    vm.assume(_spaceId != bytes16(0));
    _mockAddressToSpaceId(_account, _spaceId);

    // it reverts with SpaceAlreadyRegistered
    vm.expectRevert(ISpaceRegistry.SpaceAlreadyRegistered.selector);

    vm.startPrank(_account);
    spaceRegistryProxy.registerSpaceId();
  }

  function test_ProposeSpaceMigration_WhenCallerIsSpace(address _newAccount) external {
    // when caller is space
    _mockAddressToSpaceId(_fromSpace, _fromSpaceId);
    vm.startPrank(_fromSpace);

    spaceRegistryProxy.proposeSpaceMigration(_newAccount);

    // it updates spaceIdToProposedAddress
    assertEq(spaceRegistryProxy.spaceIdToProposedAddress(_fromSpaceId), _newAccount);
  }

  function test_ProposeSpaceMigration_WhenCallerIsNotSpace(address _newAccount) external {
    // when caller is not space
    vm.startPrank(_randomCaller);

    // it reverts with InvalidCaller
    vm.expectRevert(ISpaceRegistry.InvalidCaller.selector);

    spaceRegistryProxy.proposeSpaceMigration(_newAccount);
  }

  modifier whenCallerIsProposedSpace() {
    // when caller is proposed space
    _mockAddressToSpaceId(_fromSpace, _fromSpaceId);
    _mockSpaceIdToAddress(_fromSpaceId, _fromSpace);
    _mockSpaceIdToProposedAddress(_fromSpaceId, _toSpace);
    vm.startPrank(_toSpace);
    _;
  }

  function test_AcceptSpaceMigration_WhenProposedSpaceIsNotRegistered() external whenCallerIsProposedSpace {
    // when proposed space is not registered

    // it emits Action
    vm.expectEmit();
    emit ISpaceRegistry.Action(
      _fromSpaceId, _fromSpaceId, ActionsConstants.SPACE_ID_MIGRATED, bytes32(bytes20(_toSpace)), ''
    );

    spaceRegistryProxy.acceptSpaceMigration(_fromSpaceId);

    // it updates spaceIdToProposedAddress
    assertEq(spaceRegistryProxy.spaceIdToProposedAddress(_fromSpaceId), address(0));
    // it updates spaceIdToAddress
    assertEq(spaceRegistryProxy.spaceIdToAddress(_fromSpaceId), _toSpace);
    // it updates addressToSpaceId
    assertEq(spaceRegistryProxy.addressToSpaceId(_fromSpace), bytes16(0));
    assertEq(spaceRegistryProxy.addressToSpaceId(_toSpace), _fromSpaceId);
  }

  function test_AcceptSpaceMigration_WhenProposedSpaceIsRegistered() external whenCallerIsProposedSpace {
    // when proposed space is registered
    _mockAddressToSpaceId(_toSpace, _toSpaceId);

    // it reverts with SpaceAlreadyRegistered
    vm.expectRevert(ISpaceRegistry.SpaceAlreadyRegistered.selector);

    spaceRegistryProxy.acceptSpaceMigration(_fromSpaceId);
  }

  function test_AcceptSpaceMigration_WhenCallerIsNotProposedSpace(bytes16 _spaceId) external {
    // when caller is not proposed space
    vm.startPrank(_randomCaller);

    // it reverts with InvalidCaller
    vm.expectRevert(ISpaceRegistry.InvalidCaller.selector);

    spaceRegistryProxy.acceptSpaceMigration(_spaceId);
  }

  function test_GenerateSpaceId_WhenCalled(address _account, uint256 _nonce) external view {
    bytes16 _spaceId = bytes16(keccak256(abi.encodePacked('grc20.space', _account, _nonce, block.chainid)));

    // it returns spaceId
    assertEq(spaceRegistryProxy.generateSpaceId(_account, _nonce), _spaceId);
  }

  function test_Version_WhenCalled() external view {
    // when called

    // it returns semantic version
    assertEq(spaceRegistryProxy.version(), '1.0.0');
  }

  function test__authorizeUpgrade_WhenCalledByOwner(address _newImplementation) external {
    // when called by owner
    vm.startPrank(_owner);

    // it does not revert
    spaceRegistryProxy.exposed__authorizeUpgrade(_newImplementation);
  }

  function test__authorizeUpgrade_WhenCalledByNon_owner(address _newImplementation) external {
    // when called by non-owner
    vm.startPrank(_randomCaller);

    // it reverts with OwnableUnauthorizedAccount
    vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, _randomCaller));

    spaceRegistryProxy.exposed__authorizeUpgrade(_newImplementation);
  }

  function _mockSpaceIdToAddress(bytes16 _spaceId, address _account) internal {
    spaceRegistryProxy.workaround_setSpaceIdToAddress(_spaceId, _account);
  }

  function _mockSpaceIdToProposedAddress(bytes16 _spaceId, address _account) internal {
    spaceRegistryProxy.workaround_setSpaceIdToProposedAddress(_spaceId, _account);
  }

  function _mockAddressToSpaceId(address _account, bytes16 _spaceId) internal {
    spaceRegistryProxy.workaround_setAddressToSpaceId(_account, _spaceId);
  }

  function _mockVerify(
    address _space,
    bytes32 __action,
    bytes32 __topic,
    bytes calldata _data,
    bytes calldata _signature
  ) internal {
    _mockAndExpect(
      _fromSpace, abi.encodeCall(ISpace.verify, (_space, __action, __topic, _data, _signature)), abi.encode()
    );
  }

  function _mockWrite(address _space, bytes32 __action, bytes32 __topic, bytes calldata _data) internal {
    _mockAndExpect(_toSpace, abi.encodeCall(ISpace.write, (_space, __action, __topic, _data)), abi.encode());
  }
}
