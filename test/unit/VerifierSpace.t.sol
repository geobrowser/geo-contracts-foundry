// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {TestHelper} from 'test/unit/helpers/TestHelper.t.sol';

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {UnsafeUpgrades} from '@openzeppelin/foundry-upgrades/Upgrades.sol';

import {IVerifierSpace} from 'interfaces/IVerifierSpace.sol';
import {MockVerifierSpace} from 'mocks/MockVerifierSpace.sol';

contract UnitVerifierSpace is TestHelper {
  MockVerifierSpace public verifierSpaceImplementation;
  MockVerifierSpace public verifierSpaceProxy;
  address public verifierSpaceBeacon;

  address internal _owner;
  uint256 internal _ownerPrivateKey;
  address internal _randomCaller = makeAddr('_randomCaller');

  address internal _spaceRegistry = makeAddr('_spaceRegistry');
  address internal _fromSpace = makeAddr('_fromSpace');
  address internal _toSpace = makeAddr('_toSpace');

  function setUp() external {
    (_owner, _ownerPrivateKey) = makeAddrAndKey('_owner');

    // when deployed
    verifierSpaceImplementation = new MockVerifierSpace();
    verifierSpaceBeacon = UnsafeUpgrades.deployBeacon(address(verifierSpaceImplementation), _owner);
    // when delegate called
    verifierSpaceProxy = MockVerifierSpace(
      UnsafeUpgrades.deployBeaconProxy(
        verifierSpaceBeacon, abi.encodeCall(IVerifierSpace.initialize, (_spaceRegistry, _owner))
      )
    );
  }

  function test_Constructor_WhenCalled() external {
    // it disables initializers
    vm.expectEmit();
    emit Initializable.Initialized(type(uint64).max);

    // when called
    new MockVerifierSpace();
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

  function test_Initialize_WhenOwnerIsNotZeroAddress(
    address __spaceRegistry,
    address __owner
  ) external whenDelegateCalled whenOwnerIsNotZeroAddress(__owner) {
    // when delegate called
    verifierSpaceProxy = MockVerifierSpace(
      UnsafeUpgrades.deployUUPSProxy(
        address(verifierSpaceImplementation), abi.encodeCall(IVerifierSpace.initialize, (__spaceRegistry, __owner))
      )
    );

    // it sets owner
    assertEq(verifierSpaceProxy.owner(), __owner);

    // it sets spaceRegistry
    assertEq(verifierSpaceProxy.spaceRegistry(), __spaceRegistry);

    // it sets validWriters
    assertEq(verifierSpaceProxy.validWriters(__owner), true);
    assertEq(verifierSpaceProxy.validWriters(address(verifierSpaceProxy)), true);
  }

  function test_Initialize_WhenDelegateCalledAgain(
    address __spaceRegistry,
    address __owner
  ) external whenDelegateCalled whenOwnerIsNotZeroAddress(__owner) {
    // when delegate called
    verifierSpaceProxy = MockVerifierSpace(
      UnsafeUpgrades.deployUUPSProxy(
        address(verifierSpaceImplementation), abi.encodeCall(IVerifierSpace.initialize, (__spaceRegistry, __owner))
      )
    );

    // it reverts with InvalidInitialization
    vm.expectRevert(Initializable.InvalidInitialization.selector);

    // when delegate called again
    verifierSpaceProxy.initialize(__spaceRegistry, __owner);
  }

  function test_Initialize_WhenOwnerIsZeroAddress() external whenDelegateCalled {
    // when owner is zero address
    address __owner = address(0);

    // it reverts with OwnableInvalidOwner
    vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, __owner));

    // when delegate called
    verifierSpaceProxy = MockVerifierSpace(
      UnsafeUpgrades.deployUUPSProxy(
        address(verifierSpaceImplementation), abi.encodeCall(IVerifierSpace.initialize, (_spaceRegistry, __owner))
      )
    );
  }

  function test_Initialize_WhenCalled(address __spaceRegistry, address __owner) external {
    // it reverts with InvalidInitialization
    vm.expectRevert(Initializable.InvalidInitialization.selector);

    // when called
    verifierSpaceImplementation.initialize(__spaceRegistry, __owner);
  }

  function test_SetValidWriters_WhenCalledByOwner(address _account, bool _valid) external {
    // when called by owner
    vm.startPrank(_owner);

    // it emits ValidWriterSet
    vm.expectEmit();
    emit IVerifierSpace.ValidWriterSet(_account, _valid);

    verifierSpaceProxy.setValidWriters(_account, _valid);

    // it updates validWriters
    assertEq(verifierSpaceProxy.validWriters(_account), _valid);
  }

  function test_SetValidWriters_WhenCalledByNon_owner(address _account, bool _valid) external {
    // when called by non-owner
    vm.startPrank(_randomCaller);

    // it reverts with OwnableUnauthorizedAccount
    vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, _randomCaller));

    verifierSpaceProxy.setValidWriters(_account, _valid);
  }

  function test_Verify_WhenSignatureIsValid(bytes32 _action, bytes32 _topic, bytes calldata _data) external {
    // when signature is valid
    uint256 _replayNonce = verifierSpaceProxy.replayNonce();
    bytes32 _messageHash =
      keccak256(abi.encodePacked(_toSpace, _action, _topic, _data, _replayNonce, verifierSpaceProxy));
    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(_ownerPrivateKey, _messageHash);
    bytes memory _signature = abi.encodePacked(_r, _s, _v);

    verifierSpaceProxy.verify(_toSpace, _action, _topic, _data, _signature);

    // it increments replayNonce
    assertEq(verifierSpaceProxy.replayNonce(), _replayNonce + 1);
  }

  function test_Verify_WhenSignatureIsNotValid(
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data,
    bytes calldata _signature
  ) external {
    // when signature is not valid

    // it reverts with InvalidSignature
    vm.expectRevert(IVerifierSpace.InvalidSignature.selector);

    verifierSpaceProxy.verify(_toSpace, _action, _topic, _data, _signature);
  }

  modifier whenCallerIsSpaceRegistry() {
    vm.startPrank(_spaceRegistry);
    _;
  }

  function test_Write_WhenWriterIsValid(
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data
  ) external whenCallerIsSpaceRegistry {
    // when writer is valid
    _mockValidWriters(_fromSpace, true);

    // it does not revert
    verifierSpaceProxy.write(_fromSpace, _action, _topic, _data);
  }

  function test_Write_WhenWriterIsNotValid(
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data
  ) external whenCallerIsSpaceRegistry {
    // when writer is not valid

    // it reverts with InvalidWriter
    vm.expectRevert(IVerifierSpace.InvalidWriter.selector);

    verifierSpaceProxy.write(_fromSpace, _action, _topic, _data);
  }

  function test_Write_WhenCallerIsNotSpaceRegistry(bytes32 _action, bytes32 _topic, bytes calldata _data) external {
    // when caller is not spaceRegistry
    vm.startPrank(_randomCaller);

    // it reverts with InvalidCaller
    vm.expectRevert(IVerifierSpace.InvalidCaller.selector);

    verifierSpaceProxy.write(_fromSpace, _action, _topic, _data);
  }

  function test_Fetch_WhenCalled(bytes32 _action, bytes32 _topicInput) external view {
    // when called

    // it returns _topicInput
    assertEq(verifierSpaceProxy.fetch(_action, _topicInput), _topicInput);
  }

  function test_Version_WhenCalled() external view {
    // when called

    // it returns semantic version
    assertEq(verifierSpaceProxy.version(), '1.0.0');
  }

  function _mockValidWriters(address _account, bool _valid) internal {
    verifierSpaceProxy.workaround_setValidWriters(_account, _valid);
  }
}
