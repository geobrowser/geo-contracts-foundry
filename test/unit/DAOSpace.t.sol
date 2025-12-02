// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {TestHelper} from 'test/unit/helpers/TestHelper.t.sol';

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {UnsafeUpgrades} from '@openzeppelin/foundry-upgrades/Upgrades.sol';

import {IDAOSpace} from 'interfaces/IDAOSpace.sol';
import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';
import {MockDAOSpace} from 'mocks/MockDAOSpace.sol';

import 'src/ActionsConstants.sol' as ActionsConstants;

contract UnitDAOSpace is TestHelper {
  MockDAOSpace public daoSpaceImplementation;
  MockDAOSpace public daoSpaceProxy;
  address public daoSpaceBeacon;

  address internal _owner;
  uint256 internal _ownerPrivateKey;
  IDAOSpace.VotingSettings internal _votingSettings;
  address[] internal _initialEditors;
  address[] internal _initialMembers;

  address internal _randomCaller = makeAddr('_randomCaller');
  address internal _spaceRegistry = makeAddr('_spaceRegistry');
  address internal _fromSpace = makeAddr('_fromSpace');
  address internal _toSpace = makeAddr('_toSpace');
  address internal _initialEditor = makeAddr('_initialEditor');
  address internal _initialMember = makeAddr('_initialMember');

  function setUp() external {
    // set up
    (_owner, _ownerPrivateKey) = makeAddrAndKey('_owner');
    _initialEditors = new address[](1);
    _initialEditors[0] = _initialEditor;
    _initialMembers = new address[](1);
    _initialMembers[0] = _initialMember;

    // when deployed
    daoSpaceImplementation = new MockDAOSpace();
    daoSpaceBeacon = UnsafeUpgrades.deployBeacon(address(daoSpaceImplementation), _owner);

    // deploy with owner and fetch future address for external calls and event emissions
    vm.startPrank(_owner, _owner);
    address predictedDAOSpaceProxy = vm.computeCreateAddress(_owner, vm.getNonce(_owner));

    // when delegate called
    _mockRegisterSpaceId(_spaceRegistry);

    // it calls enter on the spaceRegistry with the ADD_EDITOR action
    _mockEnter(
      _spaceRegistry,
      predictedDAOSpaceProxy,
      predictedDAOSpaceProxy,
      ActionsConstants.ADD_EDITOR,
      bytes32(bytes20(_initialEditor))
    );

    // it calls enter on the spaceRegistry with the ADD_MEMBER action
    _mockEnter(
      _spaceRegistry,
      predictedDAOSpaceProxy,
      predictedDAOSpaceProxy,
      ActionsConstants.ADD_MEMBER,
      bytes32(bytes20(_initialMember))
    );

    daoSpaceProxy = MockDAOSpace(
      UnsafeUpgrades.deployBeaconProxy(
        daoSpaceBeacon,
        abi.encodeCall(
          IDAOSpace.initialize, (ISpaceRegistry(_spaceRegistry), _votingSettings, _initialEditors, _initialMembers)
        )
      )
    );

    vm.stopPrank();
  }

  /// CONSTRUCTOR ///

  function test_Constructor_WhenCalled() external {
    // it disables initializers
    vm.expectEmit();
    emit Initializable.Initialized(type(uint64).max);

    // when called
    new MockDAOSpace();
  }

  /// INITIALIZE ///

  modifier whenDelegateCalled() {
    // when delegate called
    _;
  }

  function test_Initializer_WhenDelegateCalled(
    address __spaceRegistry,
    IDAOSpace.VotingSettings calldata __votingSettings
  ) external whenDelegateCalled {
    //_assumeFuzzable(__spaceRegistry);
    address[] memory __initialEditors = new address[](0);
    address[] memory __initialMembers = new address[](0);

    // it calls spaceRegistry to register space ID
    _mockRegisterSpaceId(__spaceRegistry);

    // when delegate called
    daoSpaceProxy = MockDAOSpace(
      UnsafeUpgrades.deployBeaconProxy(
        daoSpaceBeacon,
        abi.encodeCall(
          IDAOSpace.initialize, (ISpaceRegistry(__spaceRegistry), __votingSettings, __initialEditors, __initialMembers)
        )
      )
    );

    // it sets the spaceRegistry
    assertEq(address(daoSpaceProxy.spaceRegistry()), __spaceRegistry);

    // it sets the voting settings
    (uint256 slowPathPercentageThreshold, uint256 fastPathFlatThreshold, uint256 duration) =
      daoSpaceProxy.votingSettings();
    assertEq(slowPathPercentageThreshold, __votingSettings.slowPathPercentageThreshold);
    assertEq(fastPathFlatThreshold, __votingSettings.fastPathFlatThreshold);
    assertEq(duration, __votingSettings.duration);

    // it grants itself the DAO role
    assertEq(daoSpaceProxy.hasRole(daoSpaceProxy.DAO(), address(daoSpaceProxy)), true);

    // it sets addMember as a valid fast path action
    assertEq(daoSpaceProxy.actionIsFastPathValid(IDAOSpace.addMember.selector), true);

    // it sets removeMember as a valid fast path action
    assertEq(daoSpaceProxy.actionIsFastPathValid(IDAOSpace.removeMember.selector), true);
  }

  modifier whenInitialEditorsLengthIsGreaterThanZero() {
    _;
  }

  function test_Initializer_WhenAnInitialEditorIsNotTheZeroAddress(
    address __spaceRegistry,
    IDAOSpace.VotingSettings calldata __votingSettings,
    address __initialEditor,
    address __initialMember
  ) external whenDelegateCalled whenInitialEditorsLengthIsGreaterThanZero {
    //_assumeFuzzable(__spaceRegistry);
    //_assumeFuzzable(__initialEditor);
    //_assumeFuzzable(__initialMember);
    address[] memory __initialEditors = new address[](1);
    __initialEditors[0] = __initialEditor;
    address[] memory __initialMembers = new address[](1);
    __initialMembers[0] = __initialMember;

    // deploy with owner and fetch future address for external calls and event emissions
    vm.startPrank(_owner, _owner);
    address predictedDAOSpaceProxy = vm.computeCreateAddress(_owner, vm.getNonce(_owner));

    // it calls spaceRegistry to register space ID
    _mockRegisterSpaceId(__spaceRegistry);

    // it calls enter on the spaceRegistry with the ADD_EDITOR action
    _mockEnter(
      __spaceRegistry,
      predictedDAOSpaceProxy,
      predictedDAOSpaceProxy,
      ActionsConstants.ADD_EDITOR,
      bytes32(bytes20(__initialEditor))
    );

    // it calls enter on the spaceRegistry with the ADD_MEMBER action
    _mockEnter(
      __spaceRegistry,
      predictedDAOSpaceProxy,
      predictedDAOSpaceProxy,
      ActionsConstants.ADD_MEMBER,
      bytes32(bytes20(__initialMember))
    );

    // when delegate called
    daoSpaceProxy = MockDAOSpace(
      UnsafeUpgrades.deployBeaconProxy(
        daoSpaceBeacon,
        abi.encodeCall(
          IDAOSpace.initialize, (ISpaceRegistry(__spaceRegistry), __votingSettings, __initialEditors, __initialMembers)
        )
      )
    );

    // it grants the new editor the EDITOR role
    assertEq(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), __initialEditor), true);
  }

  function test_Initializer_WhenAnInitialEditorIsTheZeroAddress()
    external
    whenDelegateCalled
    whenInitialEditorsLengthIsGreaterThanZero
  {
    // it reverts with InvalidAddressForRole
    vm.skip(true);
  }

  modifier whenInitialMembersLengthIsGreaterThanZero() {
    _;
  }

  function test_Initializer_WhenAnInitialMemberIsNotTheZeroAddress()
    external
    whenDelegateCalled
    whenInitialMembersLengthIsGreaterThanZero
  {
    // it grants the new member the MEMBER role
    // it calls enter on the spaceRegistry with the ADD_MEMBER action
    vm.skip(true);
  }

  function test_Initializer_WhenAnInitialMemberIsTheZeroAddress()
    external
    whenDelegateCalled
    whenInitialMembersLengthIsGreaterThanZero
  {
    // it reverts with InvalidAddressForRole
    vm.skip(true);
  }

  function test_Initializer_WhenDelegateCalledAgain() external whenDelegateCalled {
    // it reverts with InvalidInitialization
    vm.skip(true);
  }

  function test_Initializer_WhenCalled() external {
    // it reverts with InvalidInitialization
    vm.skip(true);
  }

  /// HELPERS ///

  function _mockRegisterSpaceId(address __spaceRegistry) internal {
    _mockAndExpect(__spaceRegistry, abi.encodeCall(ISpaceRegistry.registerSpaceId, ()), abi.encode());
  }

  function _mockEnter(address __spaceRegistry, address _from, address _to, bytes32 _action, bytes32 _topic) internal {
    _mockAndExpect(
      __spaceRegistry, abi.encodeCall(ISpaceRegistry.enter, (_from, _to, _action, _topic, '', '')), abi.encode()
    );
  }
}
