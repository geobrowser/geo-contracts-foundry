// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {TestHelper} from 'test/unit/helpers/TestHelper.t.sol';

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {ERC1967Utils} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol';
import {UpgradeableBeacon} from '@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol';
import {UnsafeUpgrades} from '@openzeppelin/foundry-upgrades/Upgrades.sol';

import {VerifierSpace} from 'contracts/VerifierSpace.sol';
import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';
import {IVerifierSpaceFactory} from 'interfaces/IVerifierSpaceFactory.sol';
import {MockVerifierSpaceFactory} from 'test/unit/mocks/MockVerifierSpaceFactory.sol';

contract UnitVerifierSpaceFactory is TestHelper {
  MockVerifierSpaceFactory public verifierSpaceFactoryImplementation;
  MockVerifierSpaceFactory public verifierSpaceFactoryProxy;

  address internal _owner = makeAddr('_owner');
  address internal _randomCaller = makeAddr('_randomCaller');

  ISpaceRegistry internal _spaceRegistry = ISpaceRegistry(makeAddr('_spaceRegistry'));

  function setUp() external {
    // when deployed
    verifierSpaceFactoryImplementation = new MockVerifierSpaceFactory();
    // when delegate called
    verifierSpaceFactoryProxy = MockVerifierSpaceFactory(
      UnsafeUpgrades.deployUUPSProxy(
        address(verifierSpaceFactoryImplementation),
        abi.encodeCall(IVerifierSpaceFactory.initialize, (abi.encode(_spaceRegistry, _owner)))
      )
    );
  }

  function test_Constants_WhenDeployed() external view {
    // when deployed

    // it sets _VERIFIER_SPACE_FACTORY_STORAGE_LOCATION to keccak256(abi.encode(uint256(keccak256("geo.storage.VerifierSpaceFactory")) - 1)) & ~bytes32(uint256(0xff))
    assertEq(
      verifierSpaceFactoryProxy.exposed__VERIFIER_SPACE_FACTORY_STORAGE_LOCATION(),
      keccak256(abi.encode(uint256(keccak256('geo.storage.VerifierSpaceFactory')) - 1)) & ~bytes32(uint256(0xff))
    );
  }

  function test_Constructor_WhenCalled() external {
    // it disables initializers
    vm.expectEmit();
    emit Initializable.Initialized(type(uint64).max);

    // when called
    new MockVerifierSpaceFactory();
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
    // when delegate called
    verifierSpaceFactoryProxy = MockVerifierSpaceFactory(
      UnsafeUpgrades.deployUUPSProxy(
        address(verifierSpaceFactoryImplementation),
        abi.encodeCall(IVerifierSpaceFactory.initialize, (abi.encode(__spaceRegistry, __owner)))
      )
    );

    uint256 _verifierSpaceImplementationNonce = vm.getNonce(address(verifierSpaceFactoryProxy)) - 2;
    uint256 _verifierSpaceBeaconNonce = vm.getNonce(address(verifierSpaceFactoryProxy)) - 1;

    address _verifierSpaceImplementation =
      vm.computeCreateAddress(address(verifierSpaceFactoryProxy), _verifierSpaceImplementationNonce);
    address _verifierSpaceBeacon =
      vm.computeCreateAddress(address(verifierSpaceFactoryProxy), _verifierSpaceBeaconNonce);

    // it sets owner
    assertEq(verifierSpaceFactoryProxy.owner(), __owner);

    // it deploys verifier space implementation
    assertEq(_verifierSpaceImplementation.code, type(VerifierSpace).runtimeCode);

    // it deploys verifier space beacon
    assertEq(UpgradeableBeacon(_verifierSpaceBeacon).implementation(), _verifierSpaceImplementation);
    assertEq(UpgradeableBeacon(_verifierSpaceBeacon).owner(), __owner);

    // it sets verifierSpaceBeacon
    assertEq(verifierSpaceFactoryProxy.verifierSpaceBeacon(), _verifierSpaceBeacon);

    // it sets spaceRegistry
    assertEq(address(verifierSpaceFactoryProxy.spaceRegistry()), address(__spaceRegistry));
  }

  function test_Initialize_WhenDelegateCalledAgain(
    ISpaceRegistry __spaceRegistry,
    address __owner
  ) external whenDelegateCalled whenOwnerIsNotZeroAddress(__owner) {
    // when delegate called
    verifierSpaceFactoryProxy = MockVerifierSpaceFactory(
      UnsafeUpgrades.deployUUPSProxy(
        address(verifierSpaceFactoryImplementation),
        abi.encodeCall(IVerifierSpaceFactory.initialize, (abi.encode(__spaceRegistry, __owner)))
      )
    );

    // it reverts with InvalidInitialization
    vm.expectRevert(Initializable.InvalidInitialization.selector);

    // when delegate called again
    verifierSpaceFactoryProxy.initialize(abi.encode(__spaceRegistry, __owner));
  }

  function test_Initialize_WhenOwnerIsZeroAddress() external whenDelegateCalled {
    // when owner is zero address
    address __owner = address(0);

    // it reverts with OwnableInvalidOwner
    vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, __owner));

    // when delegate called
    verifierSpaceFactoryProxy = MockVerifierSpaceFactory(
      UnsafeUpgrades.deployUUPSProxy(
        address(verifierSpaceFactoryImplementation),
        abi.encodeCall(IVerifierSpaceFactory.initialize, (abi.encode(_spaceRegistry, __owner)))
      )
    );
  }

  function test_Initialize_WhenCalled(ISpaceRegistry __spaceRegistry, address __owner) external {
    // it reverts with InvalidInitialization
    vm.expectRevert(Initializable.InvalidInitialization.selector);

    // when called
    verifierSpaceFactoryImplementation.initialize(abi.encode(__spaceRegistry, __owner));
  }

  function test_CreateVerifierSpaceProxy_WhenOwnerIsNotZeroAddress(address __owner)
    external
    whenOwnerIsNotZeroAddress(__owner)
  {
    uint256 _verifierSpaceProxyNonce = vm.getNonce(address(verifierSpaceFactoryProxy));
    VerifierSpace _verifierSpaceProxy =
      VerifierSpace(vm.computeCreateAddress(address(verifierSpaceFactoryProxy), _verifierSpaceProxyNonce));

    _mockRegisterSpaceId(_spaceRegistry);

    // it returns new verifier space proxy
    assertEq(verifierSpaceFactoryProxy.createVerifierSpaceProxy(__owner), address(_verifierSpaceProxy));

    // it deploys and initializes verifier space proxy
    assertEq(
      address(uint160(uint256(vm.load(address(_verifierSpaceProxy), ERC1967Utils.BEACON_SLOT)))),
      verifierSpaceFactoryProxy.verifierSpaceBeacon()
    );
    assertEq(_verifierSpaceProxy.owner(), __owner);
    assertEq(address(_verifierSpaceProxy.spaceRegistry()), address(verifierSpaceFactoryProxy.spaceRegistry()));
    assertEq(_verifierSpaceProxy.validWriters(__owner), true);
    assertEq(_verifierSpaceProxy.validWriters(address(_verifierSpaceProxy)), true);
  }

  function test_CreateVerifierSpaceProxy_WhenOwnerIsZeroAddress() external {
    // when owner is zero address
    address __owner = address(0);

    // it reverts with OwnableInvalidOwner
    vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, __owner));

    verifierSpaceFactoryProxy.createVerifierSpaceProxy(__owner);
  }

  function test_Name_WhenCalled() external view {
    // when called

    // it returns the name
    assertEq(verifierSpaceFactoryProxy.name(), 'VERIFIER_SPACE_FACTORY');
  }

  function test_Version_WhenCalled() external view {
    // when called

    // it returns semantic version
    assertEq(verifierSpaceFactoryProxy.version(), '1.0.0');
  }

  function test__authorizeUpgrade_WhenCalledByOwner(address _newImplementation) external {
    // when called by owner
    vm.startPrank(_owner);

    // it does not revert
    verifierSpaceFactoryProxy.exposed__authorizeUpgrade(_newImplementation);
  }

  function test__authorizeUpgrade_WhenCalledByNon_owner(address _newImplementation) external {
    // when called by non-owner
    vm.startPrank(_randomCaller);

    // it reverts with OwnableUnauthorizedAccount
    vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, _randomCaller));

    verifierSpaceFactoryProxy.exposed__authorizeUpgrade(_newImplementation);
  }

  function _mockRegisterSpaceId(ISpaceRegistry __spaceRegistry) internal {
    _mockAndExpect(
      address(__spaceRegistry),
      abi.encodeCall(ISpaceRegistry.registerSpaceId, (keccak256('VERIFIER_SPACE'), abi.encode('1.0.0'))),
      abi.encode()
    );
  }
}
