// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {TestHelper} from 'unit-helpers/TestHelper.sol';

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {ERC1967Utils} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol';
import {UpgradeableBeacon} from '@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol';
import {UnsafeUpgrades} from '@openzeppelin/foundry-upgrades/Upgrades.sol';

import {IDAOSpace} from 'interfaces/L3/IDAOSpace.sol';
import {IDAOSpaceFactory} from 'interfaces/L3/IDAOSpaceFactory.sol';
import {ISpaceRegistry} from 'interfaces/L3/ISpaceRegistry.sol';
import {MockDAOSpaceFactory} from 'test/unit/L3/mocks/MockDAOSpaceFactory.sol';

import 'contracts/L3/ActionsConstants.sol' as ActionsConstants;

contract UnitDAOSpaceFactory is TestHelper {
  MockDAOSpaceFactory public daoSpaceFactoryImplementation;
  MockDAOSpaceFactory public daoSpaceFactoryProxy;

  IDAOSpace.VotingSettings internal _votingSettings;

  address internal _daoSpaceImplementation = makeAddr('_daoSpaceImplementation');
  address internal _owner = makeAddr('_owner');
  address internal _randomCaller = makeAddr('_randomCaller');
  bytes16[] internal _initialEditors = new bytes16[](1);
  address internal _initialEditor = makeAddr('_initialEditor');
  bytes16[] internal _initialMembers = new bytes16[](1);
  address internal _initialMember = makeAddr('_initialMember');
  bytes internal _initialEditsContentUri = 'Down the Rabbit-Hole';
  bytes internal _initialEditsMetadata =
    'Alice was beginning to get very tired of sitting by her sister on the bank...';
  bytes16 internal _initialTopicId = bytes16(keccak256('_initialTopicId'));

  ISpaceRegistry internal _spaceRegistry = ISpaceRegistry(makeAddr('_spaceRegistry'));

  function setUp() external {
    // Etch some code so that the beacon deploys
    vm.etch(_daoSpaceImplementation, hex'fe');

    _initialEditors[0] = _getSpaceId(_initialEditor);
    _initialMembers[0] = _getSpaceId(_initialMember);

    _votingSettings = IDAOSpace.VotingSettings({
      partialPercentageSupportThreshold: 5e5,
      universalPercentageSupportThreshold: 5e5,
      flatSupportThreshold: 1,
      quorum: 1,
      duration: 2 days,
      disableFastPathAccessForNewMembers: true,
      executionGracePeriod: 7 days
    });

    // when deployed
    daoSpaceFactoryImplementation = new MockDAOSpaceFactory();

    // when delegate called
    daoSpaceFactoryProxy = MockDAOSpaceFactory(
      UnsafeUpgrades.deployUUPSProxy(
        address(daoSpaceFactoryImplementation),
        abi.encodeCall(IDAOSpaceFactory.initialize, (abi.encode(_spaceRegistry, _owner, _daoSpaceImplementation)))
      )
    );
  }

  function test_Constants_WhenDeployed() external view {
    // when deployed

    // it sets _DAO_SPACE_FACTORY_STORAGE_LOCATION to keccak256(abi.encode(uint256(keccak256("geo.storage.DAOSpaceFactory")) - 1)) & ~bytes32(uint256(0xff))
    assertEq(
      daoSpaceFactoryProxy.exposed__DAO_SPACE_FACTORY_STORAGE_LOCATION(),
      keccak256(abi.encode(uint256(keccak256('geo.storage.DAOSpaceFactory')) - 1)) & ~bytes32(uint256(0xff))
    );
  }

  function test_Constructor_WhenCalled() external {
    // it disables initializers
    vm.expectEmit();
    emit Initializable.Initialized(type(uint64).max);

    // when called
    new MockDAOSpaceFactory();
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
    daoSpaceFactoryProxy = MockDAOSpaceFactory(
      UnsafeUpgrades.deployUUPSProxy(
        address(daoSpaceFactoryImplementation),
        abi.encodeCall(IDAOSpaceFactory.initialize, (abi.encode(__spaceRegistry, __owner, _daoSpaceImplementation)))
      )
    );

    uint256 _daoSpaceBeaconNonce = vm.getNonce(address(daoSpaceFactoryProxy)) - 1;
    address _daoSpaceBeacon = vm.computeCreateAddress(address(daoSpaceFactoryProxy), _daoSpaceBeaconNonce);

    // it sets owner
    assertEq(daoSpaceFactoryProxy.owner(), __owner);

    // it deploys DAO space beacon
    assertEq(UpgradeableBeacon(_daoSpaceBeacon).implementation(), _daoSpaceImplementation);
    assertEq(UpgradeableBeacon(_daoSpaceBeacon).owner(), __owner);

    // it sets daoSpaceBeacon
    assertEq(daoSpaceFactoryProxy.daoSpaceBeacon(), _daoSpaceBeacon);

    // it sets spaceRegistry
    assertEq(address(daoSpaceFactoryProxy.spaceRegistry()), address(__spaceRegistry));
  }

  function test_Initialize_WhenDelegateCalledAgain(
    ISpaceRegistry __spaceRegistry,
    address __owner
  ) external whenDelegateCalled whenOwnerIsNotZeroAddress(__owner) {
    // when delegate called
    daoSpaceFactoryProxy = MockDAOSpaceFactory(
      UnsafeUpgrades.deployUUPSProxy(
        address(daoSpaceFactoryImplementation),
        abi.encodeCall(IDAOSpaceFactory.initialize, (abi.encode(__spaceRegistry, __owner, _daoSpaceImplementation)))
      )
    );

    // it reverts with InvalidInitialization
    vm.expectRevert(Initializable.InvalidInitialization.selector);

    // when delegate called again
    daoSpaceFactoryProxy.initialize(abi.encode(__spaceRegistry, __owner, _daoSpaceImplementation));
  }

  function test_Initialize_WhenOwnerIsZeroAddress() external whenDelegateCalled {
    // when owner is zero address
    address __owner = address(0);

    // it reverts with OwnableInvalidOwner
    vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, __owner));

    // when delegate called
    daoSpaceFactoryProxy = MockDAOSpaceFactory(
      UnsafeUpgrades.deployUUPSProxy(
        address(daoSpaceFactoryImplementation),
        abi.encodeCall(IDAOSpaceFactory.initialize, (abi.encode(_spaceRegistry, __owner, _daoSpaceImplementation)))
      )
    );
  }

  function test_Initialize_WhenCalled(
    ISpaceRegistry __spaceRegistry,
    address __owner,
    address __daoSpaceImplementation
  ) external {
    // it reverts with InvalidInitialization
    vm.expectRevert(Initializable.InvalidInitialization.selector);

    // when called
    daoSpaceFactoryImplementation.initialize(abi.encode(__spaceRegistry, __owner, __daoSpaceImplementation));
  }

  function test_CreateDAOSpaceProxy_WhenCalled(
    IDAOSpace.VotingSettings memory __votingSettings,
    bytes memory __initialEditsContentUri,
    bytes memory __initialEditsMetadata
  ) external {
    __votingSettings.partialPercentageSupportThreshold =
      bound(__votingSettings.partialPercentageSupportThreshold, 0, 1e6);
    __votingSettings.universalPercentageSupportThreshold =
      bound(__votingSettings.universalPercentageSupportThreshold, 0, 1e6);
    __votingSettings.flatSupportThreshold = bound(__votingSettings.flatSupportThreshold, 0, 1);
    __votingSettings.quorum = bound(__votingSettings.quorum, 0, 1);
    __votingSettings.duration = bound(__votingSettings.duration, 1 minutes, 200 days);
    __votingSettings.executionGracePeriod = bound(__votingSettings.executionGracePeriod, 1 hours, 200 days);

    uint256 _daoSpaceProxyNonce = vm.getNonce(address(daoSpaceFactoryProxy));
    address _daoSpaceProxy = vm.computeCreateAddress(address(daoSpaceFactoryProxy), _daoSpaceProxyNonce);
    assertFalse(daoSpaceFactoryProxy.proxyIsChildOfFactory(_daoSpaceProxy));

    // it deploys and initializes DAO space proxy
    bytes memory _initializerData = (__initialEditsContentUri.length != 0 || __initialEditsMetadata.length != 0)
      ? abi.encode(
        daoSpaceFactoryProxy.spaceRegistry(),
        __votingSettings,
        _initialEditors,
        _initialMembers,
        abi.encode(__initialEditsContentUri, __initialEditsMetadata),
        _initialTopicId,
        bytes16(0)
      )
      : abi.encode(
        daoSpaceFactoryProxy.spaceRegistry(),
        __votingSettings,
        _initialEditors,
        _initialMembers,
        '',
        _initialTopicId,
        bytes16(0)
      );
    _mockAndExpect(_daoSpaceImplementation, abi.encodeCall(IDAOSpace.initialize, (_initializerData)), abi.encode());

    // it returns new DAO space proxy
    assertEq(
      daoSpaceFactoryProxy.createDAOSpaceProxy(
        __votingSettings,
        _initialEditors,
        _initialMembers,
        __initialEditsContentUri,
        __initialEditsMetadata,
        _initialTopicId
      ),
      _daoSpaceProxy
    );

    assertEq(
      address(uint160(uint256(vm.load(_daoSpaceProxy, ERC1967Utils.BEACON_SLOT)))),
      daoSpaceFactoryProxy.daoSpaceBeacon()
    );

    // it updates the proxyIsChildOfFactory for the deployed proxy to true
    assertTrue(daoSpaceFactoryProxy.proxyIsChildOfFactory(_daoSpaceProxy));
  }

  modifier whenCalledByOwner() {
    // when called by owner
    vm.prank(_owner);
    _;
  }

  function test_CreateDAOSpaceProxyForTransplant_WhenCalledByOwner(
    bytes16 _transplantDAOSpaceId,
    IDAOSpace.VotingSettings memory __votingSettings
  ) external whenCalledByOwner {
    vm.assume(_transplantDAOSpaceId != bytes16(0));
    __votingSettings.partialPercentageSupportThreshold =
      bound(__votingSettings.partialPercentageSupportThreshold, 0, 1e6);
    __votingSettings.universalPercentageSupportThreshold =
      bound(__votingSettings.universalPercentageSupportThreshold, 0, 1e6);
    __votingSettings.flatSupportThreshold = bound(__votingSettings.flatSupportThreshold, 0, 1);
    __votingSettings.quorum = bound(__votingSettings.quorum, 0, 1);
    __votingSettings.duration = bound(__votingSettings.duration, 1 minutes, 200 days);
    __votingSettings.executionGracePeriod = bound(__votingSettings.executionGracePeriod, 1 hours, 200 days);

    uint256 _daoSpaceProxyNonce = vm.getNonce(address(daoSpaceFactoryProxy));
    address _daoSpaceProxy = vm.computeCreateAddress(address(daoSpaceFactoryProxy), _daoSpaceProxyNonce);
    assertFalse(daoSpaceFactoryProxy.proxyIsChildOfFactory(_daoSpaceProxy));

    // when called by owner
    // it deploys and initializes DAO space proxy
    bytes memory _initializerData = abi.encode(
      daoSpaceFactoryProxy.spaceRegistry(),
      __votingSettings,
      _initialEditors,
      _initialMembers,
      bytes(''),
      bytes16(0),
      _transplantDAOSpaceId
    );
    _mockAndExpect(_daoSpaceImplementation, abi.encodeCall(IDAOSpace.initialize, (_initializerData)), abi.encode());

    // it returns new DAO space proxy
    vm.prank(_owner);
    assertEq(
      daoSpaceFactoryProxy.createDAOSpaceProxyForTransplant(
        __votingSettings, _initialEditors, _initialMembers, _transplantDAOSpaceId
      ),
      _daoSpaceProxy
    );

    // it updates the proxyIsChildOfFactory for the deployed proxy to true
    assertTrue(daoSpaceFactoryProxy.proxyIsChildOfFactory(_daoSpaceProxy));
  }

  function test_CreateDAOSpaceProxyForTransplant_WhenTransplantDAOSpaceIdIsZero() external whenCalledByOwner {
    // when transplant DAO space id is zero

    // it reverts with InvalidTransplantDAOSpaceId
    vm.expectRevert(IDAOSpaceFactory.InvalidTransplantDAOSpaceId.selector);
    daoSpaceFactoryProxy.createDAOSpaceProxyForTransplant(_votingSettings, _initialEditors, _initialMembers, bytes16(0));
  }

  function test_CreateDAOSpaceProxyForTransplant_WhenCalledByNon_owner(bytes16 _transplantDAOSpaceId) external {
    vm.assume(_transplantDAOSpaceId != bytes16(0));

    // when called by non-owner
    vm.prank(_randomCaller);

    // it reverts with OwnableUnauthorizedAccount
    vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, _randomCaller));
    daoSpaceFactoryProxy.createDAOSpaceProxyForTransplant(
      _votingSettings, _initialEditors, _initialMembers, _transplantDAOSpaceId
    );
  }

  function test_TypeId_WhenCalled() external view {
    // when called

    // it returns the type
    assertEq(daoSpaceFactoryProxy.typeId(), keccak256('DAO_SPACE_FACTORY'));
  }

  function test_Name_WhenCalled() external view {
    // when called

    // it returns the name
    assertEq(daoSpaceFactoryProxy.name(), 'DAO_SPACE_FACTORY');
  }

  function test_Version_WhenCalled() external view {
    // when called

    // it returns semantic version
    assertEq(daoSpaceFactoryProxy.version(), '1.0.0');
  }

  function test__authorizeUpgrade_WhenCalledByOwner(address _newImplementation) external {
    // when called by owner
    vm.startPrank(_owner);

    // it does not revert
    daoSpaceFactoryProxy.exposed__authorizeUpgrade(_newImplementation);
  }

  function test__authorizeUpgrade_WhenCalledByNon_owner(address _newImplementation) external {
    // when called by non-owner
    vm.startPrank(_randomCaller);

    // it reverts with OwnableUnauthorizedAccount
    vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, _randomCaller));

    daoSpaceFactoryProxy.exposed__authorizeUpgrade(_newImplementation);
  }

  function _mockEnter(
    ISpaceRegistry __spaceRegistry,
    bytes16 _fromSpaceId,
    bytes16 _toSpaceId,
    bytes32 _action,
    bytes32 _subject,
    bytes memory _data,
    bytes memory _signature
  ) internal {
    _mockAndExpect(
      address(__spaceRegistry),
      abi.encodeCall(ISpaceRegistry.enter, (_fromSpaceId, _toSpaceId, _action, _subject, _data, _signature)),
      abi.encode()
    );
  }

  function _mockRegisterSpaceId(
    ISpaceRegistry __spaceRegistry,
    bytes32 __spaceType,
    bytes memory __spaceVersion
  ) internal {
    _mockAndExpect(
      address(__spaceRegistry),
      abi.encodeCall(ISpaceRegistry.registerSpaceId, (__spaceType, __spaceVersion)),
      abi.encode()
    );
  }

  function _getSpaceId(address _account) internal view returns (bytes16 _spaceId) {
    bytes32 _hash = keccak256(abi.encodePacked('grc20.space', _account, uint256(0), block.chainid));
    _hash = _hash & ~(bytes32(uint256(0xf0)) << 200) | (bytes32(uint256(0x40)) << 200);
    _spaceId = bytes16(_hash & ~(bytes32(uint256(0xc0)) << 184) | (bytes32(uint256(0x80)) << 184));
  }
}
