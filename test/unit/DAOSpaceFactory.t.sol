// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {TestHelper} from 'test/unit/helpers/TestHelper.t.sol';

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {ERC1967Utils} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol';
import {UpgradeableBeacon} from '@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol';
import {UnsafeUpgrades} from '@openzeppelin/foundry-upgrades/Upgrades.sol';

import {DAOSpace} from 'contracts/DAOSpace.sol';
import {IDAOSpace} from 'interfaces/IDAOSpace.sol';
import {IDAOSpaceFactory} from 'interfaces/IDAOSpaceFactory.sol';
import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';
import {MockDAOSpaceFactory} from 'test/unit/mocks/MockDAOSpaceFactory.sol';

import 'src/ActionsConstants.sol' as ActionsConstants;

contract UnitDAOSpaceFactory is TestHelper {
  MockDAOSpaceFactory public daoSpaceFactoryImplementation;
  MockDAOSpaceFactory public daoSpaceFactoryProxy;

  IDAOSpace.VotingSettings internal _votingSettings;

  address internal _owner = makeAddr('_owner');
  address internal _randomCaller = makeAddr('_randomCaller');

  address[] internal _initialEditors = new address[](1);
  address internal _initialEditor = makeAddr('_initialEditor');
  address[] internal _initialMembers = new address[](1);
  address internal _initialMember = makeAddr('_initialMember');

  ISpaceRegistry internal _spaceRegistry = ISpaceRegistry(makeAddr('_spaceRegistry'));

  function setUp() external {
    _initialEditors[0] = _initialEditor;
    _initialMembers[0] = _initialMember;

    _votingSettings = IDAOSpace.VotingSettings({
      slowPathPercentageThreshold: 5e5, fastPathFlatThreshold: 1, quorum: 1, duration: 2 days
    });

    // when deployed
    daoSpaceFactoryImplementation = new MockDAOSpaceFactory();
    // when delegate called
    daoSpaceFactoryProxy = MockDAOSpaceFactory(
      UnsafeUpgrades.deployUUPSProxy(
        address(daoSpaceFactoryImplementation), abi.encodeCall(IDAOSpaceFactory.initialize, (_spaceRegistry, _owner))
      )
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
        address(daoSpaceFactoryImplementation), abi.encodeCall(IDAOSpaceFactory.initialize, (__spaceRegistry, __owner))
      )
    );

    uint256 _daoSpaceImplementationNonce = vm.getNonce(address(daoSpaceFactoryProxy)) - 2;
    uint256 _daoSpaceBeaconNonce = vm.getNonce(address(daoSpaceFactoryProxy)) - 1;

    address _daoSpaceImplementation =
      vm.computeCreateAddress(address(daoSpaceFactoryProxy), _daoSpaceImplementationNonce);
    address _daoSpaceBeacon = vm.computeCreateAddress(address(daoSpaceFactoryProxy), _daoSpaceBeaconNonce);

    // it sets owner
    assertEq(daoSpaceFactoryProxy.owner(), __owner);

    // it deploys DAO space implementation
    assertEq(_daoSpaceImplementation.code, type(DAOSpace).runtimeCode);

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
        address(daoSpaceFactoryImplementation), abi.encodeCall(IDAOSpaceFactory.initialize, (__spaceRegistry, __owner))
      )
    );

    // it reverts with InvalidInitialization
    vm.expectRevert(Initializable.InvalidInitialization.selector);

    // when delegate called again
    daoSpaceFactoryProxy.initialize(__spaceRegistry, __owner);
  }

  function test_Initialize_WhenOwnerIsZeroAddress() external whenDelegateCalled {
    // when owner is zero address
    address __owner = address(0);

    // it reverts with OwnableInvalidOwner
    vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, __owner));

    // when delegate called
    daoSpaceFactoryProxy = MockDAOSpaceFactory(
      UnsafeUpgrades.deployUUPSProxy(
        address(daoSpaceFactoryImplementation), abi.encodeCall(IDAOSpaceFactory.initialize, (_spaceRegistry, __owner))
      )
    );
  }

  function test_Initialize_WhenCalled(ISpaceRegistry __spaceRegistry, address __owner) external {
    // it reverts with InvalidInitialization
    vm.expectRevert(Initializable.InvalidInitialization.selector);

    // when called
    daoSpaceFactoryImplementation.initialize(__spaceRegistry, __owner);
  }

  function test_CreateDAOSpaceProxy_WhenCalled(IDAOSpace.VotingSettings memory __votingSettings) external {
    __votingSettings.slowPathPercentageThreshold = bound(__votingSettings.slowPathPercentageThreshold, 0, 1e6);
    __votingSettings.fastPathFlatThreshold = bound(__votingSettings.fastPathFlatThreshold, 0, 1);
    __votingSettings.quorum = bound(__votingSettings.quorum, 0, 1);
    __votingSettings.duration = bound(__votingSettings.duration, 2 days, 200 days);

    uint256 _daoSpaceProxyNonce = vm.getNonce(address(daoSpaceFactoryProxy));
    DAOSpace _daoSpaceProxy = DAOSpace(vm.computeCreateAddress(address(daoSpaceFactoryProxy), _daoSpaceProxyNonce));

    // it emits DAOSpaceProxyCreated
    vm.expectEmit(address(daoSpaceFactoryProxy));
    emit IDAOSpaceFactory.DAOSpaceProxyCreated(address(_daoSpaceProxy));

    _mockRegisterSpaceId(_spaceRegistry);
    _mockEnter(
      _spaceRegistry,
      address(_daoSpaceProxy),
      address(_daoSpaceProxy),
      ActionsConstants.EDITOR_ADDED,
      bytes32(bytes20(_initialEditor)),
      '',
      ''
    );
    _mockEnter(
      _spaceRegistry,
      address(_daoSpaceProxy),
      address(_daoSpaceProxy),
      ActionsConstants.MEMBER_ADDED,
      bytes32(bytes20(_initialMember)),
      '',
      ''
    );

    // it returns new DAO space proxy
    assertEq(
      daoSpaceFactoryProxy.createDAOSpaceProxy(__votingSettings, _initialEditors, _initialMembers),
      address(_daoSpaceProxy)
    );

    (
      _votingSettings.slowPathPercentageThreshold,
      _votingSettings.fastPathFlatThreshold,
      _votingSettings.quorum,
      _votingSettings.duration
    ) = _daoSpaceProxy.votingSettings();

    // it deploys and initializes DAO space proxy
    assertEq(
      address(uint160(uint256(vm.load(address(_daoSpaceProxy), ERC1967Utils.BEACON_SLOT)))),
      daoSpaceFactoryProxy.daoSpaceBeacon()
    );
    assertEq(address(_daoSpaceProxy.spaceRegistry()), address(daoSpaceFactoryProxy.spaceRegistry()));
    assertEq(abi.encode(_votingSettings), abi.encode(__votingSettings));
    assertEq(_daoSpaceProxy.hasRole(_daoSpaceProxy.EDITOR(), _initialEditor), true);
    assertEq(_daoSpaceProxy.hasRole(_daoSpaceProxy.MEMBER(), _initialMember), true);
    assertEq(_daoSpaceProxy.hasRole(_daoSpaceProxy.DAO(), address(_daoSpaceProxy)), true);
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
    address _from,
    address _to,
    bytes32 _action,
    bytes32 _topic,
    bytes memory _data,
    bytes memory _signature
  ) internal {
    _mockAndExpect(
      address(__spaceRegistry),
      abi.encodeCall(ISpaceRegistry.enter, (_from, _to, _action, _topic, _data, _signature)),
      abi.encode()
    );
  }

  function _mockRegisterSpaceId(ISpaceRegistry __spaceRegistry) internal {
    _mockAndExpect(address(__spaceRegistry), abi.encodeCall(ISpaceRegistry.registerSpaceId, ()), abi.encode());
  }
}
