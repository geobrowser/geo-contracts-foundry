// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {TestHelper} from 'test/unit/helpers/TestHelper.t.sol';

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {Errors} from '@openzeppelin/contracts/utils/Errors.sol';
import {UnsafeUpgrades} from '@openzeppelin/foundry-upgrades/Upgrades.sol';

import {IDAOSpace} from 'interfaces/IDAOSpace.sol';
import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';
import {MockDAOSpace} from 'test/unit/mocks/MockDAOSpace.sol';

import 'src/ActionsConstants.sol' as ActionsConstants;

contract UnitDAOSpace is TestHelper {
  MockDAOSpace public daoSpaceImplementation;
  MockDAOSpace public daoSpaceProxy;
  address public daoSpaceBeacon;

  address internal _owner;
  uint256 internal _ownerPrivateKey;
  IDAOSpace.VotingSettings internal _votingSettings;
  bytes16 internal _daoSpaceProxySpaceId;
  bytes16[] internal _initialEditors;
  bytes16[] internal _initialMembers;
  bytes32 internal _spaceType;
  bytes internal _spaceVersion;

  address internal _randomCaller = makeAddr('_randomCaller');
  address internal _spaceRegistry = makeAddr('_spaceRegistry');
  bytes16 internal _randomCallerSpaceId = _getSpaceId(_randomCaller);
  bytes16 internal _spaceRegistrySpaceId = _getSpaceId(_spaceRegistry);
  bytes16 internal _fromSpaceId = bytes16(keccak256('_fromSpaceId'));
  bytes16 internal _toSpaceId = bytes16(keccak256('_toSpaceId'));
  bytes16 internal _initialEditorASpaceId = bytes16(keccak256('_initialEditorASpaceId'));
  bytes16 internal _initialEditorBSpaceId = bytes16(keccak256('_initialEditorBSpaceId'));
  bytes16 internal _initialMemberASpaceId = bytes16(keccak256('_initialMemberASpaceId'));
  bytes16 internal _initialMemberBSpaceId = bytes16(keccak256('_initialMemberBSpaceId'));
  bytes16 internal _transplantDAOSpaceId = bytes16(keccak256('_transplantDAOSpaceId'));
  bytes16 internal _initialTopicId = bytes16(keccak256('_initialTopicId'));
  bytes16 internal _proposalId = bytes16(keccak256('_proposalId'));
  bytes internal _publishEditsData = 'Curiouser and curiouser!';
  uint8 internal _proposalVersion = uint8(uint256(keccak256('_proposalVersion')));

  function setUp() external {
    // set up
    (_owner, _ownerPrivateKey) = makeAddrAndKey('_owner');
    _votingSettings = IDAOSpace.VotingSettings({
      partialPercentageSupportThreshold: 5e5,
      universalPercentageSupportThreshold: 5e5,
      flatSupportThreshold: 1,
      quorum: 1,
      duration: 2 days,
      disableFastPathAccessForNewMembers: true,
      executionGracePeriod: 7 days
    });
    _initialEditors = new bytes16[](2);
    _initialEditors[0] = _initialEditorASpaceId;
    _initialEditors[1] = _initialEditorBSpaceId;
    _initialMembers = new bytes16[](2);
    _initialMembers[0] = _initialMemberASpaceId;
    _initialMembers[1] = _initialMemberBSpaceId;

    // proxy set up
    daoSpaceImplementation = new MockDAOSpace();
    daoSpaceBeacon = UnsafeUpgrades.deployBeacon(address(daoSpaceImplementation), _owner);

    // get predicted DAO Space address for external calls and event emissions
    address _predictedDAOSpaceProxy = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
    bytes16 _predictedDAOSpaceProxySpaceId = _getSpaceId(_predictedDAOSpaceProxy);

    // And the space type and version
    _spaceType = keccak256(bytes(daoSpaceImplementation.name()));
    _spaceVersion = abi.encode(daoSpaceImplementation.version());

    // it calls spaceRegistry to register space ID
    _mockRegisterSpaceId(_spaceRegistry, _spaceType, _spaceVersion, _predictedDAOSpaceProxySpaceId);

    // mock mapping fetch with ping
    _mockAddressToSpaceId(_spaceRegistry, _predictedDAOSpaceProxy, _predictedDAOSpaceProxySpaceId);

    // it calls enter on the spaceRegistry with the EDITS_PUBLISHED action
    _mockEnter(
      _spaceRegistry,
      _predictedDAOSpaceProxySpaceId,
      _predictedDAOSpaceProxySpaceId,
      ActionsConstants.EDITS_PUBLISHED,
      '',
      _publishEditsData
    );

    // it calls enter on the spaceRegistry with the TOPIC_SET action
    _mockEnter(
      _spaceRegistry,
      _predictedDAOSpaceProxySpaceId,
      _predictedDAOSpaceProxySpaceId,
      ActionsConstants.TOPIC_SET,
      bytes32(_initialTopicId),
      ''
    );

    // it calls enter on the spaceRegistry with the EDITOR_ADDED action
    _mockEnter(
      _spaceRegistry,
      _predictedDAOSpaceProxySpaceId,
      _predictedDAOSpaceProxySpaceId,
      ActionsConstants.EDITOR_ADDED,
      bytes32(_initialEditorASpaceId),
      ''
    );
    _mockEnter(
      _spaceRegistry,
      _predictedDAOSpaceProxySpaceId,
      _predictedDAOSpaceProxySpaceId,
      ActionsConstants.EDITOR_ADDED,
      bytes32(_initialEditorBSpaceId),
      ''
    );

    // it calls enter on the spaceRegistry with the VOTING_SETTINGS_UPDATED action
    _mockEnter(
      _spaceRegistry,
      _predictedDAOSpaceProxySpaceId,
      _predictedDAOSpaceProxySpaceId,
      ActionsConstants.VOTING_SETTINGS_UPDATED,
      '',
      abi.encode(_votingSettings)
    );

    // it calls enter with SPACE_FAST_PATH_RESTRICTED then MEMBER_ADDED for each initial member (disable fast path)
    _mockEnter(
      _spaceRegistry,
      _predictedDAOSpaceProxySpaceId,
      _predictedDAOSpaceProxySpaceId,
      ActionsConstants.SPACE_FAST_PATH_RESTRICTED,
      bytes32(_initialMemberASpaceId),
      abi.encode(_initialMemberASpaceId)
    );
    _mockEnter(
      _spaceRegistry,
      _predictedDAOSpaceProxySpaceId,
      _predictedDAOSpaceProxySpaceId,
      ActionsConstants.MEMBER_ADDED,
      bytes32(_initialMemberASpaceId),
      ''
    );
    _mockEnter(
      _spaceRegistry,
      _predictedDAOSpaceProxySpaceId,
      _predictedDAOSpaceProxySpaceId,
      ActionsConstants.SPACE_FAST_PATH_RESTRICTED,
      bytes32(_initialMemberBSpaceId),
      abi.encode(_initialMemberBSpaceId)
    );
    _mockEnter(
      _spaceRegistry,
      _predictedDAOSpaceProxySpaceId,
      _predictedDAOSpaceProxySpaceId,
      ActionsConstants.MEMBER_ADDED,
      bytes32(_initialMemberBSpaceId),
      ''
    );

    // when deployed and delegate called
    daoSpaceProxy = MockDAOSpace(
      UnsafeUpgrades.deployBeaconProxy(
        daoSpaceBeacon,
        abi.encodeCall(
          IDAOSpace.initialize,
          (abi.encode(
              _spaceRegistry,
              _votingSettings,
              _initialEditors,
              _initialMembers,
              _publishEditsData,
              _initialTopicId,
              bytes16(0)
            ))
        )
      )
    );
    _daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));
  }

  /// CONSTANTS ///

  function test_Constants_WhenDeployed() external view {
    // it sets MINIMUM_VOTING_DURATION to 1 minute
    assertEq(daoSpaceProxy.MINIMUM_VOTING_DURATION(), 1 minutes);

    // it sets MINIMUM_EXECUTION_GRACE_PERIOD to 1 hour
    assertEq(daoSpaceProxy.MINIMUM_EXECUTION_GRACE_PERIOD(), 1 hours);

    // it sets RATIO_BASE to 10e6
    assertEq(daoSpaceProxy.RATIO_BASE(), 10e6);

    // it sets FAST_PATH_RESTRICTED to keccak256('FAST_PATH_RESTRICTED')
    assertEq(daoSpaceProxy.FAST_PATH_RESTRICTED(), keccak256('FAST_PATH_RESTRICTED'));

    // it sets SPACE_REGISTRY to keccak256('SPACE_REGISTRY')
    assertEq(daoSpaceProxy.SPACE_REGISTRY(), keccak256('SPACE_REGISTRY'));

    // it sets EDITOR to keccak256('EDITOR')
    assertEq(daoSpaceProxy.EDITOR(), keccak256('EDITOR'));

    // it sets MEMBER to keccak256('MEMBER')
    assertEq(daoSpaceProxy.MEMBER(), keccak256('MEMBER'));

    // it sets DAO to keccak256('DAO')
    assertEq(daoSpaceProxy.DAO(), keccak256('DAO'));

    // it sets _DAO_SPACE_STORAGE_LOCATION to keccak256(abi.encode(uint256(keccak256("geo.storage.DAOSpace")) - 1)) & ~bytes32(uint256(0xff))
    assertEq(
      daoSpaceProxy.exposed__DAO_SPACE_STORAGE_LOCATION(),
      keccak256(abi.encode(uint256(keccak256('geo.storage.DAOSpace')) - 1)) & ~bytes32(uint256(0xff))
    );
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

  /// @dev Uses the proxy deployed in `setUp` (standard creation, `_daoSpaceId == 0`).
  function test_Initialize_WhenDelegateCalled() external view whenDelegateCalled {
    // it sets the spaceRegistry
    assertEq(address(daoSpaceProxy.spaceRegistry()), _spaceRegistry);

    // it sets addMember as a valid fast path action
    assertTrue(daoSpaceProxy.actionIsFastPathValid(IDAOSpace.addMember.selector));

    // it sets removeMember as a valid fast path action
    assertTrue(daoSpaceProxy.actionIsFastPathValid(IDAOSpace.removeMember.selector));

    // it sets ping as a valid fast path action
    assertTrue(daoSpaceProxy.actionIsFastPathValid(IDAOSpace.ping.selector));
  }

  modifier when_daoSpaceIdIsZero() {
    _;
  }

  /// @dev Mocks require `registerSpaceId`, `_ping` / `enter` calls, and role grants; failure means init did not follow the zero-`daoSpaceId` path.
  function test_Initialize_When_daoSpaceIdIsZero(
    address __spaceRegistry,
    bytes memory __publishEditsData,
    bytes16 __initialTopicId
  ) external whenDelegateCalled {
    _assumeFuzzable(__spaceRegistry);

    // get predicted DAO Space address for external calls and event emissions
    address _predictedDAOSpaceProxy = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));

    // it calls spaceRegistry to register space ID
    bytes16 _predictedDAOSpaceProxySpaceId = _getSpaceId(_predictedDAOSpaceProxy);
    _mockRegisterSpaceId(__spaceRegistry, _spaceType, _spaceVersion, _predictedDAOSpaceProxySpaceId);

    // mock mapping fetch with ping
    _mockAddressToSpaceId(__spaceRegistry, _predictedDAOSpaceProxy, _predictedDAOSpaceProxySpaceId);

    // it calls enter on the spaceRegistry with the EDITS_PUBLISHED action
    if (__publishEditsData.length != 0) {
      _mockEnter(
        __spaceRegistry,
        _predictedDAOSpaceProxySpaceId,
        _predictedDAOSpaceProxySpaceId,
        ActionsConstants.EDITS_PUBLISHED,
        '',
        __publishEditsData
      );
    }

    // it calls enter on the spaceRegistry with the TOPIC_SET action
    if (__initialTopicId != bytes16(0)) {
      _mockEnter(
        __spaceRegistry,
        _predictedDAOSpaceProxySpaceId,
        _predictedDAOSpaceProxySpaceId,
        ActionsConstants.TOPIC_SET,
        bytes32(__initialTopicId),
        ''
      );
    }

    // it calls enter on the spaceRegistry with the EDITOR_ADDED action
    _mockEnter(
      __spaceRegistry,
      _predictedDAOSpaceProxySpaceId,
      _predictedDAOSpaceProxySpaceId,
      ActionsConstants.EDITOR_ADDED,
      bytes32(_initialEditorASpaceId),
      ''
    );
    _mockEnter(
      __spaceRegistry,
      _predictedDAOSpaceProxySpaceId,
      _predictedDAOSpaceProxySpaceId,
      ActionsConstants.EDITOR_ADDED,
      bytes32(_initialEditorBSpaceId),
      ''
    );

    // it calls enter on the spaceRegistry with the VOTING_SETTINGS_UPDATED action
    _mockEnter(
      __spaceRegistry,
      _predictedDAOSpaceProxySpaceId,
      _predictedDAOSpaceProxySpaceId,
      ActionsConstants.VOTING_SETTINGS_UPDATED,
      '',
      abi.encode(_votingSettings)
    );

    // it calls enter with SPACE_FAST_PATH_RESTRICTED then MEMBER_ADDED for each initial member (disable fast path)
    _mockEnter(
      __spaceRegistry,
      _predictedDAOSpaceProxySpaceId,
      _predictedDAOSpaceProxySpaceId,
      ActionsConstants.SPACE_FAST_PATH_RESTRICTED,
      bytes32(_initialMemberASpaceId),
      abi.encode(_initialMemberASpaceId)
    );
    _mockEnter(
      __spaceRegistry,
      _predictedDAOSpaceProxySpaceId,
      _predictedDAOSpaceProxySpaceId,
      ActionsConstants.MEMBER_ADDED,
      bytes32(_initialMemberASpaceId),
      ''
    );
    _mockEnter(
      __spaceRegistry,
      _predictedDAOSpaceProxySpaceId,
      _predictedDAOSpaceProxySpaceId,
      ActionsConstants.SPACE_FAST_PATH_RESTRICTED,
      bytes32(_initialMemberBSpaceId),
      abi.encode(_initialMemberBSpaceId)
    );
    _mockEnter(
      __spaceRegistry,
      _predictedDAOSpaceProxySpaceId,
      _predictedDAOSpaceProxySpaceId,
      ActionsConstants.MEMBER_ADDED,
      bytes32(_initialMemberBSpaceId),
      ''
    );

    // when delegate called
    daoSpaceProxy = MockDAOSpace(
      UnsafeUpgrades.deployBeaconProxy(
        daoSpaceBeacon,
        abi.encodeCall(
          IDAOSpace.initialize,
          (abi.encode(
              __spaceRegistry,
              _votingSettings,
              _initialEditors,
              _initialMembers,
              __publishEditsData,
              __initialTopicId,
              bytes16(0)
            ))
        )
      )
    );
    _daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));

    // when _daoSpaceId is zero — it sets totalEditors
    assertEq(daoSpaceProxy.totalEditors(), 2);

    // it sets the voting settings
    assertEq(abi.encode(daoSpaceProxy.votingSettings()), abi.encode(_votingSettings));

    // it grants the new editor the EDITOR role
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _initialEditorASpaceId));
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _initialEditorBSpaceId));

    // it grants the new member the MEMBER role
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _initialMemberASpaceId));
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _initialMemberBSpaceId));
  }

  function test_Initialize_WhenAnInitialEditorAlreadyHasTheEDITORRole(address __spaceRegistry) external {
    _assumeFuzzable(__spaceRegistry);

    address _predictedDAOSpaceProxy = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
    bytes16 _predictedDAOSpaceProxySpaceId = _getSpaceId(_predictedDAOSpaceProxy);
    _mockRegisterSpaceId(__spaceRegistry, _spaceType, _spaceVersion, _predictedDAOSpaceProxySpaceId);
    _mockAddressToSpaceId(__spaceRegistry, _predictedDAOSpaceProxy, _predictedDAOSpaceProxySpaceId);

    bytes16[] memory _duplicateEditors = new bytes16[](2);
    _duplicateEditors[0] = _initialEditorASpaceId;
    _duplicateEditors[1] = _initialEditorASpaceId;

    _mockEnter(
      __spaceRegistry,
      _predictedDAOSpaceProxySpaceId,
      _predictedDAOSpaceProxySpaceId,
      ActionsConstants.EDITOR_ADDED,
      bytes32(_initialEditorASpaceId),
      ''
    );

    // it reverts with InvalidSpaceIdForRole
    vm.expectRevert(IDAOSpace.InvalidSpaceIdForRole.selector);
    MockDAOSpace(
      UnsafeUpgrades.deployBeaconProxy(
        daoSpaceBeacon,
        abi.encodeCall(
          IDAOSpace.initialize,
          (abi.encode(
              __spaceRegistry, _votingSettings, _duplicateEditors, _initialMembers, bytes(''), bytes16(0), bytes16(0)
            ))
        )
      )
    );
  }

  function test_Initialize_WhenAnInitialMemberAlreadyHasTheMEMBERRole(address __spaceRegistry) external {
    _assumeFuzzable(__spaceRegistry);

    address _predictedDAOSpaceProxy = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
    bytes16 _predictedDAOSpaceProxySpaceId = _getSpaceId(_predictedDAOSpaceProxy);
    _mockRegisterSpaceId(__spaceRegistry, _spaceType, _spaceVersion, _predictedDAOSpaceProxySpaceId);
    _mockAddressToSpaceId(__spaceRegistry, _predictedDAOSpaceProxy, _predictedDAOSpaceProxySpaceId);

    bytes16[] memory _duplicateMembers = new bytes16[](2);
    _duplicateMembers[0] = _initialMemberASpaceId;
    _duplicateMembers[1] = _initialMemberASpaceId;

    _mockEnter(
      __spaceRegistry,
      _predictedDAOSpaceProxySpaceId,
      _predictedDAOSpaceProxySpaceId,
      ActionsConstants.EDITOR_ADDED,
      bytes32(_initialEditorASpaceId),
      ''
    );
    _mockEnter(
      __spaceRegistry,
      _predictedDAOSpaceProxySpaceId,
      _predictedDAOSpaceProxySpaceId,
      ActionsConstants.EDITOR_ADDED,
      bytes32(_initialEditorBSpaceId),
      ''
    );
    _mockEnter(
      __spaceRegistry,
      _predictedDAOSpaceProxySpaceId,
      _predictedDAOSpaceProxySpaceId,
      ActionsConstants.VOTING_SETTINGS_UPDATED,
      '',
      abi.encode(_votingSettings)
    );
    _mockEnter(
      __spaceRegistry,
      _predictedDAOSpaceProxySpaceId,
      _predictedDAOSpaceProxySpaceId,
      ActionsConstants.SPACE_FAST_PATH_RESTRICTED,
      bytes32(_initialMemberASpaceId),
      abi.encode(_initialMemberASpaceId)
    );
    _mockEnter(
      __spaceRegistry,
      _predictedDAOSpaceProxySpaceId,
      _predictedDAOSpaceProxySpaceId,
      ActionsConstants.MEMBER_ADDED,
      bytes32(_initialMemberASpaceId),
      ''
    );

    // it reverts with InvalidSpaceIdForRole
    vm.expectRevert(IDAOSpace.InvalidSpaceIdForRole.selector);
    MockDAOSpace(
      UnsafeUpgrades.deployBeaconProxy(
        daoSpaceBeacon,
        abi.encodeCall(
          IDAOSpace.initialize,
          (abi.encode(
              __spaceRegistry, _votingSettings, _initialEditors, _duplicateMembers, bytes(''), bytes16(0), bytes16(0)
            ))
        )
      )
    );
  }

  modifier when_daoSpaceIdIsNon_zero() {
    _;
  }

  function test_Initialize_When_daoSpaceIdIsNon_zero(address __spaceRegistry) external {
    _assumeFuzzable(__spaceRegistry);

    daoSpaceProxy = MockDAOSpace(
      UnsafeUpgrades.deployBeaconProxy(
        daoSpaceBeacon,
        abi.encodeCall(
          IDAOSpace.initialize,
          (abi.encode(
              __spaceRegistry,
              _votingSettings,
              _initialEditors,
              _initialMembers,
              _publishEditsData,
              _initialTopicId,
              _transplantDAOSpaceId
            ))
        )
      )
    );
    _daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));

    // it sets the spaceRegistry
    assertEq(address(daoSpaceProxy.spaceRegistry()), __spaceRegistry);

    // it sets addMember as a valid fast path action
    assertTrue(daoSpaceProxy.actionIsFastPathValid(IDAOSpace.addMember.selector));

    // it sets removeMember as a valid fast path action
    assertTrue(daoSpaceProxy.actionIsFastPathValid(IDAOSpace.removeMember.selector));

    // it sets ping as a valid fast path action
    assertTrue(daoSpaceProxy.actionIsFastPathValid(IDAOSpace.ping.selector));

    // when _daoSpaceId is non-zero — it sets totalEditors
    assertEq(daoSpaceProxy.totalEditors(), 2);

    // it sets the voting settings
    assertEq(abi.encode(daoSpaceProxy.votingSettings()), abi.encode(_votingSettings));

    // it grants the new editor the EDITOR role
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _initialEditorASpaceId));
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _initialEditorBSpaceId));

    // it grants the new member the MEMBER role
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _initialMemberASpaceId));
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _initialMemberBSpaceId));
  }

  function test_Initialize_WhenDisableFastPathAccessForNewMembersIsTrue()
    external
    whenDelegateCalled
    when_daoSpaceIdIsNon_zero
  {
    daoSpaceProxy = MockDAOSpace(
      UnsafeUpgrades.deployBeaconProxy(
        daoSpaceBeacon,
        abi.encodeCall(
          IDAOSpace.initialize,
          (abi.encode(
              _spaceRegistry,
              _votingSettings,
              _initialEditors,
              _initialMembers,
              _publishEditsData,
              _initialTopicId,
              _transplantDAOSpaceId
            ))
        )
      )
    );

    // it grants FAST_PATH_RESTRICTED to initial members who are not editors
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.FAST_PATH_RESTRICTED(), _initialMemberASpaceId));
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.FAST_PATH_RESTRICTED(), _initialMemberBSpaceId));
  }

  function test_Initialize_WhenDisableFastPathAccessForNewMembersIsFalse()
    external
    whenDelegateCalled
    when_daoSpaceIdIsNon_zero
  {
    IDAOSpace.VotingSettings memory _vs = _votingSettings;
    _vs.disableFastPathAccessForNewMembers = false;

    daoSpaceProxy = MockDAOSpace(
      UnsafeUpgrades.deployBeaconProxy(
        daoSpaceBeacon,
        abi.encodeCall(
          IDAOSpace.initialize,
          (abi.encode(
              _spaceRegistry,
              _vs,
              _initialEditors,
              _initialMembers,
              _publishEditsData,
              _initialTopicId,
              _transplantDAOSpaceId
            ))
        )
      )
    );

    // it does not grant FAST_PATH_RESTRICTED to initial members
    assertFalse(daoSpaceProxy.hasRole(daoSpaceProxy.FAST_PATH_RESTRICTED(), _initialMemberASpaceId));
    assertFalse(daoSpaceProxy.hasRole(daoSpaceProxy.FAST_PATH_RESTRICTED(), _initialMemberBSpaceId));
  }

  function test_Initialize_WhenAnInitialEditorAlreadyHasTheEDITORRole_When_daoSpaceIdIsNon_zero(address __spaceRegistry)
    external
  {
    _assumeFuzzable(__spaceRegistry);

    bytes16[] memory _duplicateEditors = new bytes16[](2);
    _duplicateEditors[0] = _initialEditorASpaceId;
    _duplicateEditors[1] = _initialEditorASpaceId;

    // it reverts with InvalidSpaceIdForRole
    vm.expectRevert(IDAOSpace.InvalidSpaceIdForRole.selector);
    MockDAOSpace(
      UnsafeUpgrades.deployBeaconProxy(
        daoSpaceBeacon,
        abi.encodeCall(
          IDAOSpace.initialize,
          (abi.encode(
              __spaceRegistry,
              _votingSettings,
              _duplicateEditors,
              _initialMembers,
              bytes(''),
              bytes16(0),
              _transplantDAOSpaceId
            ))
        )
      )
    );
  }

  function test_Initialize_WhenAnInitialMemberAlreadyHasTheMEMBERRole_When_daoSpaceIdIsNon_zero(address __spaceRegistry)
    external
  {
    _assumeFuzzable(__spaceRegistry);

    bytes16[] memory _duplicateMembers = new bytes16[](2);
    _duplicateMembers[0] = _initialMemberASpaceId;
    _duplicateMembers[1] = _initialMemberASpaceId;

    // it reverts with InvalidSpaceIdForRole
    vm.expectRevert(IDAOSpace.InvalidSpaceIdForRole.selector);
    MockDAOSpace(
      UnsafeUpgrades.deployBeaconProxy(
        daoSpaceBeacon,
        abi.encodeCall(
          IDAOSpace.initialize,
          (abi.encode(
              __spaceRegistry,
              _votingSettings,
              _initialEditors,
              _duplicateMembers,
              bytes(''),
              bytes16(0),
              _transplantDAOSpaceId
            ))
        )
      )
    );
  }

  function test_Initialize_WhenPartialPercentageSupportThresholdIsGreaterThanRATIO_BASE(
    address __spaceRegistry,
    uint256 _partialPercentageSupportThreshold
  ) external when_daoSpaceIdIsNon_zero {
    _assumeFuzzable(__spaceRegistry);
    vm.assume(_partialPercentageSupportThreshold > daoSpaceImplementation.RATIO_BASE());
    IDAOSpace.VotingSettings memory _vs = _votingSettings;
    _vs.partialPercentageSupportThreshold = _partialPercentageSupportThreshold;

    // it reverts with InvalidSetting
    vm.expectRevert(IDAOSpace.InvalidSetting.selector);
    MockDAOSpace(
      UnsafeUpgrades.deployBeaconProxy(
        daoSpaceBeacon,
        abi.encodeCall(
          IDAOSpace.initialize,
          (abi.encode(
              __spaceRegistry, _vs, _initialEditors, _initialMembers, bytes(''), bytes16(0), _transplantDAOSpaceId
            ))
        )
      )
    );
  }

  function test_Initialize_WhenUniversalPercentageSupportThresholdIsGreaterThanRATIO_BASE(
    address __spaceRegistry,
    uint256 _universalPercentageSupportThreshold
  ) external when_daoSpaceIdIsNon_zero {
    _assumeFuzzable(__spaceRegistry);
    vm.assume(_universalPercentageSupportThreshold > daoSpaceImplementation.RATIO_BASE());
    IDAOSpace.VotingSettings memory _vs = _votingSettings;
    _vs.universalPercentageSupportThreshold = _universalPercentageSupportThreshold;

    // it reverts with InvalidSetting
    vm.expectRevert(IDAOSpace.InvalidSetting.selector);
    MockDAOSpace(
      UnsafeUpgrades.deployBeaconProxy(
        daoSpaceBeacon,
        abi.encodeCall(
          IDAOSpace.initialize,
          (abi.encode(
              __spaceRegistry, _vs, _initialEditors, _initialMembers, bytes(''), bytes16(0), _transplantDAOSpaceId
            ))
        )
      )
    );
  }

  function test_Initialize_WhenFlatSupportThresholdIsGreaterThanTotalEditors(
    address __spaceRegistry,
    uint256 _flatSupportThreshold
  ) external when_daoSpaceIdIsNon_zero {
    _assumeFuzzable(__spaceRegistry);
    vm.assume(_flatSupportThreshold > _initialEditors.length);
    IDAOSpace.VotingSettings memory _vs = _votingSettings;
    _vs.flatSupportThreshold = _flatSupportThreshold;

    // it reverts with InvalidSetting
    vm.expectRevert(IDAOSpace.InvalidSetting.selector);
    MockDAOSpace(
      UnsafeUpgrades.deployBeaconProxy(
        daoSpaceBeacon,
        abi.encodeCall(
          IDAOSpace.initialize,
          (abi.encode(
              __spaceRegistry, _vs, _initialEditors, _initialMembers, bytes(''), bytes16(0), _transplantDAOSpaceId
            ))
        )
      )
    );
  }

  function test_Initialize_WhenQuorumIsGreaterThanTotalEditors(
    address __spaceRegistry,
    uint256 _quorum
  ) external when_daoSpaceIdIsNon_zero {
    _assumeFuzzable(__spaceRegistry);
    vm.assume(_quorum > _initialEditors.length);
    IDAOSpace.VotingSettings memory _vs = _votingSettings;
    _vs.quorum = _quorum;

    // it reverts with InvalidSetting
    vm.expectRevert(IDAOSpace.InvalidSetting.selector);
    MockDAOSpace(
      UnsafeUpgrades.deployBeaconProxy(
        daoSpaceBeacon,
        abi.encodeCall(
          IDAOSpace.initialize,
          (abi.encode(
              __spaceRegistry, _vs, _initialEditors, _initialMembers, bytes(''), bytes16(0), _transplantDAOSpaceId
            ))
        )
      )
    );
  }

  function test_Initialize_WhenDurationIsLessThanMINIMUM_VOTING_DURATION(
    address __spaceRegistry,
    uint256 _duration
  ) external when_daoSpaceIdIsNon_zero {
    _assumeFuzzable(__spaceRegistry);
    vm.assume(_duration < daoSpaceImplementation.MINIMUM_VOTING_DURATION());
    IDAOSpace.VotingSettings memory _vs = _votingSettings;
    _vs.duration = _duration;

    // it reverts with InvalidSetting
    vm.expectRevert(IDAOSpace.InvalidSetting.selector);
    MockDAOSpace(
      UnsafeUpgrades.deployBeaconProxy(
        daoSpaceBeacon,
        abi.encodeCall(
          IDAOSpace.initialize,
          (abi.encode(
              __spaceRegistry, _vs, _initialEditors, _initialMembers, bytes(''), bytes16(0), _transplantDAOSpaceId
            ))
        )
      )
    );
  }

  function test_Initialize_WhenExecutionGracePeriodIsLessThanMINIMUM_EXECUTION_GRACE_PERIOD(
    address __spaceRegistry,
    uint256 _executionGracePeriod
  ) external when_daoSpaceIdIsNon_zero {
    _assumeFuzzable(__spaceRegistry);
    vm.assume(_executionGracePeriod < daoSpaceImplementation.MINIMUM_EXECUTION_GRACE_PERIOD());
    IDAOSpace.VotingSettings memory _vs = _votingSettings;
    _vs.executionGracePeriod = _executionGracePeriod;

    // it reverts with InvalidSetting
    vm.expectRevert(IDAOSpace.InvalidSetting.selector);
    MockDAOSpace(
      UnsafeUpgrades.deployBeaconProxy(
        daoSpaceBeacon,
        abi.encodeCall(
          IDAOSpace.initialize,
          (abi.encode(
              __spaceRegistry, _vs, _initialEditors, _initialMembers, bytes(''), bytes16(0), _transplantDAOSpaceId
            ))
        )
      )
    );
  }

  function test_Initialize_WhenDelegateCalledAgain(
    address __spaceRegistry,
    bytes memory __publishEditsData,
    bytes16 __initialTopicId
  ) external whenDelegateCalled {
    _assumeFuzzable(__spaceRegistry);

    // get predicted DAO Space address for external calls and event emissions
    address _predictedDAOSpaceProxy = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));

    // it calls spaceRegistry to register space ID
    bytes16 _predictedDAOSpaceProxySpaceId = _getSpaceId(_predictedDAOSpaceProxy);
    _mockRegisterSpaceId(__spaceRegistry, _spaceType, _spaceVersion, _predictedDAOSpaceProxySpaceId);

    // mock mapping fetch with ping
    _mockAddressToSpaceId(__spaceRegistry, _predictedDAOSpaceProxy, _predictedDAOSpaceProxySpaceId);

    // it calls enter on the spaceRegistry with the EDITS_PUBLISHED action
    if (__publishEditsData.length != 0) {
      _mockEnter(
        __spaceRegistry,
        _predictedDAOSpaceProxySpaceId,
        _predictedDAOSpaceProxySpaceId,
        ActionsConstants.EDITS_PUBLISHED,
        '',
        __publishEditsData
      );
    }

    // it calls enter on the spaceRegistry with the TOPIC_SET action
    if (__initialTopicId != bytes16(0)) {
      _mockEnter(
        __spaceRegistry,
        _predictedDAOSpaceProxySpaceId,
        _predictedDAOSpaceProxySpaceId,
        ActionsConstants.TOPIC_SET,
        bytes32(__initialTopicId),
        ''
      );
    }

    // it calls enter on the spaceRegistry with the EDITOR_ADDED action
    _mockEnter(
      __spaceRegistry,
      _predictedDAOSpaceProxySpaceId,
      _predictedDAOSpaceProxySpaceId,
      ActionsConstants.EDITOR_ADDED,
      bytes32(_initialEditorASpaceId),
      ''
    );
    _mockEnter(
      __spaceRegistry,
      _predictedDAOSpaceProxySpaceId,
      _predictedDAOSpaceProxySpaceId,
      ActionsConstants.EDITOR_ADDED,
      bytes32(_initialEditorBSpaceId),
      ''
    );

    // it calls enter on the spaceRegistry with the VOTING_SETTINGS_UPDATED action
    _mockEnter(
      __spaceRegistry,
      _predictedDAOSpaceProxySpaceId,
      _predictedDAOSpaceProxySpaceId,
      ActionsConstants.VOTING_SETTINGS_UPDATED,
      '',
      abi.encode(_votingSettings)
    );

    // it calls enter with SPACE_FAST_PATH_RESTRICTED then MEMBER_ADDED for each initial member (disable fast path)
    _mockEnter(
      __spaceRegistry,
      _predictedDAOSpaceProxySpaceId,
      _predictedDAOSpaceProxySpaceId,
      ActionsConstants.SPACE_FAST_PATH_RESTRICTED,
      bytes32(_initialMemberASpaceId),
      abi.encode(_initialMemberASpaceId)
    );
    _mockEnter(
      __spaceRegistry,
      _predictedDAOSpaceProxySpaceId,
      _predictedDAOSpaceProxySpaceId,
      ActionsConstants.MEMBER_ADDED,
      bytes32(_initialMemberASpaceId),
      ''
    );
    _mockEnter(
      __spaceRegistry,
      _predictedDAOSpaceProxySpaceId,
      _predictedDAOSpaceProxySpaceId,
      ActionsConstants.SPACE_FAST_PATH_RESTRICTED,
      bytes32(_initialMemberBSpaceId),
      abi.encode(_initialMemberBSpaceId)
    );
    _mockEnter(
      __spaceRegistry,
      _predictedDAOSpaceProxySpaceId,
      _predictedDAOSpaceProxySpaceId,
      ActionsConstants.MEMBER_ADDED,
      bytes32(_initialMemberBSpaceId),
      ''
    );

    // when delegate called
    daoSpaceProxy = MockDAOSpace(
      UnsafeUpgrades.deployBeaconProxy(
        daoSpaceBeacon,
        abi.encodeCall(
          IDAOSpace.initialize,
          (abi.encode(
              __spaceRegistry,
              _votingSettings,
              _initialEditors,
              _initialMembers,
              __publishEditsData,
              __initialTopicId,
              bytes16(0)
            ))
        )
      )
    );
    _daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));

    // it reverts with InvalidInitialization
    vm.expectRevert(Initializable.InvalidInitialization.selector);

    // when delegate called again
    daoSpaceProxy.initialize(
      abi.encode(
        __spaceRegistry,
        _votingSettings,
        _initialEditors,
        _initialMembers,
        __publishEditsData,
        __initialTopicId,
        bytes16(0)
      )
    );
  }

  function test_Initialize_WhenCalled() external {
    // it reverts with InvalidInitialization
    vm.expectRevert(Initializable.InvalidInitialization.selector);

    // when called again
    daoSpaceProxy.initialize(
      abi.encode(
        _spaceRegistry,
        _votingSettings,
        _initialEditors,
        _initialMembers,
        _publishEditsData,
        _initialTopicId,
        bytes16(0)
      )
    );
  }

  modifier whenRoleIsSPACE_REGISTRY() {
    _;
  }

  /// _onlyRole ///

  function test__onlyRole_WhenCalledBySpaceRegistry() external whenRoleIsSPACE_REGISTRY {
    bytes32 _spaceRegistryRole = daoSpaceImplementation.SPACE_REGISTRY();
    vm.prank(_spaceRegistry);

    // it does not revert
    daoSpaceProxy.exposed__onlyRole(_spaceRegistryRole);
  }

  function test__onlyRole_WhenCalledByNon_spaceRegistry(address _caller) external whenRoleIsSPACE_REGISTRY {
    vm.assume(_caller != _spaceRegistry);
    bytes32 _spaceRegistryRole = daoSpaceImplementation.SPACE_REGISTRY();
    vm.prank(_caller);

    // it reverts with InvalidCaller
    vm.expectRevert(IDAOSpace.InvalidCaller.selector);
    daoSpaceProxy.exposed__onlyRole(_spaceRegistryRole);
  }

  modifier whenRoleIsDAO() {
    _;
  }

  function test__onlyRole_WhenCalledByDAO() external whenRoleIsDAO {
    bytes32 _daoRole = daoSpaceImplementation.DAO();
    vm.prank(address(daoSpaceProxy));

    // it does not revert
    daoSpaceProxy.exposed__onlyRole(_daoRole);
  }

  function test__onlyRole_WhenCalledByNon_DAO(address _caller) external whenRoleIsDAO {
    vm.assume(_caller != address(daoSpaceProxy));
    bytes32 _daoRole = daoSpaceImplementation.DAO();
    vm.prank(_caller);

    // it reverts with InvalidCaller
    vm.expectRevert(IDAOSpace.InvalidCaller.selector);
    daoSpaceProxy.exposed__onlyRole(_daoRole);
  }

  modifier whenRoleIsNeitherSPACE_REGISTRYNorDAO() {
    _;
  }

  function test__onlyRole_WhenCallerHasRole(
    bytes32 __role,
    address __caller
  ) external whenRoleIsNeitherSPACE_REGISTRYNorDAO {
    vm.assume(__role != daoSpaceImplementation.SPACE_REGISTRY());
    vm.assume(__role != daoSpaceImplementation.DAO());
    _assumeFuzzable(__caller);

    bytes16 __callerSpaceId = _getSpaceId(__caller);
    _mockAddressToSpaceId(_spaceRegistry, __caller, __callerSpaceId);
    daoSpaceProxy.workaround_grantRole(__role, __callerSpaceId);
    assertTrue(daoSpaceProxy.hasRole(__role, __callerSpaceId));
    vm.prank(__caller);

    // it does not revert
    daoSpaceProxy.exposed__onlyRole(__role);
  }

  function test__onlyRole_WhenCallerDoesNotHaveRole(
    bytes32 __role,
    address __caller
  ) external whenRoleIsNeitherSPACE_REGISTRYNorDAO {
    vm.assume(__role != daoSpaceImplementation.SPACE_REGISTRY());
    vm.assume(__role != daoSpaceImplementation.DAO());
    _assumeFuzzable(__caller);

    bytes16 __callerSpaceId = _getSpaceId(__caller);
    _mockAddressToSpaceId(_spaceRegistry, __caller, __callerSpaceId);
    assertFalse(daoSpaceProxy.hasRole(__role, __callerSpaceId));
    vm.prank(__caller);

    // it reverts with InvalidCaller
    vm.expectRevert(IDAOSpace.InvalidCaller.selector);
    daoSpaceProxy.exposed__onlyRole(__role);
  }

  function test__onlyRole_WhenCallerSpaceIdIsNotRegistered(
    bytes32 __role,
    address __caller
  ) external whenRoleIsNeitherSPACE_REGISTRYNorDAO {
    vm.assume(__role != daoSpaceImplementation.SPACE_REGISTRY());
    vm.assume(__role != daoSpaceImplementation.DAO());
    _assumeFuzzable(__caller);

    vm.mockCall(_spaceRegistry, abi.encodeCall(ISpaceRegistry.addressToSpaceId, (__caller)), abi.encode(bytes16(0)));
    vm.prank(__caller);

    // it reverts with InvalidCaller
    vm.expectRevert(IDAOSpace.InvalidCaller.selector);
    daoSpaceProxy.exposed__onlyRole(__role);
  }

  /// WRITE - PROPOSAL CREATED ///

  modifier whenCalledBySpaceRegistry() {
    vm.startPrank(_spaceRegistry);
    _;
    vm.stopPrank();
  }

  modifier when_actionEqualsPROPOSAL_CREATED() {
    _;
  }

  modifier whenTheVotingModeIsSlow() {
    _;
  }

  function test_Write_When_fromSpaceIdIsNotAMemberOrEditor(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_CREATED
    whenTheVotingModeIsSlow
  {
    // it reverts with InvalidFromSpace
    vm.expectRevert(IDAOSpace.InvalidFromSpace.selector);

    bytes memory _createProposalData = _createSlowPathProposalToAddEditor();
    daoSpaceProxy.write(_randomCallerSpaceId, ActionsConstants.PROPOSAL_CREATED, _subject, _createProposalData);
  }

  function test_Write_When_proposalIdHasAlreadyBeenUsed(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_CREATED
    whenTheVotingModeIsSlow
  {
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      _proposalVersion,
      _randomCallerSpaceId,
      1,
      1,
      1,
      IDAOSpace.VotingMode.Slow,
      1,
      1,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    // it reverts with InvalidProposalId
    vm.expectRevert(IDAOSpace.InvalidProposalId.selector);

    bytes memory _createProposalData = _createSlowPathProposalToAddEditor();
    daoSpaceProxy.write(_randomCallerSpaceId, ActionsConstants.PROPOSAL_CREATED, _subject, _createProposalData);
  }

  function test_Write_When_createProposalParamsAreValid(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_CREATED
    whenTheVotingModeIsSlow
  {
    // it calls enter on the spaceRegistry with the PROPOSAL_SETTINGS_SELECTED action
    _mockEnter(
      _spaceRegistry,
      _daoSpaceProxySpaceId,
      _daoSpaceProxySpaceId,
      ActionsConstants.PROPOSAL_SETTINGS_SELECTED,
      bytes32(_proposalId),
      abi.encode(
        IDAOSpace.ProposalParameters({
          votingMode: IDAOSpace.VotingMode.Slow,
          partialPercentageSupportThreshold: _votingSettings.partialPercentageSupportThreshold,
          universalPercentageSupportThreshold: _votingSettings.universalPercentageSupportThreshold,
          flatSupportThreshold: _votingSettings.flatSupportThreshold,
          quorum: _votingSettings.quorum,
          startDate: 0,
          lastDate: 0,
          executeBy: 0
        })
      )
    );

    // when called
    bytes memory _createProposalData = _createSlowPathProposalToAddEditor();
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_CREATED, _subject, _createProposalData);

    (, bytes16 _creator, IDAOSpace.ProposalParameters memory _parameters,, IDAOSpace.Action[] memory _actions) =
      daoSpaceProxy.getLatestProposalInformation(_proposalId);

    // it increments the proposal version
    assertEq(daoSpaceProxy.latestProposalVersion(_proposalId), 1);

    // it sets the proposal creator to _fromSpaceId
    assertEq(_creator, _initialEditorASpaceId);

    // it sets the proposal voting mode to the slow path
    assertEq(uint256(_parameters.votingMode), uint256(IDAOSpace.VotingMode.Slow));

    // it sets the proposal quorum to votingSettings.quorum
    assertEq(_parameters.quorum, _votingSettings.quorum);

    // it sets the proposal partial percentage support threshold to votingSettings.partialPercentageSupportThreshold
    assertEq(_parameters.partialPercentageSupportThreshold, _votingSettings.partialPercentageSupportThreshold);

    // it sets the proposal universal percentage support threshold to votingSettings.universalPercentageSupportThreshold
    assertEq(_parameters.universalPercentageSupportThreshold, _votingSettings.universalPercentageSupportThreshold);

    // it sets the proposal flat support threshold to votingSettings.flatSupportThreshold
    assertEq(_parameters.flatSupportThreshold, _votingSettings.flatSupportThreshold);

    // it stores the decoded proposal actions
    assertEq(_actions.length, 1);
    assertEq(_actions[0].to, address(daoSpaceProxy));
    assertEq(_actions[0].value, 0);
    assertEq(_actions[0].data, abi.encodeCall(IDAOSpace.addEditor, (_randomCallerSpaceId)));
  }

  modifier whenTheVotingModeIsFast() {
    _;
  }

  function test_Write_When_fromSpaceIdIsNotAMemberOrEditor_WhenTheVotingModeIsFast(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_CREATED
    whenTheVotingModeIsFast
  {
    // it reverts with InvalidFromSpace
    vm.expectRevert(IDAOSpace.InvalidFromSpace.selector);

    bytes memory _createProposalData = _createFastPathProposalToAddMember();
    daoSpaceProxy.write(_randomCallerSpaceId, ActionsConstants.PROPOSAL_CREATED, _subject, _createProposalData);
  }

  function test_Write_When_proposalIdHasAlreadyBeenUsed_WhenTheVotingModeIsFast(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_CREATED
    whenTheVotingModeIsFast
  {
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      _proposalVersion,
      _randomCallerSpaceId,
      1,
      1,
      1,
      IDAOSpace.VotingMode.Fast,
      1,
      1,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    // it reverts with InvalidProposalId
    vm.expectRevert(IDAOSpace.InvalidProposalId.selector);

    bytes memory _createProposalData = _createFastPathProposalToAddMember();
    daoSpaceProxy.write(_randomCallerSpaceId, ActionsConstants.PROPOSAL_CREATED, _subject, _createProposalData);
  }

  function test_Write_When_fromSpaceIdIsRestricted(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_CREATED
    whenTheVotingModeIsFast
  {
    daoSpaceProxy.workaround_grantRole(daoSpaceProxy.FAST_PATH_RESTRICTED(), _initialEditorASpaceId);

    // it reverts with FastPathRestricted
    vm.expectRevert(IDAOSpace.FastPathRestricted.selector);

    bytes memory _createProposalData = _createFastPathProposalToAddMember();
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_CREATED, _subject, _createProposalData);
  }

  function test_Write_WhenTheDecodedProposalActionIsNotLimitedToOneCall(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_CREATED
    whenTheVotingModeIsFast
  {
    // it reverts with OneActionForFastPath
    vm.expectRevert(IDAOSpace.OneActionForFastPath.selector);

    bytes memory _createProposalData = _createFastPathProposalToAddTwoMembers();
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_CREATED, _subject, _createProposalData);
  }

  function test_Write_WhenTheFunctionSelectorOfTheDecodedProposalActionIsNotFastPathValid(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_CREATED
    whenTheVotingModeIsFast
  {
    // it reverts with InvalidAction
    vm.expectRevert(IDAOSpace.InvalidAction.selector);

    bytes memory _createProposalData = _createFastPathProposalToAddEditor();
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_CREATED, _subject, _createProposalData);
  }

  function test_Write_WhenTheTargetAddressIsNotTheDAOContractItself(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_CREATED
    whenTheVotingModeIsFast
  {
    // it reverts with InvalidTarget
    vm.expectRevert(IDAOSpace.InvalidTarget.selector);

    bytes memory _createProposalData = _createFastPathProposalToAddMemberOnAnotherContract();
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_CREATED, _subject, _createProposalData);
  }

  function test_Write_WhenTheProposalAttemptsToTransferValue(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_CREATED
    whenTheVotingModeIsFast
  {
    // it reverts with InvalidFundsTransfer
    vm.expectRevert(IDAOSpace.InvalidFundsTransfer.selector);

    bytes memory _createProposalData = _createFastPathProposalToAddMemberAndMoveValue();
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_CREATED, _subject, _createProposalData);
  }

  function test_Write_When_createProposalParamsAreValid_WhenTheVotingModeIsFast(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_CREATED
    whenTheVotingModeIsFast
  {
    // it calls enter on the spaceRegistry with the PROPOSAL_SETTINGS_SELECTED action
    _mockEnter(
      _spaceRegistry,
      _daoSpaceProxySpaceId,
      _daoSpaceProxySpaceId,
      ActionsConstants.PROPOSAL_SETTINGS_SELECTED,
      bytes32(_proposalId),
      abi.encode(
        IDAOSpace.ProposalParameters({
          votingMode: IDAOSpace.VotingMode.Fast,
          partialPercentageSupportThreshold: _votingSettings.partialPercentageSupportThreshold,
          universalPercentageSupportThreshold: _votingSettings.universalPercentageSupportThreshold,
          flatSupportThreshold: _votingSettings.flatSupportThreshold,
          quorum: _votingSettings.quorum,
          startDate: 0,
          lastDate: 0,
          executeBy: 0
        })
      )
    );

    // when called
    bytes memory _createProposalData = _createFastPathProposalToAddMember();
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_CREATED, _subject, _createProposalData);

    (, bytes16 _creator, IDAOSpace.ProposalParameters memory _parameters,, IDAOSpace.Action[] memory _actions) =
      daoSpaceProxy.getLatestProposalInformation(_proposalId);

    // it increments the proposal version
    assertEq(daoSpaceProxy.latestProposalVersion(_proposalId), 1);

    // it sets the proposal creator to _fromSpaceId
    assertEq(_creator, _initialEditorASpaceId);

    // it sets the proposal voting mode to the fast path
    assertEq(uint256(_parameters.votingMode), uint256(IDAOSpace.VotingMode.Fast));

    // it sets the proposal quorum to votingSettings.quorum
    assertEq(_parameters.quorum, _votingSettings.quorum);

    // it sets the proposal partial percentage support threshold to votingSettings.partialPercentageSupportThreshold
    assertEq(_parameters.partialPercentageSupportThreshold, _votingSettings.partialPercentageSupportThreshold);

    // it sets the proposal universal percentage support threshold to votingSettings.universalPercentageSupportThreshold
    assertEq(_parameters.universalPercentageSupportThreshold, _votingSettings.universalPercentageSupportThreshold);

    // it sets the proposal flat support threshold to votingSettings.flatSupportThreshold
    assertEq(_parameters.flatSupportThreshold, _votingSettings.flatSupportThreshold);

    // it stores the decoded proposal actions
    assertEq(_actions.length, 1);
    assertEq(_actions[0].to, address(daoSpaceProxy));
    assertEq(_actions[0].value, 0);
    assertEq(_actions[0].data, abi.encodeCall(IDAOSpace.addMember, (_randomCallerSpaceId)));
  }

  /// WRITE - PROPOSAL_VOTED ///

  modifier when_actionEqualsPROPOSAL_VOTED() {
    _;
  }

  function test_Write_WhenTheProposalDoesNotExist(
    bytes32 _subject,
    uint256 _voteOption
  ) external whenCalledBySpaceRegistry when_actionEqualsPROPOSAL_VOTED {
    _voteOption = bound(_voteOption, 1, 3);

    // it reverts with CanNotVote
    vm.expectRevert(IDAOSpace.CanNotVote.selector);

    bytes memory _voteProposalData = _createVoteForProposal(IDAOSpace.VoteOption(_voteOption));
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, _voteProposalData);
  }

  function test_Write_When_proposalVersionIsNotLatestProposalVersion(
    bytes32 _subject,
    uint8 _latestProposalVersion,
    uint256 _voteOption,
    uint256 _votingMode
  ) external whenCalledBySpaceRegistry when_actionEqualsPROPOSAL_VOTED {
    vm.assume(_latestProposalVersion != _proposalVersion);
    _voteOption = bound(_voteOption, 1, 3);
    _votingMode = bound(_votingMode, 0, 1);

    // proposal set up
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      _latestProposalVersion,
      _initialEditorASpaceId,
      vm.getBlockTimestamp(),
      vm.getBlockTimestamp() + _votingSettings.duration,
      vm.getBlockTimestamp() + _votingSettings.duration + _votingSettings.executionGracePeriod,
      IDAOSpace.VotingMode(_votingMode),
      1,
      1,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    // it reverts with CanNotVote
    vm.expectRevert(IDAOSpace.CanNotVote.selector);

    bytes memory _voteProposalData = _createVoteForProposal(IDAOSpace.VoteOption(_voteOption));
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, _voteProposalData);
  }

  function test_Write_WhenTheBlockTimestampIsGreaterThanTheLastDateWhenSet(
    bytes32 _subject,
    uint256 _voteOption,
    uint256 _votingMode
  ) external whenCalledBySpaceRegistry when_actionEqualsPROPOSAL_VOTED {
    _voteOption = bound(_voteOption, 1, 3);
    _votingMode = bound(_votingMode, 0, 1);

    uint256 _now = vm.getBlockTimestamp();

    // proposal set up with lastDate set; voting window ends one second after creation
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      _proposalVersion,
      _initialEditorASpaceId,
      _now,
      _now + 1,
      _now + _votingSettings.executionGracePeriod,
      IDAOSpace.VotingMode(_votingMode),
      1,
      1,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    vm.warp(_now + 2);

    // it reverts with CanNotVote
    vm.expectRevert(IDAOSpace.CanNotVote.selector);

    bytes memory _voteProposalData = _createVoteForProposal(IDAOSpace.VoteOption(_voteOption));
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, _voteProposalData);
  }

  function test_Write_WhenTheProposalHasBeenExecuted(
    bytes32 _subject,
    uint256 _voteOption,
    uint256 _votingMode
  ) external whenCalledBySpaceRegistry when_actionEqualsPROPOSAL_VOTED {
    _voteOption = bound(_voteOption, 1, 3);
    _votingMode = bound(_votingMode, 0, 1);

    // proposal set up
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      true,
      _proposalVersion,
      _initialEditorASpaceId,
      vm.getBlockTimestamp(),
      vm.getBlockTimestamp() + _votingSettings.duration,
      vm.getBlockTimestamp() + _votingSettings.duration + _votingSettings.executionGracePeriod,
      IDAOSpace.VotingMode(_votingMode),
      1,
      1,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    // it reverts with CanNotVote
    vm.expectRevert(IDAOSpace.CanNotVote.selector);

    bytes memory _voteProposalData = _createVoteForProposal(IDAOSpace.VoteOption(_voteOption));
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, _voteProposalData);
  }

  function test_Write_WhenTheVoteOptionEqualsNone(
    bytes32 _subject,
    uint256 _votingMode
  ) external whenCalledBySpaceRegistry when_actionEqualsPROPOSAL_VOTED {
    _votingMode = bound(_votingMode, 0, 1);

    // proposal set up
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      _proposalVersion,
      _initialEditorASpaceId,
      vm.getBlockTimestamp(),
      vm.getBlockTimestamp() + _votingSettings.duration,
      vm.getBlockTimestamp() + _votingSettings.duration + _votingSettings.executionGracePeriod,
      IDAOSpace.VotingMode(_votingMode),
      1,
      1,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    // it reverts with CanNotVote
    vm.expectRevert(IDAOSpace.CanNotVote.selector);

    bytes memory _voteProposalData = _createVoteForProposal(IDAOSpace.VoteOption.None);
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, _voteProposalData);
  }

  function test_Write_WhenThe_fromSpaceIdIsNotAnEditor(
    bytes32 _subject,
    uint256 _voteOption,
    uint256 _votingMode
  ) external whenCalledBySpaceRegistry when_actionEqualsPROPOSAL_VOTED {
    _voteOption = bound(_voteOption, 1, 3);
    _votingMode = bound(_votingMode, 0, 1);

    // proposal set up
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      _proposalVersion,
      _randomCallerSpaceId,
      vm.getBlockTimestamp(),
      vm.getBlockTimestamp() + _votingSettings.duration,
      vm.getBlockTimestamp() + _votingSettings.duration + _votingSettings.executionGracePeriod,
      IDAOSpace.VotingMode(_votingMode),
      1,
      1,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    // it reverts with CanNotVote
    vm.expectRevert(IDAOSpace.CanNotVote.selector);

    bytes memory _voteProposalData = _createVoteForProposal(IDAOSpace.VoteOption(_voteOption));
    daoSpaceProxy.write(_randomCallerSpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, _voteProposalData);
  }

  modifier when_voteParamsAreValid() {
    _;
  }

  modifier whenFirstVote() {
    _;
  }

  function test_Write_When_voteParamsAreValid(
    bytes32 _subject,
    uint256 _voteOption,
    uint256 _votingMode
  ) external whenCalledBySpaceRegistry when_actionEqualsPROPOSAL_VOTED when_voteParamsAreValid {
    _voteOption = bound(_voteOption, 1, 3);
    _votingMode = bound(_votingMode, 0, 1);

    // proposal set up
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      _proposalVersion,
      _initialEditorASpaceId,
      vm.getBlockTimestamp(),
      vm.getBlockTimestamp() + _votingSettings.duration,
      vm.getBlockTimestamp() + _votingSettings.duration + _votingSettings.executionGracePeriod,
      IDAOSpace.VotingMode(_votingMode),
      1,
      1,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    // vote
    bytes memory _voteProposalData = _createVoteForProposal(IDAOSpace.VoteOption(_voteOption));
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, _voteProposalData);

    // it stores the current _fromSpaceId vote
    IDAOSpace.VoteOption _storedVoteOption = daoSpaceProxy.getLatestProposalVote(_proposalId, _initialEditorASpaceId);
    assertEq(uint256(_storedVoteOption), _voteOption);
  }

  function test_Write_WhenFirstVote(
    bytes32 _subject,
    uint256 _votingMode,
    uint256 _voteOption
  ) external whenCalledBySpaceRegistry when_actionEqualsPROPOSAL_VOTED when_voteParamsAreValid whenFirstVote {
    _votingMode = bound(_votingMode, 0, 1);
    _voteOption = bound(_voteOption, 1, 3);

    // proposal set up
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      _proposalVersion,
      _initialEditorASpaceId,
      0,
      0,
      0,
      IDAOSpace.VotingMode(_votingMode),
      _votingSettings.quorum,
      _votingSettings.partialPercentageSupportThreshold,
      _votingSettings.universalPercentageSupportThreshold,
      _votingSettings.flatSupportThreshold,
      new IDAOSpace.Action[](0)
    );

    uint256 _voteAt = vm.getBlockTimestamp() + _votingSettings.duration + 1;
    vm.warp(_voteAt);

    IDAOSpace.VotingMode _settingsModeAfterVote = IDAOSpace.VotingMode(_votingMode);
    if (_votingMode == 1 && _voteOption == uint256(IDAOSpace.VoteOption.No)) {
      _settingsModeAfterVote = IDAOSpace.VotingMode.Slow;
    }

    _mockEnter(
      _spaceRegistry,
      _daoSpaceProxySpaceId,
      _daoSpaceProxySpaceId,
      ActionsConstants.PROPOSAL_SETTINGS_SELECTED,
      bytes32(_proposalId),
      abi.encode(_activeProposalParameters(_settingsModeAfterVote, _voteAt))
    );

    bytes memory _voteProposalData = _createVoteForProposal(IDAOSpace.VoteOption(_voteOption));
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, _voteProposalData);

    (, bytes16 _creator, IDAOSpace.ProposalParameters memory _parameters, IDAOSpace.Tally memory _tally,) =
      daoSpaceProxy.getLatestProposalInformation(_proposalId);

    // it starts the voting window from block.timestamp
    assertEq(_creator, _initialEditorASpaceId);
    assertEq(_parameters.startDate, _voteAt);
    assertEq(_parameters.lastDate, _voteAt + _votingSettings.duration);
    assertEq(_parameters.executeBy, _parameters.lastDate + _votingSettings.executionGracePeriod);
    if (_voteOption == uint256(IDAOSpace.VoteOption.Yes)) {
      assertEq(_tally.yes, 1);
      assertEq(_tally.no, 0);
      assertEq(_tally.abstain, 0);
    } else if (_voteOption == uint256(IDAOSpace.VoteOption.No)) {
      assertEq(_tally.yes, 0);
      assertEq(_tally.no, 1);
      assertEq(_tally.abstain, 0);
    } else {
      assertEq(_tally.yes, 0);
      assertEq(_tally.no, 0);
      assertEq(_tally.abstain, 1);
    }
    if (_votingMode == 1 && _voteOption == uint256(IDAOSpace.VoteOption.No)) {
      assertEq(uint256(_parameters.votingMode), uint256(IDAOSpace.VotingMode.Slow));
    }
  }

  function test_Write_WhenTheFormer_fromSpaceIdVoteEqualsYes(
    bytes32 _subject,
    uint256 _votingMode
  ) external whenCalledBySpaceRegistry when_actionEqualsPROPOSAL_VOTED when_voteParamsAreValid {
    _votingMode = bound(_votingMode, 0, 1);

    // proposal set up
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      _proposalVersion,
      _initialEditorASpaceId,
      vm.getBlockTimestamp(),
      vm.getBlockTimestamp() + _votingSettings.duration,
      vm.getBlockTimestamp() + _votingSettings.duration + _votingSettings.executionGracePeriod,
      IDAOSpace.VotingMode(_votingMode),
      1,
      1,
      1,
      1,
      new IDAOSpace.Action[](0)
    );
    // set inital vote to yes and tally
    daoSpaceProxy.workaround_setFormerVote(_proposalId, _initialEditorASpaceId, IDAOSpace.VoteOption.Yes);
    (,,, IDAOSpace.Tally memory _tally,) = daoSpaceProxy.getLatestProposalInformation(_proposalId);
    assertEq(_tally.yes, 1);

    // vote no
    bytes memory _voteProposalData = _createVoteForProposal(IDAOSpace.VoteOption.No);
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, _voteProposalData);

    // it decreases the proposal yes vote tally by one
    (,,, _tally,) = daoSpaceProxy.getLatestProposalInformation(_proposalId);
    assertEq(_tally.yes, 0);
  }

  function test_Write_WhenTheFormer_fromSpaceIdVoteEqualsNo(
    bytes32 _subject,
    uint256 _votingMode
  ) external whenCalledBySpaceRegistry when_actionEqualsPROPOSAL_VOTED when_voteParamsAreValid {
    _votingMode = bound(_votingMode, 0, 1);

    // proposal set up
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      _proposalVersion,
      _initialEditorASpaceId,
      vm.getBlockTimestamp(),
      vm.getBlockTimestamp() + _votingSettings.duration,
      vm.getBlockTimestamp() + _votingSettings.duration + _votingSettings.executionGracePeriod,
      IDAOSpace.VotingMode(_votingMode),
      1,
      1,
      1,
      1,
      new IDAOSpace.Action[](0)
    );
    // set inital vote to no and tally
    daoSpaceProxy.workaround_setFormerVote(_proposalId, _initialEditorASpaceId, IDAOSpace.VoteOption.No);
    (,,, IDAOSpace.Tally memory _tally,) = daoSpaceProxy.getLatestProposalInformation(_proposalId);
    assertEq(_tally.no, 1);

    // vote yes
    bytes memory _voteProposalData = _createVoteForProposal(IDAOSpace.VoteOption.Yes);
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, _voteProposalData);

    // it decreases the proposal no vote tally by one
    (,,, _tally,) = daoSpaceProxy.getLatestProposalInformation(_proposalId);
    assertEq(_tally.no, 0);
  }

  function test_Write_WhenTheFormer_fromSpaceIdVoteEqualsAbstain(
    bytes32 _subject,
    uint256 _votingMode
  ) external whenCalledBySpaceRegistry when_actionEqualsPROPOSAL_VOTED when_voteParamsAreValid {
    _votingMode = bound(_votingMode, 0, 1);

    // proposal set up
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      _proposalVersion,
      _initialEditorASpaceId,
      vm.getBlockTimestamp(),
      vm.getBlockTimestamp() + _votingSettings.duration,
      vm.getBlockTimestamp() + _votingSettings.duration + _votingSettings.executionGracePeriod,
      IDAOSpace.VotingMode(_votingMode),
      1,
      1,
      1,
      1,
      new IDAOSpace.Action[](0)
    );
    // set inital vote to abstain and tally
    daoSpaceProxy.workaround_setFormerVote(_proposalId, _initialEditorASpaceId, IDAOSpace.VoteOption.Abstain);
    (,,, IDAOSpace.Tally memory _tally,) = daoSpaceProxy.getLatestProposalInformation(_proposalId);
    assertEq(_tally.abstain, 1);

    // vote yes
    bytes memory _voteProposalData = _createVoteForProposal(IDAOSpace.VoteOption.Yes);
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, _voteProposalData);

    // it decreases the proposal abstain vote tally by one
    (,,, _tally,) = daoSpaceProxy.getLatestProposalInformation(_proposalId);
    assertEq(_tally.abstain, 0);
  }

  modifier whenTheCurrent_fromSpaceIdVoteEqualsYes() {
    _;
  }

  function test_Write_WhenTheCurrent_fromSpaceIdVoteEqualsYes(
    bytes32 _subject,
    uint256 _votingMode
  )
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_VOTED
    when_voteParamsAreValid
    whenTheCurrent_fromSpaceIdVoteEqualsYes
  {
    _votingMode = bound(_votingMode, 0, 1);

    // proposal set up
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      _proposalVersion,
      _initialEditorASpaceId,
      vm.getBlockTimestamp(),
      vm.getBlockTimestamp() + _votingSettings.duration,
      vm.getBlockTimestamp() + _votingSettings.duration + _votingSettings.executionGracePeriod,
      IDAOSpace.VotingMode(_votingMode),
      2,
      1,
      1,
      2,
      new IDAOSpace.Action[](0)
    );

    // vote yes
    bytes memory _voteProposalData = _createVoteForProposal(IDAOSpace.VoteOption.Yes);
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, _voteProposalData);

    // it increases the proposal yes vote tally by one
    (bool _executed,,, IDAOSpace.Tally memory _tally,) = daoSpaceProxy.getLatestProposalInformation(_proposalId);
    assertEq(_tally.yes, 1);
    assertEq(_tally.no, 0);
    assertEq(_tally.abstain, 0);

    // it does not execute the proposal
    assertFalse(_executed);
  }

  function test_Write_WhenTheProposalCanBeExecuted(
    bytes32 _subject,
    uint256 _votingMode
  )
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_VOTED
    when_voteParamsAreValid
    whenTheCurrent_fromSpaceIdVoteEqualsYes
  {
    _votingMode = bound(_votingMode, 0, 1);

    // proposal set up to add randomCaller as a member
    IDAOSpace.Action[] memory _actions = new IDAOSpace.Action[](1);
    _actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addMember, (_randomCallerSpaceId))
    });
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      _proposalVersion,
      _initialEditorASpaceId,
      vm.getBlockTimestamp(),
      vm.getBlockTimestamp() + _votingSettings.duration,
      vm.getBlockTimestamp() + _votingSettings.duration + _votingSettings.executionGracePeriod,
      IDAOSpace.VotingMode(_votingMode),
      1,
      1,
      1,
      1,
      _actions
    );

    assertFalse(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _randomCallerSpaceId));

    // it calls enter on the spaceRegistry with the PROPOSAL_EXECUTED action (immediate execution ping)
    _mockEnter(
      _spaceRegistry,
      _daoSpaceProxySpaceId,
      _daoSpaceProxySpaceId,
      ActionsConstants.PROPOSAL_EXECUTED,
      bytes32(_proposalId),
      abi.encode(_proposalId)
    );

    // it calls enter on the spaceRegistry with the SPACE_FAST_PATH_RESTRICTED action (new member policy)
    _mockEnter(
      _spaceRegistry,
      _daoSpaceProxySpaceId,
      _daoSpaceProxySpaceId,
      ActionsConstants.SPACE_FAST_PATH_RESTRICTED,
      bytes32(_randomCallerSpaceId),
      abi.encode(_randomCallerSpaceId)
    );

    // it calls enter on the spaceRegistry with the MEMBER_ADDED action
    _mockEnter(
      _spaceRegistry,
      _daoSpaceProxySpaceId,
      _daoSpaceProxySpaceId,
      ActionsConstants.MEMBER_ADDED,
      bytes32(_randomCallerSpaceId),
      ''
    );

    // vote yes
    bytes memory _voteProposalData = _createVoteForProposal(IDAOSpace.VoteOption.Yes);
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, _voteProposalData);

    // it increases the proposal yes vote tally by one
    (bool _executed,,, IDAOSpace.Tally memory _tally,) = daoSpaceProxy.getLatestProposalInformation(_proposalId);
    assertEq(_tally.yes, 1);
    assertEq(_tally.no, 0);
    assertEq(_tally.abstain, 0);

    // it sets the proposal executed to true
    assertTrue(_executed);
    assertFalse(daoSpaceProxy.canExecuteProposal(_proposalId));

    // it loops over the stored proposal actions and performs the external calls
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _randomCallerSpaceId));
  }

  modifier whenTheCurrent_fromSpaceIdVoteEqualsNo() {
    _;
  }

  function test_Write_WhenTheCurrent_fromSpaceIdVoteEqualsNo(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_VOTED
    when_voteParamsAreValid
    whenTheCurrent_fromSpaceIdVoteEqualsNo
  {
    // proposal set up
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      _proposalVersion,
      _initialEditorASpaceId,
      vm.getBlockTimestamp(),
      vm.getBlockTimestamp() + _votingSettings.duration,
      vm.getBlockTimestamp() + _votingSettings.duration + _votingSettings.executionGracePeriod,
      IDAOSpace.VotingMode.Slow,
      1,
      1,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    // vote no
    bytes memory _voteProposalData = _createVoteForProposal(IDAOSpace.VoteOption.No);
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, _voteProposalData);

    // it increases the proposal no vote tally by one
    (bool _executed,,, IDAOSpace.Tally memory _tally,) = daoSpaceProxy.getLatestProposalInformation(_proposalId);
    assertEq(_tally.yes, 0);
    assertEq(_tally.no, 1);
    assertEq(_tally.abstain, 0);

    // it does not execute the proposal
    assertFalse(_executed);
  }

  function test_Write_WhenTheProposalVotingModeIsFast(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_VOTED
    when_voteParamsAreValid
    whenTheCurrent_fromSpaceIdVoteEqualsNo
  {
    // proposal set up
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      _proposalVersion,
      _initialEditorASpaceId,
      0,
      0,
      0,
      IDAOSpace.VotingMode.Fast,
      _votingSettings.quorum,
      _votingSettings.partialPercentageSupportThreshold,
      _votingSettings.universalPercentageSupportThreshold,
      _votingSettings.flatSupportThreshold,
      new IDAOSpace.Action[](0)
    );

    uint256 _voteAt = vm.getBlockTimestamp() + 5 days;
    vm.warp(_voteAt);

    // it calls enter on the spaceRegistry with the PROPOSAL_SETTINGS_SELECTED action
    _mockEnter(
      _spaceRegistry,
      _daoSpaceProxySpaceId,
      _daoSpaceProxySpaceId,
      ActionsConstants.PROPOSAL_SETTINGS_SELECTED,
      bytes32(_proposalId),
      abi.encode(_activeProposalParameters(IDAOSpace.VotingMode.Slow, _voteAt))
    );

    bytes memory _voteProposalData = _createVoteForProposal(IDAOSpace.VoteOption.No);
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, _voteProposalData);

    (, bytes16 _creator, IDAOSpace.ProposalParameters memory _parametersAfterVote, IDAOSpace.Tally memory _tally,) =
      daoSpaceProxy.getLatestProposalInformation(_proposalId);
    assertEq(_creator, _initialEditorASpaceId);
    assertEq(_tally.no, 1);

    // it updates the proposal voting mode to the slow path
    assertEq(uint256(_parametersAfterVote.votingMode), uint256(IDAOSpace.VotingMode.Slow));

    // it updates the proposal quorum to votingSettings.quorum
    assertEq(_parametersAfterVote.quorum, _votingSettings.quorum);

    // it updates the proposal partial percentage support threshold to votingSettings.partialPercentageSupportThreshold
    assertEq(
      _parametersAfterVote.partialPercentageSupportThreshold,
      daoSpaceProxy.votingSettings().partialPercentageSupportThreshold
    );

    // it updates the proposal universal percentage support threshold to votingSettings.universalPercentageSupportThreshold
    assertEq(
      _parametersAfterVote.universalPercentageSupportThreshold,
      daoSpaceProxy.votingSettings().universalPercentageSupportThreshold
    );

    // it updates the proposal flat support threshold to votingSettings.flatSupportThreshold
    assertEq(_parametersAfterVote.flatSupportThreshold, daoSpaceProxy.votingSettings().flatSupportThreshold);

    // it updates the proposal start date to block.timestamp
    assertEq(_parametersAfterVote.startDate, _voteAt);

    // it updates the proposal last date to block.timestamp plus votingSettings.duration
    assertEq(_parametersAfterVote.lastDate, _voteAt + _votingSettings.duration);

    // it updates executeBy to lastDate plus votingSettings.executionGracePeriod
    assertEq(_parametersAfterVote.executeBy, _parametersAfterVote.lastDate + _votingSettings.executionGracePeriod);
  }

  modifier whenTheCurrent_fromSpaceIdVoteEqualsAbstain() {
    _;
  }

  function test_Write_WhenTheCurrent_fromSpaceIdVoteEqualsAbstain(
    bytes32 _subject,
    uint256 _votingMode
  )
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_VOTED
    when_voteParamsAreValid
    whenTheCurrent_fromSpaceIdVoteEqualsAbstain
  {
    _votingMode = bound(_votingMode, 0, 1);

    // proposal set up
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      _proposalVersion,
      _initialEditorASpaceId,
      vm.getBlockTimestamp(),
      vm.getBlockTimestamp() + _votingSettings.duration,
      vm.getBlockTimestamp() + _votingSettings.duration + _votingSettings.executionGracePeriod,
      IDAOSpace.VotingMode(_votingMode),
      1,
      1,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    // vote abstain
    bytes memory _voteProposalData = _createVoteForProposal(IDAOSpace.VoteOption.Abstain);
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, _voteProposalData);

    // it increases the proposal abstain vote tally by one
    (bool _executed,,, IDAOSpace.Tally memory _tally,) = daoSpaceProxy.getLatestProposalInformation(_proposalId);
    assertEq(_tally.yes, 0);
    assertEq(_tally.no, 0);
    assertEq(_tally.abstain, 1);

    // it does not execute the proposal
    assertFalse(_executed);
  }

  /// WRITE - UPDATE PROPOSAL ///

  modifier when_actionEqualsPROPOSAL_UPDATED() {
    _;
  }

  function test_Write_WhenTheProposalCreatorIsNotThe_fromSpaceId(
    bytes32 _subject,
    uint256 _votingMode
  ) external whenCalledBySpaceRegistry when_actionEqualsPROPOSAL_UPDATED {
    _votingMode = bound(_votingMode, 0, 1);

    // Set up former proposal
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      _proposalVersion,
      _initialEditorASpaceId,
      vm.getBlockTimestamp(),
      vm.getBlockTimestamp() + _votingSettings.duration,
      vm.getBlockTimestamp() + _votingSettings.duration + _votingSettings.executionGracePeriod,
      IDAOSpace.VotingMode(_votingMode),
      1,
      1,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    // it reverts with InvalidCaller
    vm.expectRevert(IDAOSpace.InvalidCaller.selector);

    bytes memory _createProposalData = _createFastPathProposalToAddMember();
    daoSpaceProxy.write(_randomCallerSpaceId, ActionsConstants.PROPOSAL_UPDATED, _subject, _createProposalData);
  }

  function test_Write_WhenTheProposalHasAlreadyBeenExecuted(
    bytes32 _subject,
    uint256 _votingMode
  ) external whenCalledBySpaceRegistry when_actionEqualsPROPOSAL_UPDATED {
    _votingMode = bound(_votingMode, 0, 1);

    // Set up former proposal
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      true,
      _proposalVersion,
      _initialEditorASpaceId,
      vm.getBlockTimestamp(),
      vm.getBlockTimestamp() + _votingSettings.duration,
      vm.getBlockTimestamp() + _votingSettings.duration + _votingSettings.executionGracePeriod,
      IDAOSpace.VotingMode(_votingMode),
      1,
      1,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    // it reverts with InvalidProposalId
    vm.expectRevert(IDAOSpace.InvalidProposalId.selector);

    bytes memory _createProposalData = _createFastPathProposalToAddMember();
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_UPDATED, _subject, _createProposalData);
  }

  function test_Write_WhenTheProposalCanBeUpdated(
    bytes32 _subject,
    uint256 _voteOption
  ) external whenCalledBySpaceRegistry when_actionEqualsPROPOSAL_UPDATED {
    _voteOption = bound(_voteOption, 1, 3);

    // Set up former proposal
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      _proposalVersion,
      _initialEditorASpaceId,
      vm.getBlockTimestamp(),
      vm.getBlockTimestamp() + _votingSettings.duration,
      vm.getBlockTimestamp() + _votingSettings.duration + _votingSettings.executionGracePeriod,
      IDAOSpace.VotingMode.Slow,
      1,
      1,
      1,
      1,
      new IDAOSpace.Action[](0)
    );
    daoSpaceProxy.workaround_setFormerVote(_proposalId, _initialEditorASpaceId, IDAOSpace.VoteOption(_voteOption));
    daoSpaceProxy.workaround_setTally(_proposalId, 1, 1, 1);

    // it calls enter on the spaceRegistry with the PROPOSAL_SETTINGS_SELECTED action
    _mockEnter(
      _spaceRegistry,
      _daoSpaceProxySpaceId,
      _daoSpaceProxySpaceId,
      ActionsConstants.PROPOSAL_SETTINGS_SELECTED,
      bytes32(_proposalId),
      abi.encode(
        IDAOSpace.ProposalParameters({
          votingMode: IDAOSpace.VotingMode.Fast,
          partialPercentageSupportThreshold: _votingSettings.partialPercentageSupportThreshold,
          universalPercentageSupportThreshold: _votingSettings.universalPercentageSupportThreshold,
          flatSupportThreshold: _votingSettings.flatSupportThreshold,
          quorum: _votingSettings.quorum,
          startDate: 0,
          lastDate: 0,
          executeBy: 0
        })
      )
    );

    bytes memory _createProposalData = _createFastPathProposalToAddMember();
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_UPDATED, _subject, _createProposalData);

    (,,, IDAOSpace.Tally memory _tally, IDAOSpace.Action[] memory _actions) =
      daoSpaceProxy.getLatestProposalInformation(_proposalId);
    IDAOSpace.VoteOption _vote = daoSpaceProxy.getLatestProposalVote(_proposalId, _initialEditorASpaceId);

    // it resets the voting state
    assertEq(_tally.abstain, 0);
    assertEq(_tally.yes, 0);
    assertEq(_tally.no, 0);
    assertEq(uint256(_vote), 0);

    // it updates the proposal with a new version
    assertEq(daoSpaceProxy.latestProposalVersion(_proposalId), _proposalVersion + 1);
    assertEq(_actions.length, 1);

    (,,, _tally, _actions) = daoSpaceProxy.getProposalInformation(_proposalId, _proposalVersion);
    _vote = daoSpaceProxy.getProposalVote(_proposalId, _proposalVersion, _initialEditorASpaceId);

    // it also retains the previous version data
    assertEq(_tally.abstain, 1);
    assertEq(_tally.yes, 1);
    assertEq(_tally.no, 1);
    assertEq(uint256(_vote), _voteOption);
    assertEq(_actions.length, 0);
  }

  /// WRITE - EXECUTE PROPOSAL ///

  modifier when_actionEqualsPROPOSAL_EXECUTED() {
    _;
  }

  function test_Write_WhenTheProposalDoesNotExist_When_actionEqualsPROPOSAL_EXECUTED(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_EXECUTED
  {
    assertFalse(daoSpaceProxy.canExecuteProposal(_proposalId));

    // it reverts with CanNotExecute
    vm.expectRevert(IDAOSpace.CanNotExecute.selector);

    bytes memory _executeProposalData = abi.encode(_proposalId);
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_EXECUTED, _subject, _executeProposalData);
  }

  function test_Write_WhenTheProposalHasAlreadyBeenExecuted_When_actionEqualsPROPOSAL_EXECUTED(
    bytes32 _subject,
    uint256 _votingMode
  ) external whenCalledBySpaceRegistry when_actionEqualsPROPOSAL_EXECUTED {
    _votingMode = bound(_votingMode, 0, 1);

    // set up proposal
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      true,
      _proposalVersion,
      _initialEditorASpaceId,
      vm.getBlockTimestamp(),
      vm.getBlockTimestamp() + _votingSettings.duration,
      vm.getBlockTimestamp() + _votingSettings.duration + _votingSettings.executionGracePeriod,
      IDAOSpace.VotingMode(_votingMode),
      1,
      1,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    assertFalse(daoSpaceProxy.canExecuteProposal(_proposalId));

    // it reverts with CanNotExecute
    vm.expectRevert(IDAOSpace.CanNotExecute.selector);

    bytes memory _executeProposalData = abi.encode(_proposalId);
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_EXECUTED, _subject, _executeProposalData);
  }

  function test_Write_WhenTheSupportThresholdHasNotBeenReached(
    bytes32 _subject,
    uint256 _votingMode
  ) external whenCalledBySpaceRegistry when_actionEqualsPROPOSAL_EXECUTED {
    _votingMode = bound(_votingMode, 0, 1);

    // set up proposal
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      _proposalVersion,
      _initialEditorASpaceId,
      vm.getBlockTimestamp(),
      vm.getBlockTimestamp() + _votingSettings.duration,
      vm.getBlockTimestamp() + _votingSettings.duration + _votingSettings.executionGracePeriod,
      IDAOSpace.VotingMode(_votingMode),
      1,
      1,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    // warp past lastDate (snapshotted as now + voting duration) while still before executeBy
    vm.warp(vm.getBlockTimestamp() + _votingSettings.duration + 1);

    assertFalse(daoSpaceProxy.canExecuteProposal(_proposalId));

    // it reverts with CanNotExecute
    vm.expectRevert(IDAOSpace.CanNotExecute.selector);

    bytes memory _executeProposalData = abi.encode(_proposalId);
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_EXECUTED, _subject, _executeProposalData);
  }

  modifier whenTheProposalCanBeExecuted() {
    _;
  }

  modifier whenTheTargetAddressHasContractCode() {
    _;
  }

  function test_Write_WhenTheTargetAddressHasContractCode(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_EXECUTED
    whenTheProposalCanBeExecuted
    whenTheTargetAddressHasContractCode
  {
    IDAOSpace.Action[] memory _actions = new IDAOSpace.Action[](2);
    _actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addEditor, (_randomCallerSpaceId))
    });
    _actions[1] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addMember, (_randomCallerSpaceId))
    });
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      _proposalVersion,
      _initialEditorASpaceId,
      vm.getBlockTimestamp(),
      vm.getBlockTimestamp() + _votingSettings.duration,
      vm.getBlockTimestamp() + _votingSettings.duration + _votingSettings.executionGracePeriod,
      IDAOSpace.VotingMode.Slow,
      1,
      1,
      1,
      1,
      _actions
    );

    // set vote to yes
    daoSpaceProxy.workaround_setFormerVote(_proposalId, _initialEditorASpaceId, IDAOSpace.VoteOption.Yes);

    // warp past lastDate (snapshotted as now + voting duration) while still before executeBy
    vm.warp(vm.getBlockTimestamp() + _votingSettings.duration + 1);

    assertFalse(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _randomCallerSpaceId));
    assertFalse(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _randomCallerSpaceId));

    // it calls enter on the spaceRegistry with the EDITOR_ADDED action
    _mockEnter(
      _spaceRegistry,
      _daoSpaceProxySpaceId,
      _daoSpaceProxySpaceId,
      ActionsConstants.EDITOR_ADDED,
      bytes32(_randomCallerSpaceId),
      ''
    );

    // it calls enter on the spaceRegistry with the MEMBER_ADDED action
    _mockEnter(
      _spaceRegistry,
      _daoSpaceProxySpaceId,
      _daoSpaceProxySpaceId,
      ActionsConstants.MEMBER_ADDED,
      bytes32(_randomCallerSpaceId),
      ''
    );

    assertTrue(daoSpaceProxy.canExecuteProposal(_proposalId));

    bytes memory _executeProposalData = abi.encode(_proposalId);
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_EXECUTED, _subject, _executeProposalData);

    (bool _executed,,,,) = daoSpaceProxy.getLatestProposalInformation(_proposalId);

    // it sets the proposal executed to true
    assertTrue(_executed);
    assertFalse(daoSpaceProxy.canExecuteProposal(_proposalId));

    // it loops over the stored proposal actions and performs the external calls
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _randomCallerSpaceId));
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _randomCallerSpaceId));
  }

  function test_Write_WhenAnExternalCallFails(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_EXECUTED
    whenTheProposalCanBeExecuted
    whenTheTargetAddressHasContractCode
  {
    IDAOSpace.Action[] memory _actions = new IDAOSpace.Action[](1);
    _actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(ISpaceRegistry.registerSpaceId, (bytes32(0), ''))
    });
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      _proposalVersion,
      _initialEditorASpaceId,
      vm.getBlockTimestamp(),
      vm.getBlockTimestamp() + _votingSettings.duration,
      vm.getBlockTimestamp() + _votingSettings.duration + _votingSettings.executionGracePeriod,
      IDAOSpace.VotingMode.Slow,
      0,
      1,
      1,
      1,
      _actions
    );

    // set vote to yes
    daoSpaceProxy.workaround_setFormerVote(_proposalId, _initialEditorASpaceId, IDAOSpace.VoteOption.Yes);
    vm.warp(vm.getBlockTimestamp() + _votingSettings.duration + 1);

    // it reverts with an appropriate error
    vm.expectRevert(Errors.FailedCall.selector);

    bytes memory _executeProposalData = abi.encode(_proposalId);
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_EXECUTED, _subject, _executeProposalData);
  }

  modifier whenTheTargetAddressHasNoContractCode() {
    _;
  }

  function test_Write_WhenTheTargetAddressHasNoContractCode(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_EXECUTED
    whenTheProposalCanBeExecuted
    whenTheTargetAddressHasNoContractCode
  {
    address _eoaRecipient = makeAddr('eoaNoCodeRecipient');
    assertEq(_eoaRecipient.code.length, 0);

    uint256 _sendAmount = 1 ether;
    IDAOSpace.Action[] memory _actions = new IDAOSpace.Action[](1);
    _actions[0] = IDAOSpace.Action({
      to: _eoaRecipient, value: _sendAmount, data: abi.encodeCall(IDAOSpace.addEditor, (_randomCallerSpaceId))
    });

    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      _proposalVersion,
      _initialEditorASpaceId,
      vm.getBlockTimestamp(),
      vm.getBlockTimestamp() + _votingSettings.duration,
      vm.getBlockTimestamp() + _votingSettings.duration + _votingSettings.executionGracePeriod,
      IDAOSpace.VotingMode.Slow,
      1,
      1,
      1,
      1,
      _actions
    );

    daoSpaceProxy.workaround_setFormerVote(_proposalId, _initialEditorASpaceId, IDAOSpace.VoteOption.Yes);
    vm.warp(vm.getBlockTimestamp() + _votingSettings.duration + 1);

    vm.deal(address(daoSpaceProxy), _sendAmount);
    uint256 _recipientBalanceBefore = _eoaRecipient.balance;

    bytes memory _executeProposalData = abi.encode(_proposalId);
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_EXECUTED, _subject, _executeProposalData);

    (bool _executed,,,,) = daoSpaceProxy.getLatestProposalInformation(_proposalId);

    // it sets the proposal executed to true
    assertTrue(_executed);
    assertFalse(daoSpaceProxy.canExecuteProposal(_proposalId));

    // it sends native value and ignores data
    assertEq(_eoaRecipient.balance - _recipientBalanceBefore, _sendAmount);
    assertFalse(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _randomCallerSpaceId));
  }

  function test_Write_WhenAnExternalCallFails_WhenTheTargetAddressHasNoContractCode(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_EXECUTED
    whenTheProposalCanBeExecuted
    whenTheTargetAddressHasNoContractCode
  {
    address _eoaRecipient = makeAddr('eoaNoCodeRecipientB');
    assertEq(_eoaRecipient.code.length, 0);

    uint256 _sendAmount = 1 ether;
    IDAOSpace.Action[] memory _actions = new IDAOSpace.Action[](1);
    _actions[0] = IDAOSpace.Action({
      to: _eoaRecipient, value: _sendAmount, data: abi.encodeCall(IDAOSpace.addEditor, (_randomCallerSpaceId))
    });

    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      _proposalVersion,
      _initialEditorASpaceId,
      vm.getBlockTimestamp(),
      vm.getBlockTimestamp() + _votingSettings.duration,
      vm.getBlockTimestamp() + _votingSettings.duration + _votingSettings.executionGracePeriod,
      IDAOSpace.VotingMode.Slow,
      1,
      1,
      1,
      1,
      _actions
    );

    daoSpaceProxy.workaround_setFormerVote(_proposalId, _initialEditorASpaceId, IDAOSpace.VoteOption.Yes);
    vm.warp(vm.getBlockTimestamp() + _votingSettings.duration + 1);

    vm.deal(address(daoSpaceProxy), 0);

    // it reverts with an appropriate error
    vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientBalance.selector, uint256(0), uint256(_sendAmount)));

    bytes memory _executeProposalData = abi.encode(_proposalId);
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_EXECUTED, _subject, _executeProposalData);
  }

  /// WRITE - SPACE_LEFT ///

  modifier when_actionEqualsSPACE_LEFT() {
    _;
  }

  function test_Write_WhenTheRoleSpecifiedIsMEMBERAndThe_fromSpaceIdIsAMember(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsSPACE_LEFT
  {
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _initialMemberASpaceId));

    // it calls enter on the spaceRegistry with the MEMBER_REMOVED action
    _mockEnter(
      _spaceRegistry,
      _daoSpaceProxySpaceId,
      _daoSpaceProxySpaceId,
      ActionsConstants.MEMBER_REMOVED,
      bytes32(_initialMemberASpaceId),
      ''
    );

    bytes memory _leaveSpaceData = abi.encode(daoSpaceProxy.MEMBER());
    daoSpaceProxy.write(_initialMemberASpaceId, ActionsConstants.SPACE_LEFT, _subject, _leaveSpaceData);

    // it revokes the role of MEMBER from the _fromSpaceId
    assertFalse(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _initialMemberASpaceId));
  }

  function test_Write_WhenTheRoleSpecifiedIsEDITORAndThe_fromSpaceIdIsAnEditor(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsSPACE_LEFT
  {
    // Set quorum and flat support threshold to 0 so that an editor can be removed
    daoSpaceProxy.workaround_setVotingSettings(
      IDAOSpace.VotingSettings({
        partialPercentageSupportThreshold: _votingSettings.partialPercentageSupportThreshold,
        universalPercentageSupportThreshold: _votingSettings.universalPercentageSupportThreshold,
        flatSupportThreshold: 0,
        quorum: 0,
        duration: _votingSettings.duration,
        disableFastPathAccessForNewMembers: _votingSettings.disableFastPathAccessForNewMembers,
        executionGracePeriod: _votingSettings.executionGracePeriod
      })
    );

    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _initialEditorASpaceId));

    // it calls enter on the spaceRegistry with the EDITOR_REMOVED action
    _mockEnter(
      _spaceRegistry,
      _daoSpaceProxySpaceId,
      _daoSpaceProxySpaceId,
      ActionsConstants.EDITOR_REMOVED,
      bytes32(_initialEditorASpaceId),
      ''
    );

    bytes memory _leaveSpaceData = abi.encode(daoSpaceProxy.EDITOR());
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.SPACE_LEFT, _subject, _leaveSpaceData);

    // it revokes the role of EDITOR from the _fromSpaceId
    assertFalse(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _initialEditorASpaceId));
  }

  function test_Write_WhenTheRoleIsNotHeldByThe_fromSpaceIdOrTheRoleIsNeitherMEMBERNorEDITOR(
    bytes32 _subject,
    bytes16 _callerSpaceId
  ) external whenCalledBySpaceRegistry when_actionEqualsSPACE_LEFT {
    vm.assume(_callerSpaceId != _initialEditorASpaceId);
    vm.assume(_callerSpaceId != _initialMemberASpaceId);

    // it reverts with InvalidFromSpace
    // role is neither MEMBER or EDITOR
    bytes memory _leaveSpaceData = abi.encode(daoSpaceProxy.DAO());
    vm.expectRevert(IDAOSpace.InvalidFromSpace.selector);
    daoSpaceProxy.write(_callerSpaceId, ActionsConstants.SPACE_LEFT, _subject, _leaveSpaceData);

    // _fromSpaceId doesn't have role
    _leaveSpaceData = abi.encode(daoSpaceProxy.MEMBER());
    vm.expectRevert(IDAOSpace.InvalidFromSpace.selector);
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.SPACE_LEFT, _subject, _leaveSpaceData);

    // _fromSpaceId doesn't have role
    _leaveSpaceData = abi.encode(daoSpaceProxy.EDITOR());
    vm.expectRevert(IDAOSpace.InvalidFromSpace.selector);
    daoSpaceProxy.write(_initialMemberASpaceId, ActionsConstants.SPACE_LEFT, _subject, _leaveSpaceData);
  }

  /// WRITE - REQUEST MEMBERSHIP ///

  modifier when_actionEqualsMEMBERSHIP_REQUESTED() {
    _;
  }

  function test_Write_When_proposalIdHasAlreadyBeenUsed_When_actionEqualsMEMBERSHIP_REQUESTED()
    external
    whenCalledBySpaceRegistry
    when_actionEqualsMEMBERSHIP_REQUESTED
  {
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      _proposalVersion,
      _randomCallerSpaceId,
      1,
      1,
      1,
      IDAOSpace.VotingMode.Fast,
      1,
      1,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    // it reverts with InvalidProposalId
    vm.expectRevert(IDAOSpace.InvalidProposalId.selector);

    bytes memory _requestMembershipData = abi.encode(_proposalId, _randomCallerSpaceId);
    daoSpaceProxy.write(_randomCallerSpaceId, ActionsConstants.MEMBERSHIP_REQUESTED, bytes32(0), _requestMembershipData);
  }

  function test_Write_When_fromSpaceIdIsRestricted_When_actionEqualsMEMBERSHIP_REQUESTED()
    external
    whenCalledBySpaceRegistry
    when_actionEqualsMEMBERSHIP_REQUESTED
  {
    daoSpaceProxy.workaround_grantRole(daoSpaceProxy.FAST_PATH_RESTRICTED(), _randomCallerSpaceId);

    // it reverts with FastPathRestricted
    vm.expectRevert(IDAOSpace.FastPathRestricted.selector);

    bytes memory _requestMembershipData = abi.encode(_proposalId, _randomCallerSpaceId);
    daoSpaceProxy.write(_randomCallerSpaceId, ActionsConstants.MEMBERSHIP_REQUESTED, bytes32(0), _requestMembershipData);
  }

  function test_Write_When_newMemberSpaceIdIsAMember()
    external
    whenCalledBySpaceRegistry
    when_actionEqualsMEMBERSHIP_REQUESTED
  {
    daoSpaceProxy.workaround_grantRole(daoSpaceProxy.MEMBER(), _randomCallerSpaceId);

    // it reverts with InvalidSpaceIdForRole
    vm.expectRevert(IDAOSpace.InvalidSpaceIdForRole.selector);

    bytes memory _requestMembershipData = abi.encode(_proposalId, _randomCallerSpaceId);
    daoSpaceProxy.write(_randomCallerSpaceId, ActionsConstants.MEMBERSHIP_REQUESTED, bytes32(0), _requestMembershipData);
  }

  function test_Write_WhenTheRequestCanBeMade()
    external
    whenCalledBySpaceRegistry
    when_actionEqualsMEMBERSHIP_REQUESTED
  {
    // it calls enter on the spaceRegistry with the PROPOSAL_CREATED action
    IDAOSpace.Action[] memory _actions = new IDAOSpace.Action[](1);
    _actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addMember, (_randomCallerSpaceId))
    });

    // Mock addressToSpaceId for _ping calls (called twice: once for PROPOSAL_CREATED, once for PROPOSAL_SETTINGS_SELECTED)
    _mockAddressToSpaceId(_spaceRegistry, address(daoSpaceProxy), _daoSpaceProxySpaceId);
    _mockAddressToSpaceId(_spaceRegistry, address(daoSpaceProxy), _daoSpaceProxySpaceId);

    // it calls enter on the spaceRegistry with the PROPOSAL_CREATED action
    _mockEnter(
      _spaceRegistry,
      _daoSpaceProxySpaceId,
      _daoSpaceProxySpaceId,
      ActionsConstants.PROPOSAL_CREATED,
      bytes32(_proposalId),
      abi.encode(_proposalId, IDAOSpace.VotingMode.Fast, _actions)
    );

    // it calls enter on the spaceRegistry with the PROPOSAL_SETTINGS_SELECTED action
    _mockEnter(
      _spaceRegistry,
      _daoSpaceProxySpaceId,
      _daoSpaceProxySpaceId,
      ActionsConstants.PROPOSAL_SETTINGS_SELECTED,
      bytes32(_proposalId),
      abi.encode(
        IDAOSpace.ProposalParameters({
          votingMode: IDAOSpace.VotingMode.Fast,
          partialPercentageSupportThreshold: _votingSettings.partialPercentageSupportThreshold,
          universalPercentageSupportThreshold: _votingSettings.universalPercentageSupportThreshold,
          flatSupportThreshold: _votingSettings.flatSupportThreshold,
          quorum: _votingSettings.quorum,
          startDate: 0,
          lastDate: 0,
          executeBy: 0
        })
      )
    );

    bytes memory _requestMembershipData = abi.encode(_proposalId, _randomCallerSpaceId);
    daoSpaceProxy.write(_randomCallerSpaceId, ActionsConstants.MEMBERSHIP_REQUESTED, bytes32(0), _requestMembershipData);

    (, bytes16 _creator, IDAOSpace.ProposalParameters memory _parameters,, IDAOSpace.Action[] memory _actionsA) =
      daoSpaceProxy.getLatestProposalInformation(_proposalId);

    // it increments the proposal version
    assertEq(daoSpaceProxy.latestProposalVersion(_proposalId), 1);

    // it sets the proposal creator to _fromSpaceId
    assertEq(_creator, _randomCallerSpaceId);

    // it sets the proposal voting mode to the fast path
    assertEq(uint256(_parameters.votingMode), uint256(IDAOSpace.VotingMode.Fast));

    // it sets the proposal quorum to votingSettings.quorum
    assertEq(_parameters.quorum, _votingSettings.quorum);

    // it sets the proposal partial percentage support threshold to votingSettings.partialPercentageSupportThreshold
    assertEq(_parameters.partialPercentageSupportThreshold, _votingSettings.partialPercentageSupportThreshold);

    // it sets the proposal universal percentage support threshold to votingSettings.universalPercentageSupportThreshold
    assertEq(_parameters.universalPercentageSupportThreshold, _votingSettings.universalPercentageSupportThreshold);

    // it sets the proposal flat support threshold to votingSettings.flatSupportThreshold
    assertEq(_parameters.flatSupportThreshold, _votingSettings.flatSupportThreshold);

    // it stores the decoded proposal actions
    assertEq(_actionsA.length, 1);
    assertEq(_actionsA[0].to, address(daoSpaceProxy));
    assertEq(_actionsA[0].value, 0);
    assertEq(_actionsA[0].data, abi.encodeCall(IDAOSpace.addMember, (_randomCallerSpaceId)));
  }

  /// WRITE - SPACE FAST PATH RESTRICTED ///

  modifier when_actionEqualsSPACE_FAST_PATH_RESTRICTED() {
    _;
  }

  function test_Write_WhenThe_fromSpaceIdIsNotAnEditor_When_actionEqualsSPACE_FAST_PATH_RESTRICTED(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsSPACE_FAST_PATH_RESTRICTED
  {
    // it reverts with InvalidFromSpace
    vm.expectRevert(IDAOSpace.InvalidFromSpace.selector);

    bytes memory _restrictSpaceData = abi.encode(_randomCallerSpaceId);
    daoSpaceProxy.write(
      _initialMemberASpaceId, ActionsConstants.SPACE_FAST_PATH_RESTRICTED, _subject, _restrictSpaceData
    );
  }

  function test_Write_WhenThe_newRestrictedSpaceIdIsRestricted(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsSPACE_FAST_PATH_RESTRICTED
  {
    daoSpaceProxy.workaround_grantRole(daoSpaceProxy.FAST_PATH_RESTRICTED(), _randomCallerSpaceId);

    // it reverts with InvalidSpaceIdForRole
    vm.expectRevert(IDAOSpace.InvalidSpaceIdForRole.selector);

    bytes memory _restrictSpaceData = abi.encode(_randomCallerSpaceId);
    daoSpaceProxy.write(
      _initialEditorASpaceId, ActionsConstants.SPACE_FAST_PATH_RESTRICTED, _subject, _restrictSpaceData
    );
  }

  function test_Write_When_restrictSpaceParamsAreValid(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsSPACE_FAST_PATH_RESTRICTED
  {
    assertFalse(daoSpaceProxy.hasRole(daoSpaceProxy.FAST_PATH_RESTRICTED(), _randomCallerSpaceId));

    // initial editor flags themselves
    bytes memory _restrictSpaceData = abi.encode(_randomCallerSpaceId);
    daoSpaceProxy.write(
      _initialEditorASpaceId, ActionsConstants.SPACE_FAST_PATH_RESTRICTED, _subject, _restrictSpaceData
    );

    // it grants the FAST_PATH_RESTRICTED role to _newRestrictedSpaceId
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.FAST_PATH_RESTRICTED(), _randomCallerSpaceId));
  }

  /// WRITE - REVERT ///

  function test_Write_When_actionDoesNotEqualAnyExpectedConstant(
    bytes32 _action,
    bytes32 _subject,
    bytes memory _data
  ) external whenCalledBySpaceRegistry {
    vm.assume(_action != ActionsConstants.PROPOSAL_CREATED);
    vm.assume(_action != ActionsConstants.PROPOSAL_VOTED);
    vm.assume(_action != ActionsConstants.PROPOSAL_EXECUTED);
    vm.assume(_action != ActionsConstants.PROPOSAL_UPDATED);
    vm.assume(_action != ActionsConstants.SPACE_LEFT);
    vm.assume(_action != ActionsConstants.MEMBERSHIP_REQUESTED);
    vm.assume(_action != ActionsConstants.SPACE_FAST_PATH_RESTRICTED);

    // it reverts with InvalidAction
    vm.expectRevert(IDAOSpace.InvalidAction.selector);
    daoSpaceProxy.write(_randomCallerSpaceId, _action, _subject, _data);
  }

  function test_Write_WhenCalledByNon_spaceRegistry(
    address _caller,
    bytes32 _action,
    bytes32 _subject,
    bytes memory _data
  ) external {
    vm.assume(_caller != _spaceRegistry);

    // it reverts with InvalidCaller
    vm.expectRevert(IDAOSpace.InvalidCaller.selector);
    vm.prank(_caller);
    daoSpaceProxy.write(_randomCallerSpaceId, _action, _subject, _data);
  }

  /// VERIFY ///

  function test_Verify_WhenCalled(
    address _caller,
    address _sender,
    bytes32 _action,
    bytes32 _subject,
    bytes calldata _data,
    bytes calldata _signature
  ) external {
    vm.prank(_caller);

    // it reverts with VerifyDisabled
    vm.expectRevert(IDAOSpace.VerifyDisabled.selector);
    daoSpaceProxy.verify(_sender, _toSpaceId, _action, _subject, _data, _signature);
  }

  /// ADD EDITOR ///

  modifier whenCalledByDAO() {
    vm.startPrank(address(daoSpaceProxy));
    _;
    vm.stopPrank();
  }

  function test_AddEditor_When_newEditorIsAnEditor() external whenCalledByDAO {
    // it reverts with InvalidSpaceIdForRole
    vm.expectRevert(IDAOSpace.InvalidSpaceIdForRole.selector);
    daoSpaceProxy.addEditor(_initialEditorASpaceId);
  }

  function test_AddEditor_When_newEditorIsNotAnEditor(bytes16 _newEditorSpaceId) external whenCalledByDAO {
    vm.assume(_newEditorSpaceId != _initialEditorASpaceId);
    vm.assume(_newEditorSpaceId != _initialEditorBSpaceId);

    assertFalse(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _newEditorSpaceId));

    uint256 _totalEditorsBefore = daoSpaceProxy.totalEditors();
    assertEq(_totalEditorsBefore, 2);

    _mockAddressToSpaceId(_spaceRegistry, address(daoSpaceProxy), _daoSpaceProxySpaceId);

    // it calls enter on the spaceRegistry with the EDITOR_ADDED action
    _mockEnter(
      _spaceRegistry,
      _daoSpaceProxySpaceId,
      _daoSpaceProxySpaceId,
      ActionsConstants.EDITOR_ADDED,
      bytes32(_newEditorSpaceId),
      ''
    );
    daoSpaceProxy.addEditor(_newEditorSpaceId);

    // it increments totalEditors
    assertEq(daoSpaceProxy.totalEditors(), _totalEditorsBefore + 1);

    // it grants _newEditor the EDITOR role
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _newEditorSpaceId));
  }

  function test_AddEditor_WhenCalledByNon_DAO(address _caller, bytes16 _newEditorSpaceId) external {
    vm.assume(_caller != address(daoSpaceProxy));

    vm.prank(_caller);

    // it reverts with InvalidCaller
    vm.expectRevert(IDAOSpace.InvalidCaller.selector);
    daoSpaceProxy.addEditor(_newEditorSpaceId);
  }

  /// REMOVE EDITOR ///

  function test_RemoveEditor_When_oldEditorIsNotAnEditor(bytes16 _oldEditorSpaceId) external whenCalledByDAO {
    vm.assume(_oldEditorSpaceId != _initialEditorASpaceId);
    vm.assume(_oldEditorSpaceId != _initialEditorBSpaceId);

    _mockAddressToSpaceId(_spaceRegistry, address(daoSpaceProxy), _daoSpaceProxySpaceId);

    // it reverts with InvalidSpaceIdForRole
    vm.expectRevert(IDAOSpace.InvalidSpaceIdForRole.selector);
    daoSpaceProxy.removeEditor(_oldEditorSpaceId);
  }

  function test_RemoveEditor_WhenTheVotingSettingsQuorumEqualsTotalEditors() external whenCalledByDAO {
    daoSpaceProxy.workaround_setVotingSettings(
      IDAOSpace.VotingSettings({
        partialPercentageSupportThreshold: _votingSettings.partialPercentageSupportThreshold,
        universalPercentageSupportThreshold: _votingSettings.universalPercentageSupportThreshold,
        flatSupportThreshold: 0,
        quorum: 2,
        duration: _votingSettings.duration,
        disableFastPathAccessForNewMembers: _votingSettings.disableFastPathAccessForNewMembers,
        executionGracePeriod: _votingSettings.executionGracePeriod
      })
    );

    // it reverts with InvalidSetting
    vm.expectRevert(IDAOSpace.InvalidSetting.selector);
    daoSpaceProxy.removeEditor(_initialEditorASpaceId);
  }

  function test_RemoveEditor_WhenTheVotingSettingsFlatSupportThresholdEqualsTotalEditors() external whenCalledByDAO {
    daoSpaceProxy.workaround_setVotingSettings(
      IDAOSpace.VotingSettings({
        partialPercentageSupportThreshold: _votingSettings.partialPercentageSupportThreshold,
        universalPercentageSupportThreshold: _votingSettings.universalPercentageSupportThreshold,
        flatSupportThreshold: 2,
        quorum: 0,
        duration: _votingSettings.duration,
        disableFastPathAccessForNewMembers: _votingSettings.disableFastPathAccessForNewMembers,
        executionGracePeriod: _votingSettings.executionGracePeriod
      })
    );

    // it reverts with InvalidSetting
    vm.expectRevert(IDAOSpace.InvalidSetting.selector);
    daoSpaceProxy.removeEditor(_initialEditorASpaceId);
  }

  function test_RemoveEditor_WhenInputParamsAreValid() external whenCalledByDAO {
    // Set quorum and flat support threshold to 0 so that an editor can be removed
    daoSpaceProxy.workaround_setVotingSettings(
      IDAOSpace.VotingSettings({
        partialPercentageSupportThreshold: _votingSettings.partialPercentageSupportThreshold,
        universalPercentageSupportThreshold: _votingSettings.universalPercentageSupportThreshold,
        flatSupportThreshold: 0,
        quorum: 0,
        duration: _votingSettings.duration,
        disableFastPathAccessForNewMembers: _votingSettings.disableFastPathAccessForNewMembers,
        executionGracePeriod: _votingSettings.executionGracePeriod
      })
    );

    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _initialEditorASpaceId));

    uint256 _totalEditorsBefore = daoSpaceProxy.totalEditors();
    assertEq(_totalEditorsBefore, 2);

    // it calls enter on the spaceRegistry with the EDITOR_REMOVED action
    _mockEnter(
      _spaceRegistry,
      _daoSpaceProxySpaceId,
      _daoSpaceProxySpaceId,
      ActionsConstants.EDITOR_REMOVED,
      bytes32(_initialEditorASpaceId),
      ''
    );
    daoSpaceProxy.removeEditor(_initialEditorASpaceId);

    // it decrements totalEditors
    assertEq(daoSpaceProxy.totalEditors(), _totalEditorsBefore - 1);

    // it removes the EDITOR role from _oldEditor
    assertFalse(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _initialEditorASpaceId));
  }

  function test_RemoveEditor_WhenCalledByNon_DAO(address _caller, bytes16 _oldEditorSpaceId) external {
    vm.assume(_caller != address(daoSpaceProxy));
    vm.prank(_caller);

    // it reverts with InvalidCaller
    vm.expectRevert(IDAOSpace.InvalidCaller.selector);
    daoSpaceProxy.removeEditor(_oldEditorSpaceId);
  }

  /// ADD MEMBER ///

  function test_AddMember_When_newMemberIsAMember() external whenCalledByDAO {
    // it reverts with InvalidSpaceIdForRole
    vm.expectRevert(IDAOSpace.InvalidSpaceIdForRole.selector);
    daoSpaceProxy.addMember(_initialMemberASpaceId);
  }

  modifier when_newMemberIsNotAMember() {
    _;
  }

  function test_AddMember_When_newMemberIsNotAMember(bytes16 _newMemberSpaceId) external whenCalledByDAO {
    vm.assume(_newMemberSpaceId != _initialMemberASpaceId);
    vm.assume(_newMemberSpaceId != _initialMemberBSpaceId);

    assertFalse(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _newMemberSpaceId));

    // it calls enter on the spaceRegistry with the MEMBER_ADDED action
    _mockEnter(
      _spaceRegistry,
      _daoSpaceProxySpaceId,
      _daoSpaceProxySpaceId,
      ActionsConstants.MEMBER_ADDED,
      bytes32(_newMemberSpaceId),
      ''
    );
    daoSpaceProxy.addMember(_newMemberSpaceId);

    // it grants _newMember the MEMBER role
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _newMemberSpaceId));
  }

  modifier whenDisableFastPathAccessForNewMembersIsTrue() {
    assertTrue(daoSpaceProxy.votingSettings().disableFastPathAccessForNewMembers);
    _;
  }

  function test_AddMember_When_newMemberIsNotAnEditor(bytes16 _newMemberSpaceId)
    external
    whenCalledByDAO
    when_newMemberIsNotAMember
    whenDisableFastPathAccessForNewMembersIsTrue
  {
    vm.assume(_newMemberSpaceId != _initialMemberASpaceId);
    vm.assume(_newMemberSpaceId != _initialMemberBSpaceId);
    vm.assume(_newMemberSpaceId != _initialEditorASpaceId);
    vm.assume(_newMemberSpaceId != _initialEditorBSpaceId);
    assertFalse(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _newMemberSpaceId));
    assertFalse(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _newMemberSpaceId));

    bytes16 _daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));
    _mockEnter(
      _spaceRegistry,
      _daoSpaceProxySpaceId,
      _daoSpaceProxySpaceId,
      ActionsConstants.SPACE_FAST_PATH_RESTRICTED,
      bytes32(_newMemberSpaceId),
      abi.encode(_newMemberSpaceId)
    );
    _mockEnter(
      _spaceRegistry,
      _daoSpaceProxySpaceId,
      _daoSpaceProxySpaceId,
      ActionsConstants.MEMBER_ADDED,
      bytes32(_newMemberSpaceId),
      ''
    );

    daoSpaceProxy.addMember(_newMemberSpaceId);

    // it grants _newMember the MEMBER role
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _newMemberSpaceId));
    // it grants FastPathRestricted to new member
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.FAST_PATH_RESTRICTED(), _newMemberSpaceId));
  }

  function test_AddMember_When_newMemberIsAlreadyAnEditor(bytes16 _newMemberSpaceId)
    external
    whenCalledByDAO
    when_newMemberIsNotAMember
    whenDisableFastPathAccessForNewMembersIsTrue
  {
    vm.assume(_newMemberSpaceId != _initialMemberASpaceId);
    vm.assume(_newMemberSpaceId != _initialEditorASpaceId);
    vm.assume(_newMemberSpaceId != _initialMemberBSpaceId);
    vm.assume(_newMemberSpaceId != _initialEditorBSpaceId);
    assertFalse(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _newMemberSpaceId));
    assertFalse(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _newMemberSpaceId));

    // Grant editor role initially
    bytes16 _daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));
    _mockEnter(
      _spaceRegistry,
      _daoSpaceProxySpaceId,
      _daoSpaceProxySpaceId,
      ActionsConstants.EDITOR_ADDED,
      bytes32(_newMemberSpaceId),
      ''
    );
    daoSpaceProxy.addEditor(_newMemberSpaceId);
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _newMemberSpaceId));

    _mockEnter(
      _spaceRegistry,
      _daoSpaceProxySpaceId,
      _daoSpaceProxySpaceId,
      ActionsConstants.MEMBER_ADDED,
      bytes32(_newMemberSpaceId),
      ''
    );
    daoSpaceProxy.addMember(_newMemberSpaceId);

    // it grants _newMember the MEMBER role
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _newMemberSpaceId));
    // it does not grant FastPathRestricted to new member
    assertFalse(daoSpaceProxy.hasRole(daoSpaceProxy.FAST_PATH_RESTRICTED(), _newMemberSpaceId));
  }

  function test_AddMember_WhenCalledByNon_DAO(address _caller, bytes16 _newMemberSpaceId) external {
    vm.assume(_caller != address(daoSpaceProxy));
    vm.prank(_caller);

    // it reverts with InvalidCaller
    vm.expectRevert(IDAOSpace.InvalidCaller.selector);
    daoSpaceProxy.addMember(_newMemberSpaceId);
  }

  /// REMOVE MEMBER ///

  function test_RemoveMember_When_oldMemberIsNotAMember(bytes16 _oldMemberSpaceId) external whenCalledByDAO {
    vm.assume(_oldMemberSpaceId != _initialMemberASpaceId);
    vm.assume(_oldMemberSpaceId != _initialMemberBSpaceId);

    // it reverts with InvalidSpaceIdForRole
    vm.expectRevert(IDAOSpace.InvalidSpaceIdForRole.selector);
    daoSpaceProxy.removeMember(_oldMemberSpaceId);
  }

  function test_RemoveMember_When_oldMemberIsAMember() external whenCalledByDAO {
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _initialMemberASpaceId));

    // it calls enter on the spaceRegistry with the MEMBER_REMOVED action
    _mockEnter(
      _spaceRegistry,
      _daoSpaceProxySpaceId,
      _daoSpaceProxySpaceId,
      ActionsConstants.MEMBER_REMOVED,
      bytes32(_initialMemberASpaceId),
      ''
    );
    daoSpaceProxy.removeMember(_initialMemberASpaceId);

    // it removes the MEMBER role from _oldMember
    assertFalse(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _initialMemberASpaceId));
  }

  function test_RemoveMember_WhenCalledByNon_DAO(address _caller, bytes16 _oldMemberSpaceId) external {
    vm.assume(_caller != address(daoSpaceProxy));
    vm.prank(_caller);

    // it reverts with InvalidCaller
    vm.expectRevert(IDAOSpace.InvalidCaller.selector);
    daoSpaceProxy.removeMember(_oldMemberSpaceId);
  }

  /// UNRESTRICT SPACE ///

  function test_UnrestrictSpace_When_oldRestrictedSpaceIdIsNotRestricted(bytes16 _oldRestrictedSpaceId)
    external
    whenCalledByDAO
  {
    daoSpaceProxy.workaround_revokeRole(daoSpaceProxy.FAST_PATH_RESTRICTED(), _oldRestrictedSpaceId);

    // it reverts with InvalidSpaceIdForRole
    vm.expectRevert(IDAOSpace.InvalidSpaceIdForRole.selector);
    daoSpaceProxy.unrestrictSpace(_oldRestrictedSpaceId);
  }

  function test_UnrestrictSpace_When_oldRestrictedSpaceIdIsRestricted(bytes16 _oldRestrictedSpaceId)
    external
    whenCalledByDAO
  {
    daoSpaceProxy.workaround_grantRole(daoSpaceProxy.FAST_PATH_RESTRICTED(), _oldRestrictedSpaceId);

    // it fetches the daoSpaceId from the spaceRegistry
    _mockAddressToSpaceId(_spaceRegistry, address(daoSpaceProxy), _daoSpaceProxySpaceId);

    // it calls enter on the spaceRegistry with the SPACE_FAST_PATH_UNRESTRICTED action
    _mockEnter(
      _spaceRegistry,
      _daoSpaceProxySpaceId,
      _daoSpaceProxySpaceId,
      ActionsConstants.SPACE_FAST_PATH_UNRESTRICTED,
      bytes32(_oldRestrictedSpaceId),
      abi.encode(_oldRestrictedSpaceId)
    );
    daoSpaceProxy.unrestrictSpace(_oldRestrictedSpaceId);

    // it revokes the FAST_PATH_RESTRICTED role from _oldRestrictedSpaceId
    assertFalse(daoSpaceProxy.hasRole(daoSpaceProxy.FAST_PATH_RESTRICTED(), _oldRestrictedSpaceId));
  }

  function test_UnrestrictSpace_WhenCalledByNon_DAO(address _caller, bytes16 _oldRestrictedSpaceId) external {
    vm.assume(_caller != address(daoSpaceProxy));
    vm.prank(_caller);

    // it reverts with InvalidCaller
    vm.expectRevert(IDAOSpace.InvalidCaller.selector);
    daoSpaceProxy.unrestrictSpace(_oldRestrictedSpaceId);
  }

  /// PING ///

  function test_Ping_WhenCalledByDAO(bytes32 _action, bytes32 _subject, bytes calldata _data) external whenCalledByDAO {
    // it fetches the daoSpaceId from the spaceRegistry
    _mockAddressToSpaceId(_spaceRegistry, address(daoSpaceProxy), _daoSpaceProxySpaceId);

    // it calls enter on the spaceRegistry with the input variables passed
    _mockEnter(_spaceRegistry, _daoSpaceProxySpaceId, _daoSpaceProxySpaceId, _action, _subject, _data);
    daoSpaceProxy.ping(_action, _subject, _data);
  }

  function test_Ping_WhenCalledByNon_DAO(
    address _caller,
    bytes32 _action,
    bytes32 _subject,
    bytes calldata _data
  ) external {
    vm.assume(_caller != address(daoSpaceProxy));
    vm.prank(_caller);

    // it reverts with InvalidCaller
    vm.expectRevert(IDAOSpace.InvalidCaller.selector);
    daoSpaceProxy.ping(_action, _subject, _data);
  }

  /// UPDATE VOTING SETTINGS ///

  function test_UpdateVotingSettings_WhenPartialPercentageSupportThresholdIsGreaterThanRATIO_BASE(uint256 _partialPercentageSupportThreshold)
    external
    whenCalledByDAO
  {
    vm.assume(_partialPercentageSupportThreshold > daoSpaceProxy.RATIO_BASE());
    _votingSettings.partialPercentageSupportThreshold = _partialPercentageSupportThreshold;

    // it reverts with InvalidSetting
    vm.expectRevert(IDAOSpace.InvalidSetting.selector);
    daoSpaceProxy.updateVotingSettings(_votingSettings);
  }

  function test_UpdateVotingSettings_WhenUniversalPercentageSupportThresholdIsGreaterThanRATIO_BASE(uint256 _universalPercentageSupportThreshold)
    external
    whenCalledByDAO
  {
    vm.assume(_universalPercentageSupportThreshold > daoSpaceProxy.RATIO_BASE());
    _votingSettings.universalPercentageSupportThreshold = _universalPercentageSupportThreshold;

    // it reverts with InvalidSetting
    vm.expectRevert(IDAOSpace.InvalidSetting.selector);
    daoSpaceProxy.updateVotingSettings(_votingSettings);
  }

  function test_UpdateVotingSettings_WhenFlatSupportThresholdIsGreaterThanTotalEditors(uint256 _flatSupportThreshold)
    external
    whenCalledByDAO
  {
    vm.assume(_flatSupportThreshold > daoSpaceProxy.totalEditors());
    _votingSettings.flatSupportThreshold = _flatSupportThreshold;

    // it reverts with InvalidSetting
    vm.expectRevert(IDAOSpace.InvalidSetting.selector);
    daoSpaceProxy.updateVotingSettings(_votingSettings);
  }

  function test_UpdateVotingSettings_WhenQuorumIsGreaterThanTotalEditors(uint256 _quorum) external whenCalledByDAO {
    vm.assume(_quorum > daoSpaceProxy.totalEditors());
    _votingSettings.quorum = _quorum;

    // it reverts with InvalidSetting
    vm.expectRevert(IDAOSpace.InvalidSetting.selector);
    daoSpaceProxy.updateVotingSettings(_votingSettings);
  }

  function test_UpdateVotingSettings_WhenDurationIsLessThanMINIMUM_VOTING_DURATION(uint256 _duration)
    external
    whenCalledByDAO
  {
    vm.assume(_duration < daoSpaceProxy.MINIMUM_VOTING_DURATION());
    _votingSettings.duration = _duration;

    // it reverts with InvalidSetting
    vm.expectRevert(IDAOSpace.InvalidSetting.selector);
    daoSpaceProxy.updateVotingSettings(_votingSettings);
  }

  function test_UpdateVotingSettings_WhenExecutionGracePeriodIsLessThanMINIMUM_EXECUTION_GRACE_PERIOD(uint256 _executionGracePeriod)
    external
    whenCalledByDAO
  {
    vm.assume(_executionGracePeriod < daoSpaceProxy.MINIMUM_EXECUTION_GRACE_PERIOD());
    _votingSettings.executionGracePeriod = _executionGracePeriod;

    // it reverts with InvalidSetting
    vm.expectRevert(IDAOSpace.InvalidSetting.selector);
    daoSpaceProxy.updateVotingSettings(_votingSettings);
  }

  function test_UpdateVotingSettings_WhenInputParamsAreValid(
    IDAOSpace.VotingSettings memory __votingSettings
  ) external whenCalledByDAO {
    __votingSettings.partialPercentageSupportThreshold = bound(
      __votingSettings.partialPercentageSupportThreshold, 0, daoSpaceProxy.RATIO_BASE()
    );
    __votingSettings.universalPercentageSupportThreshold =
      bound(__votingSettings.universalPercentageSupportThreshold, 0, daoSpaceProxy.RATIO_BASE());
    __votingSettings.flatSupportThreshold =
      bound(__votingSettings.flatSupportThreshold, 0, daoSpaceProxy.totalEditors());
    __votingSettings.quorum = bound(__votingSettings.quorum, 0, daoSpaceProxy.totalEditors());
    __votingSettings.duration =
      bound(__votingSettings.duration, daoSpaceProxy.MINIMUM_VOTING_DURATION(), type(uint256).max);
    __votingSettings.executionGracePeriod =
      bound(__votingSettings.executionGracePeriod, daoSpaceProxy.MINIMUM_EXECUTION_GRACE_PERIOD(), type(uint256).max);

    // it calls enter on the spaceRegistry with the VOTING_SETTINGS_UPDATED action
    _mockEnter(
      _spaceRegistry,
      _daoSpaceProxySpaceId,
      _daoSpaceProxySpaceId,
      ActionsConstants.VOTING_SETTINGS_UPDATED,
      '',
      abi.encode(__votingSettings)
    );
    daoSpaceProxy.updateVotingSettings(__votingSettings);

    // it updates the voting settings
    assertEq(abi.encode(daoSpaceProxy.votingSettings()), abi.encode(__votingSettings));
  }

  function test_UpdateVotingSettings_WhenCalledByNon_DAO(
    address _caller,
    IDAOSpace.VotingSettings calldata __votingSettings
  ) external {
    vm.assume(_caller != address(daoSpaceProxy));
    vm.prank(_caller);

    // it reverts with InvalidCaller
    vm.expectRevert(IDAOSpace.InvalidCaller.selector);
    daoSpaceProxy.updateVotingSettings(__votingSettings);
  }

  /// FETCH ///

  function test_Fetch_When_actionEqualsPROPOSAL_CREATED(bytes32 _subjectInput, uint256 _votingMode) external view {
    _votingMode = bound(_votingMode, 0, 1);
    bytes memory _createProposalData =
      abi.encode(_proposalId, IDAOSpace.VotingMode(_votingMode), new IDAOSpace.Action[](0));

    // it returns bytes32(_proposalId)
    assertEq(
      daoSpaceProxy.fetch(ActionsConstants.PROPOSAL_CREATED, _subjectInput, _createProposalData), bytes32(_proposalId)
    );
  }

  function test_Fetch_When_actionEqualsPROPOSAL_VOTED(bytes32 _subjectInput, uint256 _voteOption) external view {
    _voteOption = bound(_voteOption, 0, 3);
    bytes memory _voteProposalData = _createVoteForProposal(IDAOSpace.VoteOption(_voteOption));

    // it returns bytes32(_proposalId)
    assertEq(
      daoSpaceProxy.fetch(ActionsConstants.PROPOSAL_VOTED, _subjectInput, _voteProposalData), bytes32(_proposalId)
    );
  }

  function test_Fetch_When_actionEqualsPROPOSAL_UPDATED(bytes32 _subjectInput, uint256 _votingMode) external view {
    _votingMode = bound(_votingMode, 0, 1);
    bytes memory _updateProposalData =
      abi.encode(_proposalId, IDAOSpace.VotingMode(_votingMode), new IDAOSpace.Action[](0));

    // it returns bytes32(_proposalId)
    assertEq(
      daoSpaceProxy.fetch(ActionsConstants.PROPOSAL_UPDATED, _subjectInput, _updateProposalData), bytes32(_proposalId)
    );
  }

  function test_Fetch_When_actionEqualsPROPOSAL_EXECUTED(bytes32 _subjectInput) external view {
    bytes memory _executeProposalData = abi.encode(_proposalId);

    // it returns bytes32(_proposalId)
    assertEq(
      daoSpaceProxy.fetch(ActionsConstants.PROPOSAL_EXECUTED, _subjectInput, _executeProposalData), bytes32(_proposalId)
    );
  }

  function test_Fetch_When_actionEqualsSPACE_LEFT(bytes32 _subjectInput, bytes32 _role) external view {
    bytes memory _leaveSpaceData = abi.encode(_role);

    // it returns role
    assertEq(daoSpaceProxy.fetch(ActionsConstants.SPACE_LEFT, _subjectInput, _leaveSpaceData), bytes32(_role));
  }

  function test_Fetch_When_actionEqualsMEMBERSHIP_REQUESTED(
    bytes32 _subjectInput,
    bytes16 _newMemberSpaceId
  ) external view {
    bytes memory _requestMembershipData = abi.encode(_proposalId, _newMemberSpaceId);

    // it returns bytes32(_proposalId)
    assertEq(
      daoSpaceProxy.fetch(ActionsConstants.MEMBERSHIP_REQUESTED, _subjectInput, _requestMembershipData),
      bytes32(_proposalId)
    );
  }

  function test_Fetch_When_actionEqualsSPACE_FAST_PATH_RESTRICTED(
    bytes32 _subjectInput,
    bytes16 _spaceId
  ) external view {
    bytes memory _restrictSpaceData = abi.encode(_spaceId);

    // it returns bytes32(_spaceId)
    assertEq(
      daoSpaceProxy.fetch(ActionsConstants.SPACE_FAST_PATH_RESTRICTED, _subjectInput, _restrictSpaceData),
      bytes32(_spaceId)
    );
  }

  function test_Fetch_When_actionEqualsAnythingElse(
    bytes32 _action,
    bytes32 _subjectInput,
    bytes calldata _data
  ) external view {
    vm.assume(_action != ActionsConstants.PROPOSAL_CREATED);
    vm.assume(_action != ActionsConstants.PROPOSAL_VOTED);
    vm.assume(_action != ActionsConstants.PROPOSAL_UPDATED);
    vm.assume(_action != ActionsConstants.PROPOSAL_EXECUTED);
    vm.assume(_action != ActionsConstants.SPACE_LEFT);
    vm.assume(_action != ActionsConstants.MEMBERSHIP_REQUESTED);
    vm.assume(_action != ActionsConstants.SPACE_FAST_PATH_RESTRICTED);

    // it returns _subjectInput
    assertEq(daoSpaceProxy.fetch(_action, _subjectInput, _data), _subjectInput);
  }

  /// CAN EXECUTE PROPOSAL ///

  function test_CanExecuteProposal_WhenProposalDoesNotExist() external {
    // it returns false
    assertFalse(daoSpaceProxy.canExecuteProposal(_proposalId));
  }

  function test_CanExecuteProposal_WhenProposalHasAlreadyBeenExecuted() external {
    // Create proposal where it has already been executed
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      true,
      1,
      _initialEditorASpaceId,
      vm.getBlockTimestamp(),
      vm.getBlockTimestamp() + _votingSettings.duration,
      vm.getBlockTimestamp() + _votingSettings.duration + _votingSettings.executionGracePeriod,
      IDAOSpace.VotingMode.Fast,
      _votingSettings.quorum,
      _votingSettings.partialPercentageSupportThreshold,
      _votingSettings.universalPercentageSupportThreshold,
      0,
      new IDAOSpace.Action[](0)
    );

    // it returns false
    assertFalse(daoSpaceProxy.canExecuteProposal(_proposalId));
  }

  function test_CanExecuteProposal_WhenTimersNotStarted(uint256 _votingMode) external {
    _votingMode = bound(_votingMode, 0, 1);

    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      _proposalVersion,
      _initialEditorASpaceId,
      0,
      0,
      0,
      IDAOSpace.VotingMode(_votingMode),
      _votingSettings.quorum,
      _votingSettings.partialPercentageSupportThreshold,
      _votingSettings.universalPercentageSupportThreshold,
      _votingSettings.flatSupportThreshold,
      new IDAOSpace.Action[](0)
    );
    daoSpaceProxy.workaround_setTally(_proposalId, _votingSettings.flatSupportThreshold + 1, 0, 0);

    // it returns false
    assertFalse(daoSpaceProxy.canExecuteProposal(_proposalId));
  }

  function test_CanExecuteProposal_WhenSupportThresholdIsNotReached() external {
    // Create proposal where the threshold is not reached
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      1,
      _initialEditorASpaceId,
      vm.getBlockTimestamp(),
      vm.getBlockTimestamp() + _votingSettings.duration,
      vm.getBlockTimestamp() + _votingSettings.duration + _votingSettings.executionGracePeriod,
      IDAOSpace.VotingMode.Fast,
      _votingSettings.quorum,
      _votingSettings.partialPercentageSupportThreshold,
      _votingSettings.universalPercentageSupportThreshold,
      1,
      new IDAOSpace.Action[](0)
    );
    daoSpaceProxy.workaround_setTally(_proposalId, 0, 0, 0);

    // it returns false
    assertFalse(daoSpaceProxy.canExecuteProposal(_proposalId));
  }

  function test_CanExecuteProposal_WhenPastExecuteBy(uint256 _executeBy) external {
    _executeBy = bound(
      _executeBy,
      vm.getBlockTimestamp() + _votingSettings.duration + _votingSettings.executionGracePeriod,
      vm.getBlockTimestamp() + _votingSettings.duration + _votingSettings.executionGracePeriod + 365 days
    );
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      1,
      _initialEditorASpaceId,
      vm.getBlockTimestamp(),
      vm.getBlockTimestamp() + _votingSettings.duration,
      _executeBy,
      IDAOSpace.VotingMode.Fast,
      _votingSettings.quorum,
      _votingSettings.partialPercentageSupportThreshold,
      _votingSettings.universalPercentageSupportThreshold,
      0,
      new IDAOSpace.Action[](0)
    );
    daoSpaceProxy.workaround_setTally(_proposalId, 2, 0, 0);

    vm.warp(_executeBy + 1);

    // it returns false (support met but execution window ended)
    assertFalse(daoSpaceProxy.canExecuteProposal(_proposalId));
  }

  function test_CanExecuteProposal_WhenProposalIsExecutable() external {
    // Create proposal where the threshold has been reached
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      1,
      _initialEditorASpaceId,
      vm.getBlockTimestamp(),
      vm.getBlockTimestamp() + _votingSettings.duration,
      vm.getBlockTimestamp() + _votingSettings.duration + _votingSettings.executionGracePeriod,
      IDAOSpace.VotingMode.Fast,
      _votingSettings.quorum,
      _votingSettings.partialPercentageSupportThreshold,
      _votingSettings.universalPercentageSupportThreshold,
      0,
      new IDAOSpace.Action[](0)
    );
    daoSpaceProxy.workaround_setTally(_proposalId, 1, 0, 0);

    // it returns true
    assertTrue(daoSpaceProxy.canExecuteProposal(_proposalId));
  }

  /// IS SUPPORT THRESHOLD REACHED ///

  modifier whenTheProposalVotingModeIsSlow() {
    _;
  }

  function test_IsSupportThresholdReached_WhenTheVotingQuorumHasNotBeenReached(
    uint256 _yes,
    uint256 _no,
    uint256 _abstain,
    uint256 _quorum
  ) external whenTheProposalVotingModeIsSlow {
    // set up
    _yes = bound(_yes, 0, 1e3);
    _no = bound(_no, 0, 1e3);
    _abstain = bound(_abstain, 0, 1e3);
    _quorum = bound(_quorum, _yes + _no + _abstain + 1, 1e4);
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      _proposalVersion,
      _initialEditorASpaceId,
      vm.getBlockTimestamp(),
      vm.getBlockTimestamp() + _votingSettings.duration,
      vm.getBlockTimestamp() + _votingSettings.duration + _votingSettings.executionGracePeriod,
      IDAOSpace.VotingMode.Slow,
      _quorum,
      _votingSettings.partialPercentageSupportThreshold,
      _votingSettings.universalPercentageSupportThreshold,
      _votingSettings.flatSupportThreshold,
      new IDAOSpace.Action[](0)
    );
    daoSpaceProxy.workaround_setTally(_proposalId, _yes, _no, _abstain);

    // it returns false
    assertFalse(daoSpaceProxy.isSupportThresholdReached(_proposalId));
  }

  function test_IsSupportThresholdReached_WhenTheYesVotesAreGreaterThanTheUniversalPercentageSupportThreshold(
    uint256 _yes,
    uint256 _no,
    uint256 _abstain,
    uint256 _none,
    uint256 _quorum,
    uint256 _universalPercentageSupportThreshold
  ) external whenTheProposalVotingModeIsSlow {
    // set up
    _yes = bound(_yes, 1, 1e3);
    _no = bound(_no, 0, 1e3);
    _abstain = bound(_abstain, 0, 1e3);
    _none = bound(_none, 0, 1e3);
    _quorum = bound(_quorum, 0, _yes + _no + _abstain);
    _universalPercentageSupportThreshold = bound(_universalPercentageSupportThreshold, 1, daoSpaceProxy.RATIO_BASE());
    vm.assume(
      (_yes * daoSpaceProxy.RATIO_BASE() > (_universalPercentageSupportThreshold - 1) * (_yes + _no + _abstain + _none))
    );
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      _proposalVersion,
      _initialEditorASpaceId,
      vm.getBlockTimestamp(),
      vm.getBlockTimestamp() + _votingSettings.duration,
      vm.getBlockTimestamp() + _votingSettings.duration + _votingSettings.executionGracePeriod,
      IDAOSpace.VotingMode.Slow,
      _quorum,
      daoSpaceProxy.RATIO_BASE(),
      _universalPercentageSupportThreshold,
      _votingSettings.flatSupportThreshold,
      new IDAOSpace.Action[](0)
    );
    daoSpaceProxy.workaround_setTally(_proposalId, _yes, _no, _abstain);
    daoSpaceProxy.workaround_setTotalEditors(_yes + _no + _abstain + _none);

    // it returns true
    assertTrue(daoSpaceProxy.isSupportThresholdReached(_proposalId));
  }

  function test_IsSupportThresholdReached_WhenTheProposalLastDateIsZero() external whenTheProposalVotingModeIsSlow {
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      _proposalVersion,
      _initialEditorASpaceId,
      vm.getBlockTimestamp(),
      0,
      0,
      IDAOSpace.VotingMode.Slow,
      1,
      _votingSettings.partialPercentageSupportThreshold,
      daoSpaceProxy.RATIO_BASE(),
      _votingSettings.flatSupportThreshold,
      new IDAOSpace.Action[](0)
    );
    daoSpaceProxy.workaround_setTally(_proposalId, 1, 0, 0);
    daoSpaceProxy.workaround_setTotalEditors(2);

    // it returns false
    assertFalse(daoSpaceProxy.isSupportThresholdReached(_proposalId));
  }

  function test_IsSupportThresholdReached_WhenTheBlockTimestampIsLessThanOrEqualToTheProposalLastDate(
    uint256 _yes,
    uint256 _no,
    uint256 _abstain,
    uint256 _none,
    uint256 _quorum,
    uint256 _universalPercentageSupportThreshold
  ) external whenTheProposalVotingModeIsSlow {
    // set up
    _yes = bound(_yes, 1, 1e3);
    _no = bound(_no, 0, 1e3);
    _abstain = bound(_abstain, 0, 1e3);
    _none = bound(_none, 0, 1e3);
    _quorum = bound(_quorum, 0, _yes + _no + _abstain);
    _universalPercentageSupportThreshold = bound(_universalPercentageSupportThreshold, 1, daoSpaceProxy.RATIO_BASE());
    vm.assume(
      (_yes * daoSpaceProxy.RATIO_BASE()
          <= (_universalPercentageSupportThreshold - 1) * (_yes + _no + _abstain + _none))
    );
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      _proposalVersion,
      _initialEditorASpaceId,
      vm.getBlockTimestamp(),
      vm.getBlockTimestamp() + _votingSettings.duration,
      vm.getBlockTimestamp() + _votingSettings.duration + _votingSettings.executionGracePeriod,
      IDAOSpace.VotingMode.Slow,
      _quorum,
      _votingSettings.partialPercentageSupportThreshold,
      _universalPercentageSupportThreshold,
      _votingSettings.flatSupportThreshold,
      new IDAOSpace.Action[](0)
    );
    daoSpaceProxy.workaround_setTally(_proposalId, _yes, _no, _abstain);
    daoSpaceProxy.workaround_setTotalEditors(_yes + _no + _abstain + _none);
    vm.warp(vm.getBlockTimestamp() + _votingSettings.duration);

    // it returns false
    assertFalse(daoSpaceProxy.isSupportThresholdReached(_proposalId));
  }

  function test_IsSupportThresholdReached_WhenTheYesVotesAreNotGreaterThanThePartialPercentageSupportThreshold(
    uint256 _yes,
    uint256 _no,
    uint256 _abstain,
    uint256 _none,
    uint256 _quorum,
    uint256 _universalPercentageSupportThreshold,
    uint256 _partialPercentageSupportThreshold
  ) external whenTheProposalVotingModeIsSlow {
    // set up
    _yes = bound(_yes, 0, 1e3);
    _no = bound(_no, 0, 1e3);
    _abstain = bound(_abstain, 0, 1e3);
    _none = bound(_none, 0, 1e3);
    _quorum = bound(_quorum, 0, _yes + _no + _abstain);
    _universalPercentageSupportThreshold = bound(_universalPercentageSupportThreshold, 1, daoSpaceProxy.RATIO_BASE());
    vm.assume(
      (_yes * daoSpaceProxy.RATIO_BASE()
          <= (_universalPercentageSupportThreshold - 1) * (_yes + _no + _abstain + _none))
    );
    _partialPercentageSupportThreshold = bound(_partialPercentageSupportThreshold, 1, daoSpaceProxy.RATIO_BASE());
    vm.assume(
      (daoSpaceProxy.RATIO_BASE() - (_partialPercentageSupportThreshold - 1)) * _yes
        <= (_partialPercentageSupportThreshold - 1) * _no
    );
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      _proposalVersion,
      _initialEditorASpaceId,
      vm.getBlockTimestamp(),
      vm.getBlockTimestamp() + _votingSettings.duration,
      vm.getBlockTimestamp() + _votingSettings.duration + _votingSettings.executionGracePeriod,
      IDAOSpace.VotingMode.Slow,
      _quorum,
      _partialPercentageSupportThreshold,
      _universalPercentageSupportThreshold,
      _votingSettings.flatSupportThreshold,
      new IDAOSpace.Action[](0)
    );
    daoSpaceProxy.workaround_setTally(_proposalId, _yes, _no, _abstain);
    daoSpaceProxy.workaround_setTotalEditors(_yes + _no + _abstain + _none);
    vm.warp(vm.getBlockTimestamp() + _votingSettings.duration + 1);

    // it returns false
    assertFalse(daoSpaceProxy.isSupportThresholdReached(_proposalId));
  }

  function test_IsSupportThresholdReached_WhenTheYesVotesAreGreaterThanThePartialPercentageSupportThreshold(
    uint256 _yes,
    uint256 _no,
    uint256 _abstain,
    uint256 _none,
    uint256 _quorum,
    uint256 _universalPercentageSupportThreshold,
    uint256 _partialPercentageSupportThreshold
  ) external whenTheProposalVotingModeIsSlow {
    // set up
    _yes = bound(_yes, 1, 1e3);
    _no = bound(_no, 0, 1e3);
    _abstain = bound(_abstain, 0, 1e3);
    _none = bound(_none, 0, 1e3);
    _quorum = bound(_quorum, 0, _yes + _no + _abstain);
    _universalPercentageSupportThreshold = bound(_universalPercentageSupportThreshold, 1, daoSpaceProxy.RATIO_BASE());
    vm.assume(
      (_yes * daoSpaceProxy.RATIO_BASE()
          <= (_universalPercentageSupportThreshold - 1) * (_yes + _no + _abstain + _none))
    );
    _partialPercentageSupportThreshold = bound(_partialPercentageSupportThreshold, 1, daoSpaceProxy.RATIO_BASE());
    vm.assume(
      (daoSpaceProxy.RATIO_BASE() - (_partialPercentageSupportThreshold - 1)) * _yes
        > (_partialPercentageSupportThreshold - 1) * _no
    );
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      _proposalVersion,
      _initialEditorASpaceId,
      vm.getBlockTimestamp(),
      vm.getBlockTimestamp() + _votingSettings.duration,
      vm.getBlockTimestamp() + _votingSettings.duration + _votingSettings.executionGracePeriod,
      IDAOSpace.VotingMode.Slow,
      _quorum,
      _partialPercentageSupportThreshold,
      _universalPercentageSupportThreshold,
      _votingSettings.flatSupportThreshold,
      new IDAOSpace.Action[](0)
    );
    daoSpaceProxy.workaround_setTally(_proposalId, _yes, _no, _abstain);
    daoSpaceProxy.workaround_setTotalEditors(_yes + _no + _abstain + _none);
    vm.warp(vm.getBlockTimestamp() + _votingSettings.duration + 1);

    // it returns true
    assertTrue(daoSpaceProxy.isSupportThresholdReached(_proposalId));
  }

  modifier whenTheProposalVotingModeIsFast() {
    _;
  }

  function test_IsSupportThresholdReached_WhenTheYesVotesAreNotGreaterThanTheFlatSupportThreshold(
    uint256 _yes,
    uint256 _flatSupportThreshold
  ) external whenTheProposalVotingModeIsFast {
    // set up
    _yes = bound(_yes, 0, 1e3);
    _flatSupportThreshold = bound(_flatSupportThreshold, _yes + 1, 1e4);
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      _proposalVersion,
      _initialEditorASpaceId,
      vm.getBlockTimestamp(),
      vm.getBlockTimestamp() + _votingSettings.duration,
      vm.getBlockTimestamp() + _votingSettings.duration + _votingSettings.executionGracePeriod,
      IDAOSpace.VotingMode.Fast,
      _votingSettings.quorum,
      _votingSettings.partialPercentageSupportThreshold,
      _votingSettings.universalPercentageSupportThreshold,
      _flatSupportThreshold,
      new IDAOSpace.Action[](0)
    );
    daoSpaceProxy.workaround_setTally(_proposalId, _yes, 0, 0);

    // it returns false
    assertFalse(daoSpaceProxy.isSupportThresholdReached(_proposalId));
  }

  function test_IsSupportThresholdReached_WhenTheYesVotesAreGreaterThanTheFlatSupportThreshold(
    uint256 _yes,
    uint256 _flatSupportThreshold
  ) external whenTheProposalVotingModeIsFast {
    // set up
    _flatSupportThreshold = bound(_flatSupportThreshold, 0, 1e3);
    _yes = bound(_yes, _flatSupportThreshold + 1, 1e4);
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      _proposalVersion,
      _initialEditorASpaceId,
      vm.getBlockTimestamp(),
      vm.getBlockTimestamp() + _votingSettings.duration,
      vm.getBlockTimestamp() + _votingSettings.duration + _votingSettings.executionGracePeriod,
      IDAOSpace.VotingMode.Fast,
      _votingSettings.quorum,
      _votingSettings.partialPercentageSupportThreshold,
      _votingSettings.universalPercentageSupportThreshold,
      _flatSupportThreshold,
      new IDAOSpace.Action[](0)
    );
    daoSpaceProxy.workaround_setTally(_proposalId, _yes, 0, 0);

    // it returns true
    assertTrue(daoSpaceProxy.isSupportThresholdReached(_proposalId));
  }

  /// TYPEID ///

  function test_TypeId_WhenCalled() external view {
    // it returns the type
    assertEq(daoSpaceProxy.typeId(), keccak256('DAO_SPACE'));
  }

  /// NAME ///

  function test_Name_WhenCalled() external view {
    // it returns the name
    assertEq(daoSpaceProxy.name(), 'DAO_SPACE');
  }

  /// VERSION ///

  function test_Version_WhenCalled() external view {
    // it returns semantic version
    assertEq(daoSpaceProxy.version(), '1.0.0');
  }

  /// HELPERS ///

  function _mockAddressToSpaceId(address __spaceRegistry, address __account, bytes16 __spaceId) internal {
    _mockAndExpect(__spaceRegistry, abi.encodeCall(ISpaceRegistry.addressToSpaceId, (__account)), abi.encode(__spaceId));
  }

  function _mockRegisterSpaceId(
    address __spaceRegistry,
    bytes32 __spaceType,
    bytes memory __spaceVersion,
    bytes16 __spaceId
  ) internal {
    _mockAndExpect(
      __spaceRegistry,
      abi.encodeCall(ISpaceRegistry.registerSpaceId, (__spaceType, __spaceVersion)),
      abi.encode(__spaceId)
    );
  }

  function _mockEnter(
    address __spaceRegistry,
    bytes16 __fromSpaceId,
    bytes16 __toSpaceId,
    bytes32 _action,
    bytes32 _subject,
    bytes memory _data
  ) internal {
    _mockAndExpect(
      __spaceRegistry,
      abi.encodeCall(ISpaceRegistry.enter, (__fromSpaceId, __toSpaceId, _action, _subject, _data, '')),
      abi.encode()
    );
  }

  function _createSlowPathProposalToAddEditor() internal view returns (bytes memory _createProposalData) {
    IDAOSpace.VotingMode _votingMode = IDAOSpace.VotingMode.Slow;
    IDAOSpace.Action[] memory _actions = new IDAOSpace.Action[](1);
    _actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addEditor, (_randomCallerSpaceId))
    });
    return abi.encode(_proposalId, _votingMode, _actions);
  }

  /// @dev valid proposal because action is fast path valid
  function _createFastPathProposalToAddMember() internal view returns (bytes memory _createProposalData) {
    IDAOSpace.VotingMode _votingMode = IDAOSpace.VotingMode.Fast;
    IDAOSpace.Action[] memory _actions = new IDAOSpace.Action[](1);
    _actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addMember, (_randomCallerSpaceId))
    });
    return abi.encode(_proposalId, _votingMode, _actions);
  }

  /// @dev invalid proposal because it attempts to perform two actions
  function _createFastPathProposalToAddTwoMembers() internal view returns (bytes memory _createProposalData) {
    IDAOSpace.VotingMode _votingMode = IDAOSpace.VotingMode.Fast;
    IDAOSpace.Action[] memory _actions = new IDAOSpace.Action[](2);
    _actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addMember, (_randomCallerSpaceId))
    });
    _actions[1] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addMember, (_randomCallerSpaceId))
    });
    return abi.encode(_proposalId, _votingMode, _actions);
  }

  /// @dev invalid proposal because the action is not fast path valid
  function _createFastPathProposalToAddEditor() internal view returns (bytes memory _createProposalData) {
    IDAOSpace.VotingMode _votingMode = IDAOSpace.VotingMode.Fast;
    IDAOSpace.Action[] memory _actions = new IDAOSpace.Action[](1);
    _actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addEditor, (_randomCallerSpaceId))
    });
    return abi.encode(_proposalId, _votingMode, _actions);
  }

  /// @dev invalid target because the action attempts to write in another contract
  function _createFastPathProposalToAddMemberOnAnotherContract()
    internal
    view
    returns (bytes memory _createProposalData)
  {
    IDAOSpace.VotingMode _votingMode = IDAOSpace.VotingMode.Fast;
    IDAOSpace.Action[] memory _actions = new IDAOSpace.Action[](1);
    _actions[0] = IDAOSpace.Action({
      to: address(this), value: 0, data: abi.encodeCall(IDAOSpace.addMember, (_randomCallerSpaceId))
    });
    return abi.encode(_proposalId, _votingMode, _actions);
  }

  /// @dev invalid funds transfer because the action entails a funds transfer
  function _createFastPathProposalToAddMemberAndMoveValue() internal view returns (bytes memory _createProposalData) {
    IDAOSpace.VotingMode _votingMode = IDAOSpace.VotingMode.Fast;
    IDAOSpace.Action[] memory _actions = new IDAOSpace.Action[](1);
    _actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 1, data: abi.encodeCall(IDAOSpace.addMember, (_randomCallerSpaceId))
    });
    return abi.encode(_proposalId, _votingMode, _actions);
  }

  function _createVoteForProposal(
    IDAOSpace.VoteOption _votingOption
  ) internal view returns (bytes memory _voteProposalData) {
    return abi.encode(_proposalId, _proposalVersion, _votingOption);
  }

  function _deferredProposalParameters(
    IDAOSpace.VotingMode _votingMode
  ) internal view returns (IDAOSpace.ProposalParameters memory _parameters) {
    _parameters = IDAOSpace.ProposalParameters({
      votingMode: _votingMode,
      partialPercentageSupportThreshold: _votingSettings.partialPercentageSupportThreshold,
      universalPercentageSupportThreshold: _votingSettings.universalPercentageSupportThreshold,
      flatSupportThreshold: _votingSettings.flatSupportThreshold,
      quorum: _votingSettings.quorum,
      startDate: 0,
      lastDate: 0,
      executeBy: 0
    });
  }

  function _activeProposalParameters(
    IDAOSpace.VotingMode _votingMode,
    uint256 _startDate
  ) internal view returns (IDAOSpace.ProposalParameters memory _parameters) {
    _parameters = _deferredProposalParameters(_votingMode);
    _parameters.startDate = _startDate;
    _parameters.lastDate = _startDate + _votingSettings.duration;
    _parameters.executeBy = _parameters.lastDate + _votingSettings.executionGracePeriod;
  }

  /// @dev Don't increment nonce here to keep later lookup easier; uses nonce 0. UUID v4 compliant.
  function _getSpaceId(address _account) internal view returns (bytes16 _spaceId) {
    bytes32 _hash = keccak256(abi.encodePacked('grc20.space', _account, uint256(0), block.chainid));
    _hash = _hash & ~(bytes32(uint256(0xf0)) << 200) | (bytes32(uint256(0x40)) << 200);
    _spaceId = bytes16(_hash & ~(bytes32(uint256(0xc0)) << 184) | (bytes32(uint256(0x80)) << 184));
  }
}
