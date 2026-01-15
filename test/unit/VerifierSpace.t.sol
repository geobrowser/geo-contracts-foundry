// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {TestHelper} from 'test/unit/helpers/TestHelper.t.sol';

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {UnsafeUpgrades} from '@openzeppelin/foundry-upgrades/Upgrades.sol';

import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';
import {IVerifierSpace} from 'interfaces/IVerifierSpace.sol';
import {MockVerifierSpace} from 'test/unit/mocks/MockVerifierSpace.sol';

contract UnitVerifierSpace is TestHelper {
  MockVerifierSpace public verifierSpaceImplementation;
  MockVerifierSpace public verifierSpaceProxy;
  address public verifierSpaceBeacon;

  address internal _owner;
  uint256 internal _ownerPrivateKey;
  address internal _randomCaller = makeAddr('_randomCaller');
  bytes32 internal _spaceType;
  bytes internal _spaceVersion;

  ISpaceRegistry internal _spaceRegistry = ISpaceRegistry(makeAddr('_spaceRegistry'));
  bytes16 internal _fromSpaceId = bytes16(keccak256('_fromSpaceId'));
  bytes16 internal _toSpaceId = bytes16(keccak256('_toSpaceId'));

  function setUp() external {
    (_owner, _ownerPrivateKey) = makeAddrAndKey('_owner');

    // when deployed
    verifierSpaceImplementation = new MockVerifierSpace();
    verifierSpaceBeacon = UnsafeUpgrades.deployBeacon(address(verifierSpaceImplementation), _owner);

    // And the space type and version
    _spaceType = keccak256(bytes(verifierSpaceImplementation.name()));
    _spaceVersion = abi.encode(verifierSpaceImplementation.version());

    // Get predicted Verifier Space proxy address
    address predictedVerifierSpaceProxy = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
    bytes16 predictedVerifierSpaceProxySpaceId = _getSpaceId(predictedVerifierSpaceProxy);

    // mock the space registration
    _mockRegisterSpaceId(_spaceRegistry, _spaceType, _spaceVersion, predictedVerifierSpaceProxySpaceId);

    // mock mapping fetch with ping
    _mockAddressToSpaceId(_spaceRegistry, _owner, _getSpaceId(_owner));

    // when delegate called
    verifierSpaceProxy = MockVerifierSpace(
      UnsafeUpgrades.deployBeaconProxy(
        verifierSpaceBeacon, abi.encodeCall(IVerifierSpace.initialize, (abi.encode(_spaceRegistry, _owner)))
      )
    );
  }

  function test_Constants_WhenDeployed() external view {
    // it sets the MESSAGE_TYPEHASH to keccak256('Message(bytes16 toSpaceId,bytes32 action,bytes32 topic,uint256 nonce,bytes data)')
    assertEq(
      verifierSpaceProxy.MESSAGE_TYPEHASH(),
      keccak256('Message(bytes16 toSpaceId,bytes32 action,bytes32 topic,uint256 nonce,bytes data)')
    );

    // it sets _VERIFIER_SPACE_STORAGE_LOCATION to keccak256(abi.encode(uint256(keccak256("geo.storage.VerifierSpace")) - 1)) & ~bytes32(uint256(0xff))
    assertEq(
      verifierSpaceProxy.exposed__VERIFIER_SPACE_STORAGE_LOCATION(),
      keccak256(abi.encode(uint256(keccak256('geo.storage.VerifierSpace')) - 1)) & ~bytes32(uint256(0xff))
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
    ISpaceRegistry __spaceRegistry,
    address __owner
  ) external whenDelegateCalled whenOwnerIsNotZeroAddress(__owner) {
    _assumeFuzzable(address(__spaceRegistry));

    // Get predicted Verifier Space proxy address
    address predictedVerifierSpaceProxy = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
    bytes16 predictedVerifierSpaceProxySpaceId = _getSpaceId(predictedVerifierSpaceProxy);

    // it calls spaceRegistry to register space ID
    _mockRegisterSpaceId(__spaceRegistry, _spaceType, _spaceVersion, predictedVerifierSpaceProxySpaceId);

    // mock mapping fetch with ping
    _mockAddressToSpaceId(__spaceRegistry, __owner, _getSpaceId(__owner));

    // when delegate called
    verifierSpaceProxy = MockVerifierSpace(
      UnsafeUpgrades.deployUUPSProxy(
        address(verifierSpaceImplementation),
        abi.encodeCall(IVerifierSpace.initialize, (abi.encode(__spaceRegistry, __owner)))
      )
    );

    // it sets owner
    assertEq(verifierSpaceProxy.owner(), __owner);

    // it initializes EIP712
    assertEq(verifierSpaceProxy.exposed__EIP712NameHash(), keccak256('VERIFIER_SPACE'));
    assertEq(verifierSpaceProxy.exposed__EIP712VersionHash(), keccak256(bytes(verifierSpaceProxy.version())));

    // it sets spaceRegistry
    assertEq(address(verifierSpaceProxy.spaceRegistry()), address(__spaceRegistry));

    // it sets validWriters
    bytes16 ownerSpaceId = _getSpaceId(__owner);
    bytes16 verifierSpaceProxySpaceId = _getSpaceId(address(verifierSpaceProxy));
    assertTrue(verifierSpaceProxy.validWriters(ownerSpaceId));
    assertTrue(verifierSpaceProxy.validWriters(verifierSpaceProxySpaceId));
  }

  function test_Initialize_WhenDelegateCalledAgain(
    ISpaceRegistry __spaceRegistry,
    address __owner
  ) external whenDelegateCalled whenOwnerIsNotZeroAddress(__owner) {
    _assumeFuzzable(address(__spaceRegistry));

    // Get predicted Verifier Space proxy address
    address predictedVerifierSpaceProxy = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
    bytes16 predictedVerifierSpaceProxySpaceId = _getSpaceId(predictedVerifierSpaceProxy);

    // mock the space registration
    _mockRegisterSpaceId(__spaceRegistry, _spaceType, _spaceVersion, predictedVerifierSpaceProxySpaceId);

    // mock mapping fetch with ping
    _mockAddressToSpaceId(__spaceRegistry, __owner, _getSpaceId(__owner));

    // when delegate called
    verifierSpaceProxy = MockVerifierSpace(
      UnsafeUpgrades.deployUUPSProxy(
        address(verifierSpaceImplementation),
        abi.encodeCall(IVerifierSpace.initialize, (abi.encode(__spaceRegistry, __owner)))
      )
    );

    // it reverts with InvalidInitialization
    vm.expectRevert(Initializable.InvalidInitialization.selector);

    // when delegate called again
    verifierSpaceProxy.initialize(abi.encode(__spaceRegistry, __owner));
  }

  function test_Initialize_WhenOwnerIsZeroAddress() external whenDelegateCalled {
    // when owner is zero address
    address __owner = address(0);

    // it reverts with OwnableInvalidOwner
    vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, __owner));

    // when delegate called
    verifierSpaceProxy = MockVerifierSpace(
      UnsafeUpgrades.deployUUPSProxy(
        address(verifierSpaceImplementation),
        abi.encodeCall(IVerifierSpace.initialize, (abi.encode(_spaceRegistry, __owner)))
      )
    );
  }

  function test_Initialize_WhenCalled(ISpaceRegistry __spaceRegistry, address __owner) external {
    // it reverts with InvalidInitialization
    vm.expectRevert(Initializable.InvalidInitialization.selector);

    // when called
    verifierSpaceImplementation.initialize(abi.encode(__spaceRegistry, __owner));
  }

  function test_SetValidWriters_WhenCalledByOwner(bytes16 _accountSpaceId, bool _valid) external {
    // when called by owner
    vm.startPrank(_owner);

    // it emits ValidWriterSet
    vm.expectEmit();
    emit IVerifierSpace.ValidWriterSet(_accountSpaceId, _valid);

    verifierSpaceProxy.setValidWriters(_accountSpaceId, _valid);

    // it updates validWriters
    assertEq(verifierSpaceProxy.validWriters(_accountSpaceId), _valid);
  }

  function test_SetValidWriters_WhenCalledByNon_owner(bytes16 _accountSpaceId, bool _valid) external {
    // when called by non-owner
    vm.startPrank(_randomCaller);

    // it reverts with OwnableUnauthorizedAccount
    vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, _randomCaller));

    verifierSpaceProxy.setValidWriters(_accountSpaceId, _valid);
  }

  modifier whenCallerIsSpaceRegistry() {
    vm.startPrank(address(_spaceRegistry));
    _;
  }

  function test_Verify_WhenSignatureIsValid(
    address _sender,
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data
  ) external whenCallerIsSpaceRegistry {
    // when signature is valid
    uint256 _replayNonce = verifierSpaceProxy.replayNonce();

    // struct hash
    bytes32 structHash = keccak256(
      abi.encode(verifierSpaceProxy.MESSAGE_TYPEHASH(), _toSpaceId, _action, _topic, _replayNonce, keccak256(_data))
    );
    // domain separator
    bytes32 domainSeparator = keccak256(
      abi.encode(
        keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
        keccak256(bytes('VERIFIER_SPACE')),
        keccak256(bytes(verifierSpaceProxy.version())),
        block.chainid,
        address(verifierSpaceProxy)
      )
    );
    // digest
    bytes32 digest = keccak256(abi.encodePacked('\x19\x01', domainSeparator, structHash));

    // signature
    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(_ownerPrivateKey, digest);
    bytes memory _signature = abi.encodePacked(_r, _s, _v);
    verifierSpaceProxy.verify(_sender, _toSpaceId, _action, _topic, _data, _signature);

    // it increments replayNonce
    assertEq(verifierSpaceProxy.replayNonce(), _replayNonce + 1);
  }

  function test_Verify_WhenSignatureIsNotValid(
    address _sender,
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data,
    bytes calldata _signature
  ) external whenCallerIsSpaceRegistry {
    // when signature is not valid

    // it reverts with InvalidSignature
    vm.expectRevert(IVerifierSpace.InvalidSignature.selector);

    verifierSpaceProxy.verify(_sender, _toSpaceId, _action, _topic, _data, _signature);
  }

  function test_Verify_WhenCallerIsNotSpaceRegistry(
    address _sender,
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data,
    bytes calldata _signature
  ) external {
    // when caller is not spaceRegistry
    vm.startPrank(_randomCaller);

    // it reverts with InvalidCaller
    vm.expectRevert(IVerifierSpace.InvalidCaller.selector);

    verifierSpaceProxy.verify(_sender, _toSpaceId, _action, _topic, _data, _signature);
  }

  function test_Write_WhenWriterIsValid(
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data
  ) external whenCallerIsSpaceRegistry {
    // when writer is valid
    _mockValidWriters(_fromSpaceId, true);

    // it does not revert
    verifierSpaceProxy.write(_fromSpaceId, _action, _topic, _data);
  }

  function test_Write_WhenWriterIsNotValid(
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data
  ) external whenCallerIsSpaceRegistry {
    // when writer is not valid

    // it reverts with InvalidWriter
    vm.expectRevert(IVerifierSpace.InvalidWriter.selector);

    verifierSpaceProxy.write(_fromSpaceId, _action, _topic, _data);
  }

  function test_Write_WhenCallerIsNotSpaceRegistry(bytes32 _action, bytes32 _topic, bytes calldata _data) external {
    // when caller is not spaceRegistry
    vm.startPrank(_randomCaller);

    // it reverts with InvalidCaller
    vm.expectRevert(IVerifierSpace.InvalidCaller.selector);

    verifierSpaceProxy.write(_fromSpaceId, _action, _topic, _data);
  }

  function test_Fetch_WhenCalled(bytes32 _action, bytes32 _topicInput, bytes calldata _data) external view {
    // when called

    // it returns _topicInput
    assertEq(verifierSpaceProxy.fetch(_action, _topicInput, _data), _topicInput);
  }

  function test_TypeId_WhenCalled() external view {
    // when called

    // it returns the type
    assertEq(verifierSpaceProxy.typeId(), keccak256(bytes('VERIFIER_SPACE')));
  }

  function test_Name_WhenCalled() external view {
    // when called

    // it returns the name
    assertEq(verifierSpaceProxy.name(), 'VERIFIER_SPACE');
  }

  function test_Version_WhenCalled() external view {
    // when called

    // it returns semantic version
    assertEq(verifierSpaceProxy.version(), '1.0.0');
  }

  function _mockValidWriters(bytes16 _spaceId, bool _valid) internal {
    verifierSpaceProxy.workaround_setValidWriters(_spaceId, _valid);
  }

  function _mockAddressToSpaceId(ISpaceRegistry __spaceRegistry, address __account, bytes16 __spaceId) internal {
    _mockAndExpect(
      address(__spaceRegistry), abi.encodeCall(ISpaceRegistry.addressToSpaceId, (__account)), abi.encode(__spaceId)
    );
  }

  function _getSpaceId(address _account) internal view returns (bytes16 _spaceId) {
    return bytes16(keccak256(abi.encodePacked('grc20.space', _account, uint256(0), block.chainid)));
  }

  function _mockRegisterSpaceId(
    ISpaceRegistry __spaceRegistry,
    bytes32 __spaceType,
    bytes memory __spaceVersion,
    bytes16 __spaceId
  ) internal {
    _mockAndExpect(
      address(__spaceRegistry),
      abi.encodeCall(ISpaceRegistry.registerSpaceId, (__spaceType, __spaceVersion)),
      abi.encode(__spaceId)
    );
  }
}
