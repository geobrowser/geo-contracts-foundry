// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

import {Test} from 'forge-std/Test.sol';

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';

import {ISpace} from 'interfaces/ISpace.sol';
import {ISpaceRegistry} from 'interfaces/registry/ISpaceRegistry.sol';
import {MockSpaceRegistry} from 'mocks/MockSpaceRegistry.sol';

contract UnitSpaceRegistry is Test {
  MockSpaceRegistry public spaceRegistry;
  MockSpaceRegistry public spaceRegistryProxy;

  address internal _owner = makeAddr('_owner');

  address internal _fromSpace = makeAddr('_fromSpace');
  address internal _toSpace = makeAddr('_toSpace');

  bytes16 internal _fromSpaceId = bytes16(keccak256('_fromSpaceId'));
  bytes16 internal _toSpaceId = bytes16(keccak256('_toSpaceId'));

  bytes32 internal _action = keccak256('_action');
  bytes32 internal _topic = keccak256('_topic');

  event Initialized(uint8 version);
  event Ping(
    bytes16 indexed fromId, bytes16 indexed toId, bytes32 indexed action, bytes32 indexed topic, bytes data
  ) anonymous;

  function setUp() external {
    vm.etch(_fromSpace, '_fromSpace');
    vm.etch(_toSpace, '_toSpace');

    // when deployed
    spaceRegistry = new MockSpaceRegistry();
    // when delegate called
    spaceRegistryProxy = MockSpaceRegistry(
      address(new ERC1967Proxy(address(spaceRegistry), abi.encodeCall(ISpaceRegistry.initialize, (_owner))))
    );
  }

  function test_Constructor_WhenCalled() external {
    // it disables initializers
    vm.expectEmit();
    emit Initialized(type(uint8).max);

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
      address(new ERC1967Proxy(address(spaceRegistry), abi.encodeCall(ISpaceRegistry.initialize, (__owner))))
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
      address(new ERC1967Proxy(address(spaceRegistry), abi.encodeCall(ISpaceRegistry.initialize, (__owner))))
    );

    // it reverts with InitializableContractIsAlreadyInitialized
    vm.expectRevert('Initializable: contract is already initialized');

    // when delegate called again
    spaceRegistryProxy.initialize(__owner);
  }

  function test_Initialize_WhenOwnerIsZeroAddress() external whenDelegateCalled {
    // when owner is zero address
    address __owner = address(0);

    // it reverts with InvalidZeroAddress
    vm.expectRevert(ISpaceRegistry.InvalidZeroAddress.selector);

    // when delegate called
    spaceRegistryProxy = MockSpaceRegistry(
      address(new ERC1967Proxy(address(spaceRegistry), abi.encodeCall(ISpaceRegistry.initialize, (__owner))))
    );
  }

  function test_Initialize_WhenCalled() external {
    // it reverts with InitializableContractIsAlreadyInitialized
    vm.expectRevert('Initializable: contract is already initialized');

    // when called
    spaceRegistry.initialize(_owner);
  }

  modifier whenSpacesAreRegistered() {
    // when spaces are registered
    _mockAddressToSpaceId(_fromSpace, _fromSpaceId);
    _mockAddressToSpaceId(_toSpace, _toSpaceId);
    _;
  }

  function test_Enter_WhenSpacesAreRegistered(
    bytes calldata _data,
    bytes calldata _signature
  ) external whenSpacesAreRegistered {
    // it emits Ping
    vm.expectEmit();
    emit Ping(_fromSpaceId, _toSpaceId, _action, _topic, _data);

    spaceRegistryProxy.enter(_fromSpace, _toSpace, _action, _topic, _data, _signature);
  }

  function test_Enter_WhenCallerIsNotFromSpace(
    bytes calldata _data,
    bytes calldata _signature,
    address _caller
  ) external whenSpacesAreRegistered {
    // when caller is not fromSpace
    vm.assume(_caller != _fromSpace);
    vm.startPrank(_caller);

    // it calls fromSpace to verify
    _mockVerify(_toSpace, _action, _topic, _data, _signature);

    spaceRegistryProxy.enter(_fromSpace, _toSpace, _action, _topic, _data, _signature);
  }

  function test_Enter_WhenCallerIsNotToSpace(
    bytes calldata _data,
    bytes calldata _signature,
    address _caller
  ) external whenSpacesAreRegistered {
    // when caller is not toSpace
    vm.assume(_caller != _toSpace);
    vm.startPrank(_caller);

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

    spaceRegistryProxy.registerSpaceId(_account);

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

    spaceRegistryProxy.registerSpaceId(_account);
  }

  modifier whenCallerIsMigratingSpace() {
    // when caller is migrating space
    vm.startPrank(_fromSpace);
    _mockAddressToSpaceId(_fromSpace, _fromSpaceId);
    _;
  }

  function test_MigrateSpaceAddress_WhenNewSpaceAddressIsNotRegistered(
    address _newAccount,
    address _caller
  ) external whenCallerIsMigratingSpace {
    // when new space address is not registered
    vm.assume(_newAccount != _fromSpace);

    spaceRegistryProxy.migrateSpaceAddress(_newAccount);

    // it updates spaceIdToAddress
    assertEq(spaceRegistryProxy.spaceIdToAddress(_fromSpaceId), _newAccount);
    // it updates addressToSpaceId
    assertEq(spaceRegistryProxy.addressToSpaceId(_newAccount), _fromSpaceId);
  }

  function test_MigrateSpaceAddress_WhenNewSpaceAddressIsRegistered(
    address _newAccount,
    bytes16 _spaceId
  ) external whenCallerIsMigratingSpace {
    // when new space address is registered
    vm.assume(_spaceId != bytes16(0));
    _mockAddressToSpaceId(_newAccount, _spaceId);

    // it reverts with SpaceAlreadyRegistered
    vm.expectRevert(ISpaceRegistry.SpaceAlreadyRegistered.selector);

    spaceRegistryProxy.migrateSpaceAddress(_newAccount);
  }

  function test_MigrateSpaceAddress_WhenCallerIsNotMigratingSpace(address _newAccount, address _caller) external {
    // when caller is not migrating space
    vm.startPrank(_caller);

    // it reverts with InvalidCaller
    vm.expectRevert(ISpaceRegistry.InvalidCaller.selector);

    spaceRegistryProxy.migrateSpaceAddress(_newAccount);
  }

  function test_GenerateSpaceId_WhenCalled(address _account, uint256 _nonce) external {
    bytes16 _spaceId = bytes16(keccak256(abi.encodePacked('grc20.space', _account, _nonce, block.chainid)));

    // it returns spaceId
    assertEq(spaceRegistryProxy.generateSpaceId(_account, _nonce), _spaceId);
  }

  function test_Version_WhenCalled() external {
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

  function test__authorizeUpgrade_WhenCalledByNon_owner(address _newImplementation, address _caller) external {
    // when called by non-owner
    vm.assume(_caller != _owner);
    vm.startPrank(_caller);

    // it reverts with OwnableCallerIsNotTheOwner
    vm.expectRevert('Ownable: caller is not the owner');

    spaceRegistryProxy.exposed__authorizeUpgrade(_newImplementation);
  }

  function _mockAddressToSpaceId(address _account, bytes16 _spaceId) internal {
    spaceRegistryProxy.workaround_setAddressToSpaceId(_account, _spaceId);
  }

  function _mockVerify(
    address _space,
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data,
    bytes calldata _signature
  ) internal {
    vm.expectCall(_fromSpace, abi.encodeCall(ISpace.verify, (_space, _action, _topic, _data, _signature)), 1);
  }

  function _mockWrite(address _space, bytes32 _action, bytes32 _topic, bytes calldata _data) internal {
    vm.expectCall(_toSpace, abi.encodeCall(ISpace.write, (_space, _action, _topic, _data)), 1);
  }
}
