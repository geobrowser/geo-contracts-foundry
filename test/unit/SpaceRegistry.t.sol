// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {TestHelper} from 'test/unit/helpers/TestHelper.t.sol';

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {UnsafeUpgrades} from '@openzeppelin/foundry-upgrades/Upgrades.sol';

import {ISpace} from 'interfaces/ISpace.sol';
import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';
import {IArbSys} from 'interfaces/cross-chain/IArbSys.sol';
import {IPaymentManager} from 'interfaces/cross-chain/IPaymentManager.sol';
import {MockSpaceRegistry} from 'test/unit/mocks/MockSpaceRegistry.sol';

import 'src/ActionsConstants.sol' as ActionsConstants;

contract UnitSpaceRegistry is TestHelper {
  MockSpaceRegistry public spaceRegistryImplementation;
  MockSpaceRegistry public spaceRegistryProxy;

  address internal _owner = makeAddr('_owner');
  address internal _randomCaller = makeAddr('_randomCaller');

  address internal _fromSpace = makeAddr('_fromSpace');
  address internal _toSpace = makeAddr('_toSpace');

  address internal constant _ARB_SYS = address(100);

  address internal _paymentManager = makeAddr('_paymentManager');
  address internal _incentivesSpace = makeAddr('_incentivesSpace');
  address internal _incentivesPayer = makeAddr('_incentivesPayer');

  bytes16 internal _fromSpaceId = bytes16(keccak256('_fromSpaceId'));
  bytes16 internal _incentivesSpaceId = bytes16(keccak256('_incentivesSpaceId'));
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
    // it sets _ARB_SYS to address(100)
    assertEq(spaceRegistryProxy.exposed__ARB_SYS(), _ARB_SYS);
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
    assertTrue(spaceRegistryProxy.permissionlessActions(ActionsConstants.UPVOTED));
    assertTrue(spaceRegistryProxy.permissionlessActions(ActionsConstants.DOWNVOTED));
    assertTrue(spaceRegistryProxy.permissionlessActions(ActionsConstants.UNVOTED));
    assertTrue(spaceRegistryProxy.permissionlessActions(ActionsConstants.COMMENTED));

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

  modifier whenSpaceIdsAreActive() {
    // when spaceIds are active
    _mockAddressToSpaceId(_fromSpace, _fromSpaceId);
    _mockAddressToSpaceId(_toSpace, _toSpaceId);
    _mockSpaceIdToAddress(_fromSpaceId, _fromSpace);
    _mockSpaceIdToAddress(_toSpaceId, _toSpace);
    _;
  }

  modifier whenCallerIsNotFromSpaceId() {
    // when caller is not fromSpaceId
    vm.startPrank(_toSpace);
    _;
    vm.stopPrank();
  }

  function test_Enter_WhenCallerIsNotFromSpaceId(
    uint8 _permissionlessActionIndex,
    bytes32 _subjectInput,
    bytes calldata _data,
    bytes calldata _signature
  ) external whenSpaceIdsAreActive whenCallerIsNotFromSpaceId {
    bytes32 _action = _permissionlessActionFromIndex(_permissionlessActionIndex);

    // it calls fromSpaceId to verify
    _mockVerify(_fromSpace, _toSpace, _toSpaceId, _action, _subjectInput, _data, _signature);

    vm.expectEmit();
    emit ISpaceRegistry.Action(_fromSpaceId, _toSpaceId, _action, _subjectInput, _data);
    spaceRegistryProxy.enter(_fromSpaceId, _toSpaceId, _action, _subjectInput, _data, _signature);
  }

  modifier when_actionIsPermissionless() {
    // when _action is permissionless
    _;
  }

  function test_Enter_When_actionIsPermissionless(
    uint8 _permissionlessActionIndex,
    bytes32 _subjectInput,
    bytes calldata _data,
    bytes calldata _signature
  ) external whenSpaceIdsAreActive when_actionIsPermissionless {
    bytes32 _action = _permissionlessActionFromIndex(_permissionlessActionIndex);

    // it emits Action
    vm.startPrank(_fromSpace);
    vm.expectEmit();
    emit ISpaceRegistry.Action(_fromSpaceId, _toSpaceId, _action, _subjectInput, _data);
    spaceRegistryProxy.enter(_fromSpaceId, _toSpaceId, _action, _subjectInput, _data, _signature);
    vm.stopPrank();
  }

  modifier whenCallerIsNotToSpaceId() {
    // when caller is not toSpaceId
    vm.startPrank(_fromSpace);
    _;
    vm.stopPrank();
  }

  modifier when_actionIsNotPermissionless() {
    // when _action is not permissionless
    _;
  }

  function test_Enter_WhenCallerIsNotToSpaceId(
    bytes32 _action,
    bytes32 _subjectInput,
    bytes32 _subjectOutput,
    bytes calldata _data,
    bytes calldata _signature
  ) external whenSpaceIdsAreActive when_actionIsNotPermissionless whenCallerIsNotToSpaceId {
    _whenActionIsNotPermissionless(_action);

    // it calls toSpaceId to fetch _subjectOutput
    _mockFetch(_toSpace, _action, _subjectInput, _data, _subjectOutput);

    // it emits Action
    vm.expectEmit();
    emit ISpaceRegistry.Action(_fromSpaceId, _toSpaceId, _action, _subjectOutput, _data);

    // it calls toSpaceId to write
    _mockWrite(_toSpace, _fromSpaceId, _action, _subjectOutput, _data);

    spaceRegistryProxy.enter(_fromSpaceId, _toSpaceId, _action, _subjectInput, _data, _signature);
  }

  modifier whenCallerIsToSpaceId() {
    // when caller is toSpaceId
    vm.startPrank(_toSpace);
    _;
    vm.stopPrank();
  }

  function test_Enter_WhenCallerIsToSpaceId(
    bytes32 _action,
    bytes32 _subjectInput,
    bytes calldata _data,
    bytes calldata _signature
  ) external whenSpaceIdsAreActive when_actionIsNotPermissionless whenCallerIsToSpaceId {
    _whenActionIsNotPermissionless(_action);

    _mockVerify(_fromSpace, _toSpace, _toSpaceId, _action, _subjectInput, _data, _signature);

    // it emits Action
    vm.expectEmit();
    emit ISpaceRegistry.Action(_fromSpaceId, _toSpaceId, _action, _subjectInput, _data);

    spaceRegistryProxy.enter(_fromSpaceId, _toSpaceId, _action, _subjectInput, _data, _signature);
  }

  function test_Enter_WhenSpaceIdIsNotActive(
    bytes16 __fromSpaceId,
    bytes16 __toSpaceId,
    bytes32 _action,
    bytes32 _subject,
    bytes calldata _data,
    bytes calldata _signature
  ) external {
    // when spaceId is not registered
    vm.assume(__fromSpaceId != bytes16(0));
    vm.assume(__toSpaceId != bytes16(0));

    // it reverts with SpaceNotActive
    vm.expectRevert(ISpaceRegistry.SpaceNotActive.selector);

    spaceRegistryProxy.enter(__fromSpaceId, __toSpaceId, _action, _subject, _data, _signature);

    // when spaceId is registered but archived
    _mockSpaceIdToAddress(_fromSpaceId, _fromSpace);
    _mockSpaceIdToAddress(_toSpaceId, _toSpace);
    _mockArchivedSpaceIds(_fromSpaceId, true);

    // it reverts with SpaceNotActive
    vm.expectRevert(ISpaceRegistry.SpaceNotActive.selector);

    spaceRegistryProxy.enter(_fromSpaceId, _toSpaceId, _action, _subject, _data, _signature);
  }

  modifier whenSpaceIdIsNotRegistered() {
    // when spaceId is not registered
    _;
  }

  function test_RegisterSpaceId_WhenSpaceIdIsNotRegistered(address _account) external whenSpaceIdIsNotRegistered {
    vm.assume(_account != address(0));
    vm.assume(_account != address(spaceRegistryProxy));

    uint256 _spaceIdNonce = spaceRegistryProxy.exposed__spaceIdNonce();
    bytes16 _spaceId = _getSpaceId(_account, _spaceIdNonce);
    assertFalse(spaceRegistryProxy.registeredSpaceIds(_spaceId));

    // it emits Action with SPACE_ID_REGISTERED
    vm.expectEmit();
    emit ISpaceRegistry.Action(
      bytes16(0), _spaceId, ActionsConstants.SPACE_ID_REGISTERED, bytes32(bytes20(_account)), ''
    );

    vm.startPrank(_account);
    bytes16 _returnedSpaceId = spaceRegistryProxy.registerSpaceId(bytes32(0), '');

    // it returns the newly generated spaceId
    assertEq(_returnedSpaceId, _spaceId);
    // it increments _spaceIdNonce
    assertEq(spaceRegistryProxy.exposed__spaceIdNonce(), _spaceIdNonce + 1);
    // it sets addressToSpaceId
    assertEq(spaceRegistryProxy.addressToSpaceId(_account), _spaceId);
    // it sets spaceIdToAddress
    assertEq(spaceRegistryProxy.spaceIdToAddress(_spaceId), _account);
    // it registers the space
    assertTrue(spaceRegistryProxy.registeredSpaceIds(_spaceId));
  }

  function test_RegisterSpaceId_When_typeExists(
    address _account,
    bytes32 _type,
    bytes calldata _version
  ) external whenSpaceIdIsNotRegistered {
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

  function test_RegisterSpaceId_WhenSpaceIdIsRegistered(
    address _account,
    bytes16 _spaceId,
    bytes32 _type,
    bytes calldata _version
  ) external {
    // when spaceId is registered
    vm.assume(_spaceId != bytes16(0));
    _mockAddressToSpaceId(_account, _spaceId);

    // it reverts with SpaceAlreadyRegistered
    vm.expectRevert(ISpaceRegistry.SpaceAlreadyRegistered.selector);

    vm.startPrank(_account);
    spaceRegistryProxy.registerSpaceId(_type, _version);
  }

  function test_ArchiveSpaceId_WhenSpaceIdIsNotRegistered() external whenSpaceIdIsNotRegistered {
    // when spaceId is not registered
    vm.startPrank(_randomCaller);

    // it reverts with SpaceNotRegistered
    vm.expectRevert(ISpaceRegistry.SpaceNotRegistered.selector);
    spaceRegistryProxy.archiveSpaceId();
  }

  modifier whenSpaceIdIsRegistered() {
    // when spaceId is registered
    _mockAddressToSpaceId(_fromSpace, _fromSpaceId);
    _mockSpaceIdToAddress(_fromSpaceId, _fromSpace);
    _;
  }

  function test_ArchiveSpaceId_WhenSpaceIdIsNotArchived() external whenSpaceIdIsRegistered {
    // when spaceId is registered
    vm.startPrank(_fromSpace);

    // when spaceId is not archived
    assertFalse(spaceRegistryProxy.archivedSpaceIds(_fromSpaceId));

    // it emits Action with SPACE_ID_ARCHIVED
    vm.expectEmit();
    emit ISpaceRegistry.Action(
      _fromSpaceId, _fromSpaceId, ActionsConstants.SPACE_ID_ARCHIVED, bytes32(bytes20(_fromSpace)), ''
    );

    spaceRegistryProxy.archiveSpaceId();

    // it sets archivedSpaceIds to true
    assertTrue(spaceRegistryProxy.archivedSpaceIds(_fromSpaceId));
  }

  function test_ArchiveSpaceId_WhenSpaceIdIsArchived() external whenSpaceIdIsRegistered {
    // when spaceId is registered
    _mockArchivedSpaceIds(_fromSpaceId, true);
    vm.startPrank(_fromSpace);

    // when spaceId is archived
    assertTrue(spaceRegistryProxy.archivedSpaceIds(_fromSpaceId));

    // it reverts with SpaceAlreadyArchived
    vm.expectRevert(ISpaceRegistry.SpaceAlreadyArchived.selector);
    spaceRegistryProxy.archiveSpaceId();
  }

  function test_RecoverSpaceId_WhenSpaceIdIsNotRegistered() external whenSpaceIdIsNotRegistered {
    // when spaceId is not registered
    vm.startPrank(_randomCaller);

    // it reverts with SpaceNotRegistered
    vm.expectRevert(ISpaceRegistry.SpaceNotRegistered.selector);
    spaceRegistryProxy.recoverSpaceId();
  }

  function test_RecoverSpaceId_WhenSpaceIdIsArchived() external whenSpaceIdIsRegistered {
    // when spaceId is registered
    _mockArchivedSpaceIds(_fromSpaceId, true);
    vm.startPrank(_fromSpace);

    // when spaceId is archived
    assertTrue(spaceRegistryProxy.archivedSpaceIds(_fromSpaceId));

    // it emits Action with SPACE_ID_RECOVERED
    vm.expectEmit();
    emit ISpaceRegistry.Action(
      _fromSpaceId, _fromSpaceId, ActionsConstants.SPACE_ID_RECOVERED, bytes32(bytes20(_fromSpace)), ''
    );

    spaceRegistryProxy.recoverSpaceId();

    // it sets archivedSpaceIds to false
    assertFalse(spaceRegistryProxy.archivedSpaceIds(_fromSpaceId));
  }

  function test_RecoverSpaceId_WhenSpaceIdIsNotArchived() external whenSpaceIdIsRegistered {
    // when spaceId is registered
    vm.startPrank(_fromSpace);

    // when spaceId is not archived
    assertFalse(spaceRegistryProxy.archivedSpaceIds(_fromSpaceId));

    // it reverts with SpaceNotArchived
    vm.expectRevert(ISpaceRegistry.SpaceNotArchived.selector);
    spaceRegistryProxy.recoverSpaceId();
  }

  function test_ClearSpaceId_WhenSpaceIdIsNotRegistered() external {
    // when spaceId is not registered
    vm.startPrank(_randomCaller);

    // it reverts with SpaceNotRegistered
    vm.expectRevert(ISpaceRegistry.SpaceNotRegistered.selector);

    spaceRegistryProxy.clearSpaceId();
  }

  function test_ClearSpaceId_WhenSpaceIdIsArchived() external whenSpaceIdIsRegistered {
    // when spaceId is registered
    _mockSpaceIdToProposedAddress(_fromSpaceId, _toSpace);
    _mockArchivedSpaceIds(_fromSpaceId, true);
    vm.startPrank(_fromSpace);

    // when spaceId is archived
    assertTrue(spaceRegistryProxy.archivedSpaceIds(_fromSpaceId));

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

    // it resets archivedSpaceIds
    assertFalse(spaceRegistryProxy.archivedSpaceIds(_fromSpaceId));
  }

  function test_ClearSpaceId_WhenSpaceIdIsNotArchived() external whenSpaceIdIsRegistered {
    // when spaceId is registered
    vm.startPrank(_fromSpace);

    // when spaceId is not archived
    assertFalse(spaceRegistryProxy.archivedSpaceIds(_fromSpaceId));

    // it reverts with SpaceNotArchived
    vm.expectRevert(ISpaceRegistry.SpaceNotArchived.selector);

    spaceRegistryProxy.clearSpaceId();
  }

  modifier whenCallerIsSpaceId() {
    // when caller is spaceId
    _;
  }

  function test_ProposeSpaceMigration_WhenSpaceIdIsNotArchived(address _newAccount) external whenCallerIsSpaceId {
    // when caller is spaceId
    _mockAddressToSpaceId(_fromSpace, _fromSpaceId);
    vm.startPrank(_fromSpace);

    // when spaceId is not archived
    assertFalse(spaceRegistryProxy.archivedSpaceIds(_fromSpaceId));

    // it emits Action with SPACE_ID_MIGRATION_PROPOSED
    vm.expectEmit();
    emit ISpaceRegistry.Action(
      _fromSpaceId, _fromSpaceId, ActionsConstants.SPACE_ID_MIGRATION_PROPOSED, bytes32(bytes20(_newAccount)), ''
    );

    spaceRegistryProxy.proposeSpaceMigration(_newAccount);

    // it updates spaceIdToProposedAddress
    assertEq(spaceRegistryProxy.spaceIdToProposedAddress(_fromSpaceId), _newAccount);
  }

  function test_ProposeSpaceMigration_WhenSpaceIdIsArchived(address _newAccount) external whenCallerIsSpaceId {
    // when caller is spaceId
    _mockAddressToSpaceId(_fromSpace, _fromSpaceId);
    _mockSpaceIdToAddress(_fromSpaceId, _fromSpace);
    _mockArchivedSpaceIds(_fromSpaceId, true);
    vm.startPrank(_fromSpace);

    // when spaceId is archived
    assertTrue(spaceRegistryProxy.archivedSpaceIds(_fromSpaceId));

    // it reverts with SpaceAlreadyArchived
    vm.expectRevert(ISpaceRegistry.SpaceAlreadyArchived.selector);

    spaceRegistryProxy.proposeSpaceMigration(_newAccount);
  }

  function test_ProposeSpaceMigration_WhenCallerIsNotSpaceId(address _newAccount) external {
    // when caller is not spaceId
    vm.startPrank(_randomCaller);

    // it reverts with SpaceNotRegistered
    vm.expectRevert(ISpaceRegistry.SpaceNotRegistered.selector);

    spaceRegistryProxy.proposeSpaceMigration(_newAccount);
  }

  modifier whenCallerIsProposedSpaceId() {
    // when caller is proposed spaceId
    _mockAddressToSpaceId(_fromSpace, _fromSpaceId);
    _mockSpaceIdToAddress(_fromSpaceId, _fromSpace);
    _mockSpaceIdToProposedAddress(_fromSpaceId, _toSpace);
    vm.startPrank(_toSpace);
    _;
  }

  modifier whenProposedSpaceIdIsNotRegistered() {
    // when proposed spaceId is not registered
    _;
  }

  modifier whenSpaceIdIsNotArchived() {
    // when spaceId is not archived
    _;
  }

  function test_AcceptSpaceMigration_WhenSpaceIdIsNotArchived()
    external
    whenCallerIsProposedSpaceId
    whenProposedSpaceIdIsNotRegistered
    whenSpaceIdIsNotArchived
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
  ) external whenCallerIsProposedSpaceId whenProposedSpaceIdIsNotRegistered whenSpaceIdIsNotArchived {
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

  function test_AcceptSpaceMigration_WhenSpaceIdIsArchived(
    bytes32 _type,
    bytes calldata _version
  ) external whenCallerIsProposedSpaceId whenProposedSpaceIdIsNotRegistered {
    // when spaceId is archived
    _mockArchivedSpaceIds(_fromSpaceId, true);
    assertTrue(spaceRegistryProxy.archivedSpaceIds(_fromSpaceId));

    // it reverts with SpaceAlreadyArchived
    vm.expectRevert(ISpaceRegistry.SpaceAlreadyArchived.selector);

    spaceRegistryProxy.acceptSpaceMigration(_fromSpaceId, _type, _version);
  }

  function test_AcceptSpaceMigration_WhenProposedSpaceIdIsRegistered(
    bytes32 _type,
    bytes calldata _version
  ) external whenCallerIsProposedSpaceId {
    // when proposed spaceId is registered
    _mockAddressToSpaceId(_toSpace, _toSpaceId);

    // it reverts with SpaceAlreadyRegistered
    vm.expectRevert(ISpaceRegistry.SpaceAlreadyRegistered.selector);

    spaceRegistryProxy.acceptSpaceMigration(_fromSpaceId, _type, _version);
  }

  function test_AcceptSpaceMigration_WhenCallerIsNotProposedSpaceId(
    bytes16 _spaceId,
    bytes32 _type,
    bytes calldata _version
  ) external {
    // when caller is not proposed spaceId
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

    assertFalse(spaceRegistryProxy.permissionlessActions(_action));

    // it emits Action with PERMISSIONLESS_ACTION_ADDED
    vm.expectEmit();
    emit ISpaceRegistry.Action(bytes16(0), bytes16(0), ActionsConstants.PERMISSIONLESS_ACTION_ADDED, _action, '');
    spaceRegistryProxy.setPermissionlessAction(_action, true);

    // it updates the permissionlessActions mapping to add the action
    assertTrue(spaceRegistryProxy.permissionlessActions(_action));
  }

  function test_SetPermissionlessAction_When_setIsFalse() external whenCalledByOwner {
    assertTrue(spaceRegistryProxy.permissionlessActions(ActionsConstants.UPVOTED));

    // it emits Action with PERMISSIONLESS_ACTION_REMOVED
    vm.expectEmit();
    emit ISpaceRegistry.Action(
      bytes16(0), bytes16(0), ActionsConstants.PERMISSIONLESS_ACTION_REMOVED, ActionsConstants.UPVOTED, ''
    );
    spaceRegistryProxy.setPermissionlessAction(ActionsConstants.UPVOTED, false);

    // it updates the permissionlessActions mapping to remove the action
    assertFalse(spaceRegistryProxy.permissionlessActions(ActionsConstants.UPVOTED));
  }

  function test_SetPermissionlessAction_WhenCalledByNon_owner(bytes32 _action, bool _set) external {
    // when called by non-owner
    vm.startPrank(_randomCaller);

    // it reverts with OwnableUnauthorizedAccount
    vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, _randomCaller));
    spaceRegistryProxy.setPermissionlessAction(_action, _set);
  }

  function test_OverrideSpaceId_WhenCalledByOwner(
    address _account,
    bytes16 _oldSpaceId,
    address _proposedRecipient,
    address _vacatedSlotProposedRecipient
  ) external whenCalledByOwner {
    vm.assume(_account != address(0));
    vm.assume(_account != address(spaceRegistryProxy));
    vm.assume(_account != _fromSpace);
    vm.assume(_oldSpaceId != _fromSpaceId);
    vm.assume(_proposedRecipient != address(0));
    vm.assume(_vacatedSlotProposedRecipient != address(0));

    // set initial relationship
    _mockAddressToSpaceId(_fromSpace, _fromSpaceId);
    _mockSpaceIdToAddress(_fromSpaceId, _fromSpace);
    _mockAddressToSpaceId(_account, _oldSpaceId);
    _mockSpaceIdToAddress(_oldSpaceId, _account);
    _mockSpaceIdToProposedAddress(_fromSpaceId, _proposedRecipient);
    _mockArchivedSpaceIds(_fromSpaceId, true);
    _mockSpaceIdToProposedAddress(_oldSpaceId, _vacatedSlotProposedRecipient);
    _mockArchivedSpaceIds(_oldSpaceId, true);

    // it emits Action with SPACE_ID_OVERRIDDEN (_oldSpaceId, _spaceId)
    vm.expectEmit();
    emit ISpaceRegistry.Action(
      _oldSpaceId, _fromSpaceId, ActionsConstants.SPACE_ID_OVERRIDDEN, bytes32(bytes20(_account)), ''
    );

    // when called by owner
    spaceRegistryProxy.overrideSpaceId(_account, _fromSpaceId);

    // it clears old mappings and storage and sets new bi-directional mapping
    assertEq(spaceRegistryProxy.addressToSpaceId(_account), _fromSpaceId);
    assertEq(spaceRegistryProxy.spaceIdToAddress(_fromSpaceId), _account);
    assertEq(spaceRegistryProxy.addressToSpaceId(_fromSpace), bytes16(0));
    assertEq(spaceRegistryProxy.spaceIdToAddress(_oldSpaceId), address(0));
    assertEq(spaceRegistryProxy.spaceIdToProposedAddress(_fromSpaceId), address(0));
    assertFalse(spaceRegistryProxy.archivedSpaceIds(_fromSpaceId));
    assertEq(spaceRegistryProxy.spaceIdToProposedAddress(_oldSpaceId), address(0));
    assertFalse(spaceRegistryProxy.archivedSpaceIds(_oldSpaceId));
  }

  function test_OverrideSpaceId_When_accountIsZeroAddress() external whenCalledByOwner {
    vm.expectRevert(ISpaceRegistry.OverrideZero.selector);
    spaceRegistryProxy.overrideSpaceId(address(0), _fromSpaceId);
  }

  function test_OverrideSpaceId_When_spaceIdIsZero() external whenCalledByOwner {
    vm.expectRevert(ISpaceRegistry.OverrideZero.selector);
    spaceRegistryProxy.overrideSpaceId(_fromSpace, bytes16(0));
  }

  function test_OverrideSpaceId_When_accountIsRegistryAddress() external whenCalledByOwner {
    vm.expectRevert(ISpaceRegistry.InvalidAccount.selector);
    spaceRegistryProxy.overrideSpaceId(address(spaceRegistryProxy), _fromSpaceId);
  }

  function test_OverrideSpaceId_WhenCalledByNon_owner(address _account, bytes16 _spaceId) external {
    // it reverts with OwnableUnauthorizedAccount
    vm.startPrank(_randomCaller);
    vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, _randomCaller));
    spaceRegistryProxy.overrideSpaceId(_account, _spaceId);
  }

  function test_OverrideAction_WhenCalledByOwner() external whenCalledByOwner {
    bytes16[] memory _fromSpaceIds = new bytes16[](3);
    _fromSpaceIds[0] = _fromSpaceId;
    _fromSpaceIds[1] = _fromSpaceId;
    _fromSpaceIds[2] = _fromSpaceId;
    bytes16[] memory _toSpaceIds = new bytes16[](3);
    _toSpaceIds[0] = _toSpaceId;
    _toSpaceIds[1] = _toSpaceId;
    _toSpaceIds[2] = _toSpaceId;
    bytes32[] memory _actions = new bytes32[](3);
    _actions[0] = ActionsConstants.EDITOR_ADDED;
    _actions[1] = ActionsConstants.MEMBER_ADDED;
    _actions[2] = ActionsConstants.EDITS_PUBLISHED;
    bytes32[] memory _subjects = new bytes32[](3);
    _subjects[0] = bytes32(_fromSpaceId);
    _subjects[1] = bytes32(_toSpaceId);
    _subjects[2] = bytes32(0);
    bytes[] memory _datas = new bytes[](3);
    _datas[0] = 'alice';
    _datas[1] = 'bob';
    _datas[2] = 'charlie';

    // it emits Action for each _actions _subjects _datas element
    vm.expectEmit();
    emit ISpaceRegistry.Action(_fromSpaceIds[0], _toSpaceIds[0], _actions[0], _subjects[0], _datas[0]);
    vm.expectEmit();
    emit ISpaceRegistry.Action(_fromSpaceIds[1], _toSpaceIds[1], _actions[1], _subjects[1], _datas[1]);
    vm.expectEmit();
    emit ISpaceRegistry.Action(_fromSpaceIds[2], _toSpaceIds[2], _actions[2], _subjects[2], _datas[2]);

    spaceRegistryProxy.overrideAction(_fromSpaceIds, _toSpaceIds, _actions, _subjects, _datas);
  }

  function test_OverrideAction_WhenActionArraysLengthMismatch() external whenCalledByOwner {
    bytes16[] memory _fromSpaceIds = new bytes16[](1);
    _fromSpaceIds[0] = _fromSpaceId;
    bytes32[] memory _actions = new bytes32[](1);
    _actions[0] = ActionsConstants.EDITOR_ADDED;

    // it reverts with InvalidActionArraysLength
    vm.expectRevert(ISpaceRegistry.InvalidActionArraysLength.selector);
    spaceRegistryProxy.overrideAction(_fromSpaceIds, new bytes16[](0), _actions, new bytes32[](0), new bytes[](0));
  }

  function test_OverrideAction_WhenCalledByNon_owner() external {
    // it reverts with OwnableUnauthorizedAccount
    vm.startPrank(_randomCaller);
    vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, _randomCaller));
    spaceRegistryProxy.overrideAction(
      new bytes16[](0), new bytes16[](0), new bytes32[](0), new bytes32[](0), new bytes[](0)
    );
  }

  function test_RegisteredSpaceIds_WhenCalled(bytes16 _spaceId, address _account) external {
    vm.assume(_spaceId != bytes16(0));
    vm.assume(_account != address(spaceRegistryProxy));
    vm.assume(_account != address(0));

    // when called
    // it returns whether the space ID is registered (has an address mapping)

    // Test when spaceId is not registered
    assertFalse(spaceRegistryProxy.registeredSpaceIds(_spaceId));

    // Test when spaceId is registered
    _mockSpaceIdToAddress(_spaceId, _account);
    assertTrue(spaceRegistryProxy.registeredSpaceIds(_spaceId));
  }

  function test_RegisteredSpaceAddresses_WhenCalled(address _account, bytes16 _spaceId) external {
    vm.assume(_account != address(0));
    vm.assume(_spaceId != bytes16(0));

    // when called
    // it returns whether the address is registered (has a space ID mapping)

    // Test when address is not registered
    assertFalse(spaceRegistryProxy.registeredSpaceAddresses(_account));

    // Test when address is registered
    _mockAddressToSpaceId(_account, _spaceId);
    assertTrue(spaceRegistryProxy.registeredSpaceAddresses(_account));
  }

  function test_ArchivedSpaceIds_WhenCalled(bytes16 _spaceId, address _account) external {
    vm.assume(_spaceId != bytes16(0));
    vm.assume(_account != address(0));

    // when called
    // it returns whether the space ID is archived

    // Test when spaceId is not archived
    _mockAddressToSpaceId(_account, _spaceId);
    _mockSpaceIdToAddress(_spaceId, _account);
    assertFalse(spaceRegistryProxy.archivedSpaceIds(_spaceId));

    // Test when spaceId is archived
    _mockArchivedSpaceIds(_spaceId, true);
    assertTrue(spaceRegistryProxy.archivedSpaceIds(_spaceId));
  }

  function test_ActiveSpaceIds_WhenCalled(bytes16 _spaceId, address _account) external {
    vm.assume(_spaceId != bytes16(0));
    vm.assume(_account != address(0));

    // when called
    // it returns whether the space ID is active (registered and not archived)

    // Test when spaceId is not registered
    assertFalse(spaceRegistryProxy.activeSpaceIds(_spaceId));

    // Test when spaceId is registered but not archived
    _mockAddressToSpaceId(_account, _spaceId);
    _mockSpaceIdToAddress(_spaceId, _account);
    assertTrue(spaceRegistryProxy.activeSpaceIds(_spaceId));

    // Test when spaceId is registered and archived
    _mockArchivedSpaceIds(_spaceId, true);
    assertFalse(spaceRegistryProxy.activeSpaceIds(_spaceId));
  }

  function test_GenerateSpaceId_WhenCalled(address _account, uint256 _nonce) external view {
    bytes16 _id = spaceRegistryProxy.generateSpaceId(_account, _nonce);

    // it returns UUID v4 compliant spaceId (version nibble 4, variant bits 10)
    assertEq(_id, _getSpaceId(_account, _nonce));

    uint256 _idBits = uint256(bytes32(_id));
    // UUID v4: version (0x4) in high nibble of byte 6 (bits 207-200)
    assertEq((_idBits >> 200) & 0xf0, 0x40);
    // UUID v4: variant (10) in high 2 bits of byte 8 (bits 191-184)
    assertEq((_idBits >> 184) & 0xc0, 0x80);
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

  function test_SetPaymentManager_WhenCalledByOwner() external {
    vm.expectEmit();
    emit ISpaceRegistry.Action(
      bytes16(0), bytes16(0), ActionsConstants.PAYMENT_MANAGER_SET, bytes32(bytes20(_paymentManager)), ''
    );

    vm.prank(_owner);
    spaceRegistryProxy.setPaymentManager(_paymentManager);

    // it sets paymentManager
    assertEq(spaceRegistryProxy.paymentManager(), _paymentManager);
  }

  function test_SetPaymentManager_WhenCalledByNon_owner() external {
    vm.prank(_randomCaller);
    vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, _randomCaller));
    spaceRegistryProxy.setPaymentManager(_paymentManager);
  }

  function test_SetL2IncentivesPayer_WhenCallerIsActiveRegisteredSpace() external {
    _mockAddressToSpaceId(_incentivesSpace, _incentivesSpaceId);
    _mockSpaceIdToAddress(_incentivesSpaceId, _incentivesSpace);

    _mockPaymentManager(_paymentManager);

    bytes32 _targetId = bytes32(_incentivesSpaceId);
    bytes memory _calldataForL2 = abi.encodeCall(IPaymentManager.setPayer, (_targetId, _incentivesPayer));

    vm.mockCall(
      _ARB_SYS, abi.encodeCall(IArbSys.sendTxToL1, (_paymentManager, _calldataForL2)), abi.encode(uint256(42))
    );

    vm.expectEmit();
    emit ISpaceRegistry.Action(
      _incentivesSpaceId,
      _incentivesSpaceId,
      ActionsConstants.L2_INCENTIVES_PAYER_ENQUEUED,
      _targetId,
      abi.encode(_incentivesPayer, uint256(42))
    );

    vm.prank(_incentivesSpace);
    spaceRegistryProxy.setL2IncentivesPayer(_incentivesPayer);
  }

  function test_SetL2IncentivesPayer_WhenCallerIsNotRegistered() external {
    _mockPaymentManager(_paymentManager);

    vm.prank(_incentivesSpace);
    vm.expectRevert(ISpaceRegistry.SpaceNotActive.selector);
    spaceRegistryProxy.setL2IncentivesPayer(_incentivesPayer);
  }

  function test_SetL2IncentivesPayer_WhenCallerIsArchived() external {
    _mockAddressToSpaceId(_incentivesSpace, _incentivesSpaceId);
    _mockSpaceIdToAddress(_incentivesSpaceId, _incentivesSpace);
    _mockArchivedSpaceIds(_incentivesSpaceId, true);

    _mockPaymentManager(_paymentManager);

    vm.prank(_incentivesSpace);
    vm.expectRevert(ISpaceRegistry.SpaceNotActive.selector);
    spaceRegistryProxy.setL2IncentivesPayer(_incentivesPayer);
  }

  function test_SetL2IncentivesPayer_WhenPaymentManagerIsNotSet() external {
    _mockAddressToSpaceId(_incentivesSpace, _incentivesSpaceId);
    _mockSpaceIdToAddress(_incentivesSpaceId, _incentivesSpace);

    vm.prank(_incentivesSpace);
    vm.expectRevert(ISpaceRegistry.PaymentManagerNotSet.selector);
    spaceRegistryProxy.setL2IncentivesPayer(_incentivesPayer);
  }

  function test_SetL2IncentivesPayer_WhenPayerIsZeroAddress() external {
    _mockAddressToSpaceId(_incentivesSpace, _incentivesSpaceId);
    _mockSpaceIdToAddress(_incentivesSpaceId, _incentivesSpace);

    _mockPaymentManager(_paymentManager);

    vm.prank(_incentivesSpace);
    vm.expectRevert(ISpaceRegistry.InvalidPayer.selector);
    spaceRegistryProxy.setL2IncentivesPayer(address(0));
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

  function _mockArchivedSpaceIds(bytes16 _spaceId, bool _isArchived) internal {
    spaceRegistryProxy.workaround_setArchivedSpaceIds(_spaceId, _isArchived);
  }

  function _mockPaymentManager(address _paymentManager) internal {
    spaceRegistryProxy.workaround_setPaymentManager(_paymentManager);
  }

  function _mockFetch(
    address __toSpace,
    bytes32 _action,
    bytes32 _subjectInput,
    bytes calldata _data,
    bytes32 _subjectOutput
  ) internal {
    _mockAndExpect(__toSpace, abi.encodeCall(ISpace.fetch, (_action, _subjectInput, _data)), abi.encode(_subjectOutput));
  }

  function _mockVerify(
    address __fromSpace,
    address _sender,
    bytes16 __toSpaceId,
    bytes32 _action,
    bytes32 _subject,
    bytes calldata _data,
    bytes calldata _signature
  ) internal {
    _mockAndExpect(
      __fromSpace,
      abi.encodeCall(ISpace.verify, (_sender, __toSpaceId, _action, _subject, _data, _signature)),
      abi.encode()
    );
  }

  function _mockWrite(
    address __toSpace,
    bytes16 __fromSpaceId,
    bytes32 _action,
    bytes32 _subject,
    bytes calldata _data
  ) internal {
    _mockAndExpect(__toSpace, abi.encodeCall(ISpace.write, (__fromSpaceId, _action, _subject, _data)), abi.encode());
  }

  function _whenActionIsNotPermissionless(bytes32 _action) internal pure {
    vm.assume(_action != ActionsConstants.UPVOTED);
    vm.assume(_action != ActionsConstants.DOWNVOTED);
    vm.assume(_action != ActionsConstants.UNVOTED);
    vm.assume(_action != ActionsConstants.COMMENTED);
  }

  function _permissionlessActionFromIndex(uint8 _permissionlessActionIndex) internal pure returns (bytes32 _action) {
    uint256 _index = bound(_permissionlessActionIndex, 0, 3);
    if (_index == 0) _action = ActionsConstants.UPVOTED;
    else if (_index == 1) _action = ActionsConstants.DOWNVOTED;
    else if (_index == 2) _action = ActionsConstants.UNVOTED;
    else _action = ActionsConstants.COMMENTED;
  }

  function _getSpaceId(address _account, uint256 _nonce) internal view returns (bytes16 _spaceId) {
    bytes32 _hash = keccak256(abi.encodePacked('grc20.space', _account, _nonce, block.chainid));
    _hash = _hash & ~(bytes32(uint256(0xf0)) << 200) | (bytes32(uint256(0x40)) << 200);
    _spaceId = bytes16(_hash & ~(bytes32(uint256(0xc0)) << 184) | (bytes32(uint256(0x80)) << 184));
  }
}
