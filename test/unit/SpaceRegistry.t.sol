// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {TestHelper} from 'test/unit/helpers/TestHelper.t.sol';

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {UnsafeUpgrades} from '@openzeppelin/foundry-upgrades/Upgrades.sol';

import {ISpace} from 'interfaces/ISpace.sol';
import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';
import {MockSpaceRegistry} from 'test/unit/mocks/MockSpaceRegistry.sol';

import 'src/ActionsConstants.sol' as ActionsConstants;

contract UnitSpaceRegistry is TestHelper {
  MockSpaceRegistry public spaceRegistryImplementation;
  MockSpaceRegistry public spaceRegistryProxy;

  address internal _owner = makeAddr('_owner');
  address internal _randomCaller = makeAddr('_randomCaller');

  address internal _fromSpace = makeAddr('_fromSpace');
  address internal _toSpace = makeAddr('_toSpace');

  bytes16 internal _fromSpaceId = bytes16(keccak256('_fromSpaceId'));
  bytes16 internal _toSpaceId = bytes16(keccak256('_toSpaceId'));

  bytes32 internal _permissionlessAction = bytes32(keccak256('_permissionlessAction'));

  function setUp() external {
    // when deployed
    spaceRegistryImplementation = new MockSpaceRegistry();
    // when delegate called
    spaceRegistryProxy = MockSpaceRegistry(
      UnsafeUpgrades.deployUUPSProxy(
        address(spaceRegistryImplementation), abi.encodeCall(ISpaceRegistry.initialize, (abi.encode(_owner)))
      )
    );
  }

  function test_Constants_WhenDeployed() external view {
    // when deployed
    // it sets _SPACE_REGISTRY_STORAGE_LOCATION to keccak256(abi.encode(uint256(keccak256("geo.storage.SpaceRegistry")) - 1)) & ~bytes32(uint256(0xff))
    assertEq(
      spaceRegistryProxy.exposed__SPACE_REGISTRY_STORAGE_LOCATION(),
      keccak256(abi.encode(uint256(keccak256('geo.storage.SpaceRegistry')) - 1)) & ~bytes32(uint256(0xff))
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
    address _predictedSpaceRegistryProxy = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
    bytes16 _spaceId = _getSpaceId(_predictedSpaceRegistryProxy, 0);

    // it emits Action with SPACE_ID_REGISTERED
    vm.expectEmit();
    emit ISpaceRegistry.Action(
      bytes16(0), _spaceId, ActionsConstants.SPACE_ID_REGISTERED, bytes32(bytes20(_predictedSpaceRegistryProxy)), ''
    );

    // it emits Action with SPACE_TYPE_DECLARED
    vm.expectEmit();
    emit ISpaceRegistry.Action(
      _spaceId, _spaceId, ActionsConstants.SPACE_TYPE_DECLARED, keccak256('SPACE_REGISTRY'), abi.encode('1.0.0')
    );

    // when delegate called
    spaceRegistryProxy = MockSpaceRegistry(
      UnsafeUpgrades.deployUUPSProxy(
        address(spaceRegistryImplementation), abi.encodeCall(ISpaceRegistry.initialize, (abi.encode(__owner)))
      )
    );
    assertEq(address(spaceRegistryProxy), _predictedSpaceRegistryProxy);

    // it sets owner
    assertEq(spaceRegistryProxy.owner(), __owner);

    // it adds the permissionless actions
    assertEq(spaceRegistryProxy.permissionlessActions(ActionsConstants.UPVOTED), true);
    assertEq(spaceRegistryProxy.permissionlessActions(ActionsConstants.DOWNVOTED), true);
    assertEq(spaceRegistryProxy.permissionlessActions(ActionsConstants.UNVOTED), true);
    assertEq(spaceRegistryProxy.permissionlessActions(ActionsConstants.COMMENTED), true);

    // it registers the space registry
    assertEq(spaceRegistryProxy.addressToSpaceId(address(spaceRegistryProxy)), _spaceId);
    assertEq(spaceRegistryProxy.spaceIdToAddress(_spaceId), address(spaceRegistryProxy));
  }

  function test_Initialize_WhenDelegateCalledAgain(address __owner)
    external
    whenDelegateCalled
    whenOwnerIsNotZeroAddress(__owner)
  {
    // when delegate called
    spaceRegistryProxy = MockSpaceRegistry(
      UnsafeUpgrades.deployUUPSProxy(
        address(spaceRegistryImplementation), abi.encodeCall(ISpaceRegistry.initialize, (abi.encode(__owner)))
      )
    );

    // it reverts with InvalidInitialization
    vm.expectRevert(Initializable.InvalidInitialization.selector);

    // when delegate called again
    spaceRegistryProxy.initialize(abi.encode(__owner));
  }

  function test_Initialize_WhenOwnerIsZeroAddress() external whenDelegateCalled {
    // when owner is zero address
    address __owner = address(0);

    // it reverts with OwnableInvalidOwner
    vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, __owner));

    // when delegate called
    spaceRegistryProxy = MockSpaceRegistry(
      UnsafeUpgrades.deployUUPSProxy(
        address(spaceRegistryImplementation), abi.encodeCall(ISpaceRegistry.initialize, (abi.encode(__owner)))
      )
    );
  }

  function test_Initialize_WhenCalled(address __owner) external {
    // it reverts with InvalidInitialization
    vm.expectRevert(Initializable.InvalidInitialization.selector);

    // when called
    spaceRegistryImplementation.initialize(abi.encode(__owner));
  }

  modifier whenSpacesAreRegistered() {
    // when spaces are registered
    _mockAddressToSpaceId(_fromSpace, _fromSpaceId);
    _mockAddressToSpaceId(_toSpace, _toSpaceId);
    _;
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
    _mockVerify(_fromSpace, _toSpace, _action, _topic, _data, _signature);

    spaceRegistryProxy.enter(_fromSpace, _toSpace, _action, _topic, _data, _signature);
  }

  modifier whenCallerIsNotToSpace() {
    // when caller is not toSpace
    vm.startPrank(_fromSpace);
    _;
    vm.stopPrank();
  }

  function test_Enter_When_actionIsNotPermissionless(
    bytes32 _action,
    bytes32 _topicInput,
    bytes32 _topicOutput,
    bytes calldata _data,
    bytes calldata _signature
  ) external whenSpacesAreRegistered whenCallerIsNotToSpace {
    // when _action is not permissionless
    _whenActionIsNotPermissionless(_action);

    // it calls toSpace to fetch _topicOutput
    _mockFetch(_toSpace, _action, _topicInput, _data, _topicOutput);

    // it emits Action
    vm.expectEmit();
    emit ISpaceRegistry.Action(_fromSpaceId, _toSpaceId, _action, _topicOutput, _data);

    // it calls toSpace to write
    _mockWrite(_fromSpace, _toSpace, _action, _topicOutput, _data);

    spaceRegistryProxy.enter(_fromSpace, _toSpace, _action, _topicInput, _data, _signature);
  }

  function test_Enter_When_actionIsPermissionless(
    bytes32 _topicInput,
    bytes calldata _data,
    bytes calldata _signature
  ) external whenSpacesAreRegistered whenCallerIsNotToSpace {
    // it emits Action
    vm.expectEmit();
    emit ISpaceRegistry.Action(_fromSpaceId, _toSpaceId, ActionsConstants.UPVOTED, _topicInput, _data);
    spaceRegistryProxy.enter(_fromSpace, _toSpace, ActionsConstants.UPVOTED, _topicInput, _data, _signature);
  }

  function test_Enter_WhenSpaceIsNotRegistered(
    address _from,
    address _to,
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data,
    bytes calldata _signature
  ) external whenSpaceIsNotRegistered {
    // it reverts with SpaceNotRegistered
    vm.expectRevert(ISpaceRegistry.SpaceNotRegistered.selector);

    spaceRegistryProxy.enter(_from, _to, _action, _topic, _data, _signature);
  }

  modifier whenSpaceIsNotRegistered() {
    // when space is not registered
    _;
  }

  function test_RegisterSpaceId_WhenSpaceIsNotRegistered(address _account) external whenSpaceIsNotRegistered {
    vm.assume(_account != address(spaceRegistryProxy));

    uint256 _spaceIdNonce = spaceRegistryProxy.exposed__spaceIdNonce();
    bytes16 _spaceId = _getSpaceId(_account, _spaceIdNonce);

    // it emits Action with SPACE_ID_REGISTERED
    vm.expectEmit();
    emit ISpaceRegistry.Action(
      bytes16(0), _spaceId, ActionsConstants.SPACE_ID_REGISTERED, bytes32(bytes20(_account)), ''
    );

    vm.startPrank(_account);
    spaceRegistryProxy.registerSpaceId(bytes32(0), '');

    // it increments _spaceIdNonce
    assertEq(spaceRegistryProxy.exposed__spaceIdNonce(), _spaceIdNonce + 1);
    // it sets addressToSpaceId
    assertEq(spaceRegistryProxy.addressToSpaceId(_account), _spaceId);
    // it sets spaceIdToAddress
    assertEq(spaceRegistryProxy.spaceIdToAddress(_spaceId), _account);
  }

  function test_RegisterSpaceId_When_typeExists(
    address _account,
    bytes32 _type,
    bytes calldata _version
  ) external whenSpaceIsNotRegistered {
    vm.assume(_account != address(spaceRegistryProxy));

    uint256 _spaceIdNonce = spaceRegistryProxy.exposed__spaceIdNonce();
    bytes16 _spaceId = _getSpaceId(_account, _spaceIdNonce);

    vm.assume(_type != bytes32(0));

    // it emits Action with SPACE_ID_REGISTERED
    vm.expectEmit();
    emit ISpaceRegistry.Action(
      bytes16(0), _spaceId, ActionsConstants.SPACE_ID_REGISTERED, bytes32(bytes20(_account)), ''
    );

    // it emits Action with SPACE_TYPE_DECLARED
    vm.expectEmit();
    emit ISpaceRegistry.Action(_spaceId, _spaceId, ActionsConstants.SPACE_TYPE_DECLARED, _type, _version);

    vm.startPrank(_account);
    spaceRegistryProxy.registerSpaceId(_type, _version);
  }

  function test_RegisterSpaceId_WhenSpaceIsRegistered(
    address _account,
    bytes16 _spaceId,
    bytes32 _type,
    bytes calldata _version
  ) external {
    // when space is registered
    vm.assume(_spaceId != bytes16(0));
    _mockAddressToSpaceId(_account, _spaceId);

    // it reverts with SpaceAlreadyRegistered
    vm.expectRevert(ISpaceRegistry.SpaceAlreadyRegistered.selector);

    vm.startPrank(_account);
    spaceRegistryProxy.registerSpaceId(_type, _version);
  }

  function test_ClearSpaceId_WhenCallerIsSpace() external {
    // set caller up as proposer from space
    _mockAddressToSpaceId(_fromSpace, _fromSpaceId);
    _mockSpaceIdToAddress(_fromSpaceId, _fromSpace);
    _mockSpaceIdToProposedAddress(_fromSpaceId, _toSpace);
    vm.startPrank(_fromSpace);

    // it emits Action with SPACE_ID_CLEARED
    vm.expectEmit();
    emit ISpaceRegistry.Action(
      _fromSpaceId, bytes16(0), ActionsConstants.SPACE_ID_CLEARED, bytes32(bytes20(_fromSpace)), ''
    );

    spaceRegistryProxy.clearSpaceId();

    // it resets addressToSpaceId
    assertEq(spaceRegistryProxy.addressToSpaceId(_fromSpace), bytes16(0));

    // it resets spaceIdToAddress
    assertEq(spaceRegistryProxy.spaceIdToAddress(_fromSpaceId), address(0));

    // it resets spaceIdToProposedAddress
    assertEq(spaceRegistryProxy.spaceIdToProposedAddress(_fromSpaceId), address(0));
  }

  function test_ClearSpaceId_WhenCallerIsNotSpace(address _newAccount) external {
    // when caller is not space
    vm.startPrank(_randomCaller);

    // it reverts with InvalidCaller
    vm.expectRevert(ISpaceRegistry.InvalidCaller.selector);

    spaceRegistryProxy.clearSpaceId();
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

  modifier whenProposedSpaceIsNotRegistered() {
    // when proposed space is not registered
    _;
  }

  function test_AcceptSpaceMigration_WhenProposedSpaceIsNotRegistered()
    external
    whenCallerIsProposedSpace
    whenProposedSpaceIsNotRegistered
  {
    // it emits Action with SPACE_ID_MIGRATED
    vm.expectEmit();
    emit ISpaceRegistry.Action(
      _fromSpaceId, _fromSpaceId, ActionsConstants.SPACE_ID_MIGRATED, bytes32(bytes20(_toSpace)), ''
    );

    spaceRegistryProxy.acceptSpaceMigration(_fromSpaceId, bytes32(0), '');

    // it updates spaceIdToProposedAddress
    assertEq(spaceRegistryProxy.spaceIdToProposedAddress(_fromSpaceId), address(0));
    // it updates spaceIdToAddress
    assertEq(spaceRegistryProxy.spaceIdToAddress(_fromSpaceId), _toSpace);
    // it updates addressToSpaceId
    assertEq(spaceRegistryProxy.addressToSpaceId(_fromSpace), bytes16(0));
    assertEq(spaceRegistryProxy.addressToSpaceId(_toSpace), _fromSpaceId);
  }

  function test_AcceptSpaceMigration_When_typeExists(
    bytes32 _type,
    bytes calldata _version
  ) external whenCallerIsProposedSpace whenProposedSpaceIsNotRegistered {
    vm.assume(_type != bytes32(0));

    // it emits Action with SPACE_ID_MIGRATED
    vm.expectEmit();
    emit ISpaceRegistry.Action(
      _fromSpaceId, _fromSpaceId, ActionsConstants.SPACE_ID_MIGRATED, bytes32(bytes20(_toSpace)), ''
    );

    // it emits Action with SPACE_TYPE_DECLARED
    vm.expectEmit();
    emit ISpaceRegistry.Action(_fromSpaceId, _fromSpaceId, ActionsConstants.SPACE_TYPE_DECLARED, _type, _version);

    spaceRegistryProxy.acceptSpaceMigration(_fromSpaceId, _type, _version);
  }

  function test_AcceptSpaceMigration_WhenProposedSpaceIsRegistered(
    bytes32 _type,
    bytes calldata _version
  ) external whenCallerIsProposedSpace {
    // when proposed space is registered
    _mockAddressToSpaceId(_toSpace, _toSpaceId);

    // it reverts with SpaceAlreadyRegistered
    vm.expectRevert(ISpaceRegistry.SpaceAlreadyRegistered.selector);

    spaceRegistryProxy.acceptSpaceMigration(_fromSpaceId, _type, _version);
  }

  function test_AcceptSpaceMigration_WhenCallerIsNotProposedSpace(
    bytes16 _spaceId,
    bytes32 _type,
    bytes calldata _version
  ) external {
    // when caller is not proposed space
    vm.startPrank(_randomCaller);

    // it reverts with InvalidCaller
    vm.expectRevert(ISpaceRegistry.InvalidCaller.selector);

    spaceRegistryProxy.acceptSpaceMigration(_spaceId, _type, _version);
  }

  modifier whenCalledByOwner() {
    vm.startPrank(_owner);
    _;
    vm.stopPrank();
  }

  function test_SetPermissionlessAction_When_setIsTrue(bytes32 _action) external whenCalledByOwner {
    _whenActionIsNotPermissionless(_action);

    assertEq(spaceRegistryProxy.permissionlessActions(_action), false);

    // it emits Action with PERMISSIONLESS_ACTION_ADDED
    vm.expectEmit();
    emit ISpaceRegistry.Action(bytes16(0), bytes16(0), ActionsConstants.PERMISSIONLESS_ACTION_ADDED, _action, '');
    spaceRegistryProxy.setPermissionlessAction(_action, true);

    // it updates the permissionlessActions mapping to add the action
    assertEq(spaceRegistryProxy.permissionlessActions(_action), true);
  }

  function test_SetPermissionlessAction_When_setIsFalse() external whenCalledByOwner {
    assertEq(spaceRegistryProxy.permissionlessActions(ActionsConstants.UPVOTED), true);

    // it emits Action with PERMISSIONLESS_ACTION_REMOVED
    vm.expectEmit();
    emit ISpaceRegistry.Action(
      bytes16(0), bytes16(0), ActionsConstants.PERMISSIONLESS_ACTION_REMOVED, ActionsConstants.UPVOTED, ''
    );
    spaceRegistryProxy.setPermissionlessAction(ActionsConstants.UPVOTED, false);

    // it updates the permissionlessActions mapping to remove the action
    assertEq(spaceRegistryProxy.permissionlessActions(ActionsConstants.UPVOTED), false);
  }

  function test_SetPermissionlessAction_WhenCalledByNon_owner(bytes32 _action, bool _set) external {
    // when called by non-owner
    vm.startPrank(_randomCaller);

    // it reverts with OwnableUnauthorizedAccount
    vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, _randomCaller));
    spaceRegistryProxy.setPermissionlessAction(_action, _set);
  }

  function test_GenerateSpaceId_WhenCalled(address _account, uint256 _nonce) external view {
    // it returns spaceId
    assertEq(spaceRegistryProxy.generateSpaceId(_account, _nonce), _getSpaceId(_account, _nonce));
  }

  function test_TypeId_WhenCalled() external view {
    // when called

    // it returns the type
    assertEq(spaceRegistryProxy.typeId(), keccak256('SPACE_REGISTRY'));
  }

  function test_Name_WhenCalled() external view {
    // when called

    // it returns the name
    assertEq(spaceRegistryProxy.name(), 'SPACE_REGISTRY');
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

  function _mockFetch(
    address __toSpace,
    bytes32 _action,
    bytes32 _topicInput,
    bytes calldata _data,
    bytes32 _topicOutput
  ) internal {
    _mockAndExpect(__toSpace, abi.encodeCall(ISpace.fetch, (_action, _topicInput, _data)), abi.encode(_topicOutput));
  }

  function _mockVerify(
    address __fromSpace,
    address __toSpace,
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data,
    bytes calldata _signature
  ) internal {
    _mockAndExpect(
      __fromSpace, abi.encodeCall(ISpace.verify, (__toSpace, _action, _topic, _data, _signature)), abi.encode()
    );
  }

  function _mockWrite(
    address __fromSpace,
    address __toSpace,
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data
  ) internal {
    _mockAndExpect(__toSpace, abi.encodeCall(ISpace.write, (__fromSpace, _action, _topic, _data)), abi.encode());
  }

  function _whenActionIsNotPermissionless(bytes32 _action) internal pure {
    vm.assume(_action != ActionsConstants.UPVOTED);
    vm.assume(_action != ActionsConstants.DOWNVOTED);
    vm.assume(_action != ActionsConstants.UNVOTED);
    vm.assume(_action != ActionsConstants.COMMENTED);
  }

  function _getSpaceId(address _account, uint256 _nonce) internal view returns (bytes16 _spaceId) {
    return bytes16(keccak256(abi.encodePacked('grc20.space', _account, _nonce, block.chainid)));
  }
}
