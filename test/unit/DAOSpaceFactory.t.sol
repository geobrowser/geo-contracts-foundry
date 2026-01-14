// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {TestHelper} from 'test/unit/helpers/TestHelper.t.sol';

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {ERC1967Utils} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol';
import {UpgradeableBeacon} from '@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol';
import {UnsafeUpgrades} from '@openzeppelin/foundry-upgrades/Upgrades.sol';

import {IDAOSpace} from 'interfaces/IDAOSpace.sol';
import {IDAOSpaceFactory} from 'interfaces/IDAOSpaceFactory.sol';
import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';
import {MockDAOSpaceFactory} from 'test/unit/mocks/MockDAOSpaceFactory.sol';

import 'src/ActionsConstants.sol' as ActionsConstants;

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

  ISpaceRegistry internal _spaceRegistry = ISpaceRegistry(makeAddr('_spaceRegistry'));

  function setUp() external {
    // Etch some code so that the beacon deploys
    vm.etch(_daoSpaceImplementation, hex'fe');

    _initialEditors[0] = _getSpaceId(_initialEditor);
    _initialMembers[0] = _getSpaceId(_initialMember);

    _votingSettings = IDAOSpace.VotingSettings({
      slowPathPercentageThreshold: 5e5, fastPathFlatThreshold: 1, quorum: 1, duration: 2 days
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
    __votingSettings.slowPathPercentageThreshold = bound(__votingSettings.slowPathPercentageThreshold, 0, 1e6);
    __votingSettings.fastPathFlatThreshold = bound(__votingSettings.fastPathFlatThreshold, 0, 1);
    __votingSettings.quorum = bound(__votingSettings.quorum, 0, 1);
    __votingSettings.duration = bound(__votingSettings.duration, 1 minutes, 200 days);

    uint256 _daoSpaceProxyNonce = vm.getNonce(address(daoSpaceFactoryProxy));
    address _daoSpaceProxy = vm.computeCreateAddress(address(daoSpaceFactoryProxy), _daoSpaceProxyNonce);
    assertEq(daoSpaceFactoryProxy.proxyIsChildOfFactory(_daoSpaceProxy), false);

    // it deploys and initializes DAO space proxy
    bytes memory _initializerData = (__initialEditsContentUri.length != 0 || __initialEditsMetadata.length != 0)
      ? abi.encode(
        daoSpaceFactoryProxy.spaceRegistry(),
        __votingSettings,
        _initialEditors,
        _initialMembers,
        abi.encode(__initialEditsContentUri, __initialEditsMetadata)
      )
      : abi.encode(daoSpaceFactoryProxy.spaceRegistry(), __votingSettings, _initialEditors, _initialMembers, '');
    _mockAndExpect(_daoSpaceImplementation, abi.encodeCall(IDAOSpace.initialize, (_initializerData)), abi.encode());

    // it returns new DAO space proxy
    assertEq(
      daoSpaceFactoryProxy.createDAOSpaceProxy(
        __votingSettings, _initialEditors, _initialMembers, __initialEditsContentUri, __initialEditsMetadata
      ),
      _daoSpaceProxy
    );

    assertEq(
      address(uint160(uint256(vm.load(_daoSpaceProxy, ERC1967Utils.BEACON_SLOT)))),
      daoSpaceFactoryProxy.daoSpaceBeacon()
    );

    // it updates the proxyIsChildOfFactory for the deployed proxy to true
    assertEq(daoSpaceFactoryProxy.proxyIsChildOfFactory(_daoSpaceProxy), true);
  }

  function test_TypeId_WhenCalled() external view {
    // when called

    // it returns the type
    assertEq(daoSpaceFactoryProxy.typeId(), keccak256(bytes('DAO_SPACE_FACTORY')));
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
    bytes32 _topic,
    bytes memory _data,
    bytes memory _signature
  ) internal {
    _mockAndExpect(
      address(__spaceRegistry),
      abi.encodeCall(ISpaceRegistry.enter, (_fromSpaceId, _toSpaceId, _action, _topic, _data, _signature)),
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
    return bytes16(keccak256(abi.encodePacked('grc20.space', _account, uint256(0), block.chainid)));
  }
}
