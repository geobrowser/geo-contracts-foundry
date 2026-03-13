// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {TestHelper} from 'test/unit/helpers/TestHelper.t.sol';

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
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
  bytes16[] internal _initialEditors;
  bytes16[] internal _initialMembers;
  bytes32 internal _spaceType;
  bytes internal _spaceVersion;
  uint8 internal _proposalVersion;

  address internal _randomCaller = makeAddr('_randomCaller');
  address internal _spaceRegistry = makeAddr('_spaceRegistry');
  bytes16 internal _fromSpaceId = bytes16(keccak256('_fromSpaceId'));
  bytes16 internal _toSpaceId = bytes16(keccak256('_toSpaceId'));
  bytes16 internal _initialEditorASpaceId = bytes16(keccak256('_initialEditorASpaceId'));
  bytes16 internal _initialEditorBSpaceId = bytes16(keccak256('_initialEditorBSpaceId'));
  bytes16 internal _initialMemberASpaceId = bytes16(keccak256('_initialMemberASpaceId'));
  bytes16 internal _initialMemberBSpaceId = bytes16(keccak256('_initialMemberBSpaceId'));
  bytes internal _publishEditsData = 'Curiouser and curiouser!';
  bytes16 internal _initialTopicId = bytes16(keccak256('_initialTopicId'));
  bytes16 internal _proposalId = bytes16(keccak256('_proposalId'));

  function setUp() external {
    // set up
    (_owner, _ownerPrivateKey) = makeAddrAndKey('_owner');
    _votingSettings = IDAOSpace.VotingSettings({
      partialPercentageSupportThreshold: 5e5,
      universalPercentageSupportThreshold: 5e5,
      flatSupportThreshold: 1,
      quorum: 1,
      duration: 2 days,
      defaultFastPathAccessForMembers: false
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

    // when delegate called
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

    // it calls enter on the spaceRegistry with the MEMBER_ADDED action
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
      ActionsConstants.MEMBER_ADDED,
      bytes32(_initialMemberBSpaceId),
      ''
    );

    // mock for _grantRole call
    _mockAddressToSpaceId(_spaceRegistry, _spaceRegistry, _getSpaceId(_spaceRegistry));

    // when deployed
    daoSpaceProxy = MockDAOSpace(
      UnsafeUpgrades.deployBeaconProxy(
        daoSpaceBeacon,
        abi.encodeCall(
          IDAOSpace.initialize,
          (abi.encode(
              _spaceRegistry, _votingSettings, _initialEditors, _initialMembers, _publishEditsData, _initialTopicId
            ))
        )
      )
    );
  }

  /// CONSTANTS ///

  function test_Constants_WhenDeployed() external view {
    // it sets MINIMUM_VOTING_DURATION to 1 minute
    assertEq(daoSpaceProxy.MINIMUM_VOTING_DURATION(), 1 minutes);

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

  function test_Initialize_WhenDelegateCalled(
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

    // it calls enter on the spaceRegistry with the MEMBER_ADDED action
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
      ActionsConstants.MEMBER_ADDED,
      bytes32(_initialMemberBSpaceId),
      ''
    );

    // mock _grantRole call
    _mockAddressToSpaceId(__spaceRegistry, __spaceRegistry, _getSpaceId(__spaceRegistry));

    // when delegate called
    daoSpaceProxy = MockDAOSpace(
      UnsafeUpgrades.deployBeaconProxy(
        daoSpaceBeacon,
        abi.encodeCall(
          IDAOSpace.initialize,
          (abi.encode(
              __spaceRegistry, _votingSettings, _initialEditors, _initialMembers, __publishEditsData, __initialTopicId
            ))
        )
      )
    );

    // it sets the spaceRegistry
    assertEq(address(daoSpaceProxy.spaceRegistry()), __spaceRegistry);

    // it sets the voting settings
    assertEq(abi.encode(daoSpaceProxy.votingSettings()), abi.encode(_votingSettings));

    // it grants the new editors the EDITOR role
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _initialEditorASpaceId));
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _initialEditorBSpaceId));

    // it grants the new members the MEMBER role
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _initialMemberASpaceId));
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _initialMemberBSpaceId));

    // it grants itself the DAO role
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.DAO(), _getSpaceId(address(daoSpaceProxy))));

    // it sets addMember as a valid fast path action
    assertTrue(daoSpaceProxy.actionIsFastPathValid(IDAOSpace.addMember.selector));

    // it sets removeMember as a valid fast path action
    assertTrue(daoSpaceProxy.actionIsFastPathValid(IDAOSpace.removeMember.selector));

    // it sets ping as a valid fast path action
    assertTrue(daoSpaceProxy.actionIsFastPathValid(IDAOSpace.ping.selector));
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

    // it calls enter on the spaceRegistry with the MEMBER_ADDED action
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
      ActionsConstants.MEMBER_ADDED,
      bytes32(_initialMemberBSpaceId),
      ''
    );

    // mock _grantRole call
    _mockAddressToSpaceId(__spaceRegistry, __spaceRegistry, _getSpaceId(__spaceRegistry));

    // when delegate called
    daoSpaceProxy = MockDAOSpace(
      UnsafeUpgrades.deployBeaconProxy(
        daoSpaceBeacon,
        abi.encodeCall(
          IDAOSpace.initialize,
          (abi.encode(
              __spaceRegistry, _votingSettings, _initialEditors, _initialMembers, __publishEditsData, __initialTopicId
            ))
        )
      )
    );

    // it reverts with InvalidInitialization
    vm.expectRevert(Initializable.InvalidInitialization.selector);

    // when delegate called again
    daoSpaceProxy.initialize(
      abi.encode(
        __spaceRegistry, _votingSettings, _initialEditors, _initialMembers, _publishEditsData, __initialTopicId
      )
    );
  }

  function test_Initialize_WhenCalled() external {
    // it reverts with InvalidInitialization
    vm.expectRevert(Initializable.InvalidInitialization.selector);

    // when called again
    daoSpaceProxy.initialize(
      abi.encode(_spaceRegistry, _votingSettings, _initialEditors, _initialMembers, _publishEditsData, _initialTopicId)
    );
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

    _mockAddressToSpaceId(_spaceRegistry, _spaceRegistry, _getSpaceId(_spaceRegistry));

    bytes memory _proposalData = _createSlowPathProposalToAddEditor();
    daoSpaceProxy.write(_getSpaceId(_randomCaller), ActionsConstants.PROPOSAL_CREATED, _subject, _proposalData);
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
      0,
      _getSpaceId(_randomCaller),
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

    bytes memory _proposalData = _createSlowPathProposalToAddEditor();
    daoSpaceProxy.write(_getSpaceId(_randomCaller), ActionsConstants.PROPOSAL_CREATED, _subject, _proposalData);
  }

  function test_Write_When_createProposalParamsAreValid(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_CREATED
    whenTheVotingModeIsSlow
  {
    // it calls enter on the spaceRegistry with the PROPOSAL_SETTINGS_SELECTED action
    bytes16 _daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));
    _mockEnter(
      _spaceRegistry,
      _daoSpaceProxySpaceId,
      _daoSpaceProxySpaceId,
      ActionsConstants.PROPOSAL_SETTINGS_SELECTED,
      bytes32(_proposalId),
      abi.encode(
        vm.getBlockTimestamp(),
        vm.getBlockTimestamp() + _votingSettings.duration,
        IDAOSpace.VotingMode.Slow,
        _votingSettings.quorum,
        _votingSettings.partialPercentageSupportThreshold,
        _votingSettings.universalPercentageSupportThreshold,
        _votingSettings.flatSupportThreshold
      )
    );

    // when called
    bytes memory _proposalData = _createSlowPathProposalToAddEditor();
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_CREATED, _subject, _proposalData);

    (, bytes16 _creator, IDAOSpace.ProposalParameters memory _parameters,, IDAOSpace.Action[] memory _actions) =
      daoSpaceProxy.getLatestProposalInformation(_proposalId);

    // it increments the proposal version
    assertEq(daoSpaceProxy.latestProposalVersion(_proposalId), 1);

    // it sets the proposal creator to _fromSpaceId
    assertEq(_creator, _initialEditorASpaceId);

    // it sets the proposal start date to block.timestamp
    assertEq(_parameters.startDate, vm.getBlockTimestamp());

    // it sets the proposal last date to block.timestamp plus votingSettings.duration
    assertEq(_parameters.lastDate, vm.getBlockTimestamp() + _votingSettings.duration);

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
    assertEq(_actions[0].data, abi.encodeCall(IDAOSpace.addEditor, (_getSpaceId(_randomCaller))));
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

    bytes memory _proposalData = _createFastPathProposalToAddMember();
    daoSpaceProxy.write(_getSpaceId(_randomCaller), ActionsConstants.PROPOSAL_CREATED, _subject, _proposalData);
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
      0,
      _getSpaceId(_randomCaller),
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

    bytes memory _proposalData = _createFastPathProposalToAddMember();
    daoSpaceProxy.write(_getSpaceId(_randomCaller), ActionsConstants.PROPOSAL_CREATED, _subject, _proposalData);
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

    bytes memory _proposalData = _createFastPathProposalToAddMember();
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_CREATED, _subject, _proposalData);
  }

  function test_Write_WhenTheDecodedProposalActionIsNotLimitedToOneCall(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_CREATED
    whenTheVotingModeIsFast
  {
    // it reverts with OneActionForFastPath
    vm.expectRevert(IDAOSpace.OneActionForFastPath.selector);

    bytes memory _proposalData = _createFastPathProposalToAddTwoMembers();
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_CREATED, _subject, _proposalData);
  }

  function test_Write_WhenTheFunctionSelectorOfTheDecodedProposalActionIsNotFastPathValid(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_CREATED
    whenTheVotingModeIsFast
  {
    // it reverts with InvalidAction
    vm.expectRevert(IDAOSpace.InvalidAction.selector);

    bytes memory _proposalData = _createFastPathProposalToAddEditor();
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_CREATED, _subject, _proposalData);
  }

  function test_Write_WhenTheTargetAddressIsNotTheDAOContractItself(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_CREATED
    whenTheVotingModeIsFast
  {
    // it reverts with InvalidTarget
    vm.expectRevert(IDAOSpace.InvalidTarget.selector);

    bytes memory _proposalData = _createFastPathProposalToAddMemberOnAnotherContract();
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_CREATED, _subject, _proposalData);
  }

  function test_Write_WhenTheProposalAttemptsToTransferValue(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_CREATED
    whenTheVotingModeIsFast
  {
    // it reverts with InvalidFundsTransfer
    vm.expectRevert(IDAOSpace.InvalidFundsTransfer.selector);

    bytes memory _proposalData = _createFastPathProposalToAddMemberAndMoveValue();
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_CREATED, _subject, _proposalData);
  }

  function test_Write_When_createProposalParamsAreValid_WhenTheVotingModeIsFast(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_CREATED
    whenTheVotingModeIsFast
  {
    // get voting settings
    IDAOSpace.VotingSettings memory _votingSettings = daoSpaceProxy.votingSettings();

    // it calls enter on the spaceRegistry with the PROPOSAL_SETTINGS_SELECTED action
    bytes16 _daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));
    _mockEnter(
      _spaceRegistry,
      _daoSpaceProxySpaceId,
      _daoSpaceProxySpaceId,
      ActionsConstants.PROPOSAL_SETTINGS_SELECTED,
      bytes32(_proposalId),
      abi.encode(
        vm.getBlockTimestamp(),
        vm.getBlockTimestamp() + _votingSettings.duration,
        IDAOSpace.VotingMode.Fast,
        _votingSettings.quorum,
        _votingSettings.partialPercentageSupportThreshold,
        _votingSettings.universalPercentageSupportThreshold,
        _votingSettings.flatSupportThreshold
      )
    );

    // when called
    bytes memory _proposalData = _createFastPathProposalToAddMember();
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_CREATED, _subject, _proposalData);

    (, bytes16 _creator, IDAOSpace.ProposalParameters memory _parameters,, IDAOSpace.Action[] memory _actions) =
      daoSpaceProxy.getLatestProposalInformation(_proposalId);

    // it increments the proposal version
    assertEq(daoSpaceProxy.latestProposalVersion(_proposalId), 1);

    // it sets the proposal creator to _fromSpaceId
    assertEq(_creator, _initialEditorASpaceId);

    // it sets the proposal start date to block.timestamp
    assertEq(_parameters.startDate, vm.getBlockTimestamp());

    // it sets the proposal last date to block.timestamp plus votingSettings.duration
    assertEq(_parameters.lastDate, vm.getBlockTimestamp() + _votingSettings.duration);

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
    assertEq(_actions[0].data, abi.encodeCall(IDAOSpace.addMember, (_getSpaceId(_randomCaller))));
  }

  /// WRITE - PROPOSAL_VOTED ///

  modifier when_actionEqualsPROPOSAL_VOTED() {
    _;
  }

  function test_Write_WhenTheProposalStartDateEqualsZero(
    bytes32 _subject,
    uint256 _voteOption
  ) external whenCalledBySpaceRegistry when_actionEqualsPROPOSAL_VOTED {
    _voteOption = bound(_voteOption, 1, 3);

    // it reverts with CanNotVote
    vm.expectRevert(IDAOSpace.CanNotVote.selector);

    bytes memory _voteData = _createVoteForProposal(IDAOSpace.VoteOption(_voteOption));
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, _voteData);
  }

  function test_Write_WhenTheBlockTimestampIsGreaterThanTheLastDate(
    bytes32 _subject,
    uint256 _voteOption
  ) external whenCalledBySpaceRegistry when_actionEqualsPROPOSAL_VOTED {
    _voteOption = bound(_voteOption, 1, 3);

    // proposal set up
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      0,
      _initialEditorASpaceId,
      block.timestamp,
      block.timestamp - 1,
      IDAOSpace.VotingMode.Slow,
      1,
      1,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    // it reverts with CanNotVote
    vm.expectRevert(IDAOSpace.CanNotVote.selector);

    bytes memory _voteData = _createVoteForProposal(IDAOSpace.VoteOption(_voteOption));
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, _voteData);
  }

  function test_Write_WhenTheProposalHasBeenExecuted(
    bytes32 _subject,
    uint256 _voteOption
  ) external whenCalledBySpaceRegistry when_actionEqualsPROPOSAL_VOTED {
    _voteOption = bound(_voteOption, 1, 3);

    // proposal set up
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      true,
      0,
      _initialEditorASpaceId,
      block.timestamp,
      block.timestamp + 1,
      IDAOSpace.VotingMode.Slow,
      1,
      1,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    // it reverts with CanNotVote
    vm.expectRevert(IDAOSpace.CanNotVote.selector);

    bytes memory _voteData = _createVoteForProposal(IDAOSpace.VoteOption(_voteOption));
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, _voteData);
  }

  function test_Write_WhenTheVoteOptionEqualsNone(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_VOTED
  {
    // proposal set up
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      0,
      _initialEditorASpaceId,
      block.timestamp,
      block.timestamp + 1,
      IDAOSpace.VotingMode.Slow,
      1,
      1,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    // it reverts with CanNotVote
    vm.expectRevert(IDAOSpace.CanNotVote.selector);

    bytes memory _voteData = _createVoteForProposal(IDAOSpace.VoteOption.None);
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, _voteData);
  }

  function test_Write_WhenThe_fromSpaceIdIsNotAnEditor(
    bytes32 _subject,
    uint256 _voteOption
  ) external whenCalledBySpaceRegistry when_actionEqualsPROPOSAL_VOTED {
    _voteOption = bound(_voteOption, 1, 3);

    // proposal set up
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      0,
      _getSpaceId(_randomCaller),
      block.timestamp,
      block.timestamp + 1,
      IDAOSpace.VotingMode.Slow,
      1,
      1,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    _mockAddressToSpaceId(_spaceRegistry, _spaceRegistry, _getSpaceId(_spaceRegistry));

    // it reverts with CanNotVote
    vm.expectRevert(IDAOSpace.CanNotVote.selector);

    bytes memory _voteData = _createVoteForProposal(IDAOSpace.VoteOption(_voteOption));
    daoSpaceProxy.write(_getSpaceId(_randomCaller), ActionsConstants.PROPOSAL_VOTED, _subject, _voteData);
  }

  modifier when_voteParamsAreValid() {
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
      0,
      _initialEditorASpaceId,
      block.timestamp,
      block.timestamp + 1,
      IDAOSpace.VotingMode(_votingMode),
      1,
      1,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    // vote
    bytes memory _voteData = _createVoteForProposal(IDAOSpace.VoteOption(_voteOption));
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, _voteData);

    // it stores the current _fromSpaceId vote
    IDAOSpace.VoteOption _storedVoteOption = daoSpaceProxy.getLatestProposalVote(_proposalId, _initialEditorASpaceId);
    assertEq(uint256(_storedVoteOption), _voteOption);
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
      0,
      _initialEditorASpaceId,
      block.timestamp,
      block.timestamp + 1,
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
    bytes memory _voteData = _createVoteForProposal(IDAOSpace.VoteOption.No);
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, _voteData);

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
      0,
      _initialEditorASpaceId,
      block.timestamp,
      block.timestamp + 1,
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
    bytes memory _voteData = _createVoteForProposal(IDAOSpace.VoteOption.Yes);
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, _voteData);

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
      0,
      _initialEditorASpaceId,
      block.timestamp,
      block.timestamp + 1,
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
    bytes memory _voteData = _createVoteForProposal(IDAOSpace.VoteOption.Yes);
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, _voteData);

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
      0,
      _initialEditorASpaceId,
      block.timestamp,
      block.timestamp + 1,
      IDAOSpace.VotingMode(_votingMode),
      2,
      1,
      1,
      2,
      new IDAOSpace.Action[](0)
    );

    // vote yes
    bytes memory _voteData = _createVoteForProposal(IDAOSpace.VoteOption.Yes);
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, _voteData);

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
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addMember, (_getSpaceId(_randomCaller)))
    });
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      0,
      _initialEditorASpaceId,
      block.timestamp,
      block.timestamp + 1,
      IDAOSpace.VotingMode(_votingMode),
      1,
      1,
      1,
      1,
      _actions
    );

    assertFalse(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _getSpaceId(_randomCaller)));

    // it calls enter on the spaceRegistry with the MEMBER_ADDED action
    bytes16 _daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));
    _mockEnter(
      _spaceRegistry,
      _daoSpaceProxySpaceId,
      _daoSpaceProxySpaceId,
      ActionsConstants.MEMBER_ADDED,
      bytes32(_getSpaceId(_randomCaller)),
      ''
    );

    // vote yes
    bytes memory _voteData = _createVoteForProposal(IDAOSpace.VoteOption.Yes);
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, _voteData);

    // it increases the proposal yes vote tally by one
    (bool _executed,,, IDAOSpace.Tally memory _tally,) = daoSpaceProxy.getLatestProposalInformation(_proposalId);
    assertEq(_tally.yes, 1);
    assertEq(_tally.no, 0);
    assertEq(_tally.abstain, 0);

    // it sets the proposal executed to true
    assertTrue(_executed);

    // it loops over the stored proposal actions and performs the external calls
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _getSpaceId(_randomCaller)));
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
      0,
      _initialEditorASpaceId,
      block.timestamp,
      block.timestamp + 1,
      IDAOSpace.VotingMode.Slow,
      1,
      1,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    // vote no
    bytes memory _voteData = _createVoteForProposal(IDAOSpace.VoteOption.No);
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, _voteData);

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
  {
    // proposal set up
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      0,
      _initialEditorASpaceId,
      block.timestamp,
      block.timestamp + 1e5,
      IDAOSpace.VotingMode.Fast,
      1,
      1,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    (, bytes16 _creator, IDAOSpace.ProposalParameters memory _parameters,,) =
      daoSpaceProxy.getLatestProposalInformation(_proposalId);
    assertEq(uint256(_parameters.votingMode), uint256(IDAOSpace.VotingMode.Fast));
    assertEq(_parameters.quorum, 1);
    assertEq(_parameters.partialPercentageSupportThreshold, 1);
    assertEq(_parameters.universalPercentageSupportThreshold, 1);
    assertEq(_parameters.flatSupportThreshold, 1);
    assertEq(_parameters.startDate, block.timestamp);
    assertEq(_parameters.lastDate, block.timestamp + 1e5);

    // warp forwards to ensure start date is reset
    vm.warp(block.timestamp + 100);

    IDAOSpace.VotingSettings memory _votingSettings = daoSpaceProxy.votingSettings();

    // it calls enter on the spaceRegistry with the PROPOSAL_SETTINGS_SELECTED action
    bytes16 _daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));
    _mockEnter(
      _spaceRegistry,
      _daoSpaceProxySpaceId,
      _daoSpaceProxySpaceId,
      ActionsConstants.PROPOSAL_SETTINGS_SELECTED,
      bytes32(_proposalId),
      abi.encode(
        block.timestamp,
        block.timestamp + _votingSettings.duration,
        IDAOSpace.VotingMode.Slow,
        _votingSettings.quorum,
        _votingSettings.partialPercentageSupportThreshold,
        _votingSettings.universalPercentageSupportThreshold,
        _votingSettings.flatSupportThreshold
      )
    );

    // vote no
    bytes memory _voteData = _createVoteForProposal(IDAOSpace.VoteOption.No);
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, _voteData);

    (, _creator, _parameters,,) = daoSpaceProxy.getLatestProposalInformation(_proposalId);

    // it updates the proposal voting mode to the slow path
    assertEq(uint256(_parameters.votingMode), uint256(IDAOSpace.VotingMode.Slow));

    // it updates the proposal quorum to votingSettings.quorum
    assertEq(_parameters.quorum, _votingSettings.quorum);

    // it updates the proposal partial percentage support threshold to votingSettings.partialPercentageSupportThreshold
    assertEq(
      _parameters.partialPercentageSupportThreshold, daoSpaceProxy.votingSettings().partialPercentageSupportThreshold
    );

    // it updates the proposal universal percentage support threshold to votingSettings.universalPercentageSupportThreshold
    assertEq(
      _parameters.universalPercentageSupportThreshold,
      daoSpaceProxy.votingSettings().universalPercentageSupportThreshold
    );

    // it updates the proposal flat support threshold to votingSettings.flatSupportThreshold
    assertEq(_parameters.flatSupportThreshold, daoSpaceProxy.votingSettings().flatSupportThreshold);

    // it updates the proposal start date to block.timestamp
    assertEq(_parameters.startDate, block.timestamp);

    // it updates the proposal last date to block.timestamp plus votingSettings.duration
    assertEq(_parameters.lastDate, block.timestamp + daoSpaceProxy.votingSettings().duration);
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
      0,
      _initialEditorASpaceId,
      block.timestamp,
      block.timestamp + 1,
      IDAOSpace.VotingMode(_votingMode),
      1,
      1,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    // vote abstain
    bytes memory _voteData = _createVoteForProposal(IDAOSpace.VoteOption.Abstain);
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, _voteData);

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

  function test_Write_WhenTheProposalCreatorIsNotThe_fromSpaceId(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_UPDATED
  {
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      0,
      _initialEditorASpaceId,
      block.timestamp,
      block.timestamp + 1,
      IDAOSpace.VotingMode.Slow,
      1,
      1,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    // it reverts with InvalidCaller
    vm.expectRevert(IDAOSpace.InvalidCaller.selector);

    bytes memory _proposalData = _createFastPathProposalToAddMember();
    daoSpaceProxy.write(_getSpaceId(_randomCaller), ActionsConstants.PROPOSAL_UPDATED, _subject, _proposalData);
  }

  function test_Write_WhenTheProposalHasAlreadyBeenExecuted(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_UPDATED
  {
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      true,
      0,
      _initialEditorASpaceId,
      block.timestamp,
      block.timestamp + 1,
      IDAOSpace.VotingMode.Slow,
      1,
      1,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    // it reverts with InvalidProposalId
    vm.expectRevert(IDAOSpace.InvalidProposalId.selector);

    bytes memory _proposalData = _createFastPathProposalToAddMember();
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_UPDATED, _subject, _proposalData);
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
      0,
      _initialEditorASpaceId,
      block.timestamp,
      block.timestamp + 1,
      IDAOSpace.VotingMode.Slow,
      1,
      1,
      1,
      1,
      new IDAOSpace.Action[](0)
    );
    daoSpaceProxy.workaround_setFormerVote(_proposalId, _initialEditorASpaceId, IDAOSpace.VoteOption(_voteOption));
    daoSpaceProxy.workaround_setTally(_proposalId, 1, 1, 1);

    IDAOSpace.VotingSettings memory _votingSettings = daoSpaceProxy.votingSettings();

    // it calls enter on the spaceRegistry with the PROPOSAL_SETTINGS_SELECTED action
    bytes16 _daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));
    _mockEnter(
      _spaceRegistry,
      _daoSpaceProxySpaceId,
      _daoSpaceProxySpaceId,
      ActionsConstants.PROPOSAL_SETTINGS_SELECTED,
      bytes32(_proposalId),
      abi.encode(
        block.timestamp,
        block.timestamp + _votingSettings.duration,
        IDAOSpace.VotingMode.Fast,
        _votingSettings.quorum,
        _votingSettings.partialPercentageSupportThreshold,
        _votingSettings.universalPercentageSupportThreshold,
        _votingSettings.flatSupportThreshold
      )
    );

    bytes memory _proposalData = _createFastPathProposalToAddMember();
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_UPDATED, _subject, _proposalData);

    (,,, IDAOSpace.Tally memory _tally, IDAOSpace.Action[] memory _actions) =
      daoSpaceProxy.getLatestProposalInformation(_proposalId);
    IDAOSpace.VoteOption _vote = daoSpaceProxy.getLatestProposalVote(_proposalId, _initialEditorASpaceId);

    // it resets the voting state
    assertEq(_tally.abstain, 0);
    assertEq(_tally.yes, 0);
    assertEq(_tally.no, 0);
    assertEq(uint256(_vote), 0);

    // it updates the proposal with a new version
    assertEq(daoSpaceProxy.latestProposalVersion(_proposalId), 1);
    assertEq(_actions.length, 1);

    (,,, _tally, _actions) = daoSpaceProxy.getProposalInformation(_proposalId, 0);
    _vote = daoSpaceProxy.getProposalVote(_proposalId, 0, _initialEditorASpaceId);

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

  function test_Write_WhenTheProposalHasAlreadyBeenExecuted_When_actionEqualsPROPOSAL_EXECUTED(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_EXECUTED
  {
    // set up proposal
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      true,
      0,
      _initialEditorASpaceId,
      block.timestamp,
      block.timestamp + 1,
      IDAOSpace.VotingMode.Fast,
      1,
      1,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    // it reverts with CanNotExecute
    vm.expectRevert(IDAOSpace.CanNotExecute.selector);

    bytes memory _executeData = abi.encode(_proposalId);
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_EXECUTED, _subject, _executeData);
  }

  function test_Write_WhenTheProposalStartDateEqualsZero_When_actionEqualsPROPOSAL_EXECUTED(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_EXECUTED
  {
    // it reverts with CanNotExecute
    vm.expectRevert(IDAOSpace.CanNotExecute.selector);

    bytes memory _executeData = abi.encode(_proposalId);
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_EXECUTED, _subject, _executeData);
  }

  function test_Write_WhenTheSupportThresholdHasNotBeenReached(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_EXECUTED
  {
    // set up proposal
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      0,
      _initialEditorASpaceId,
      block.timestamp,
      block.timestamp + 1,
      IDAOSpace.VotingMode.Slow,
      1,
      1,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    vm.warp(block.timestamp + 2);

    // it reverts with CanNotExecute
    vm.expectRevert(IDAOSpace.CanNotExecute.selector);

    bytes memory _executeData = abi.encode(_proposalId);
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_EXECUTED, _subject, _executeData);
  }

  modifier whenTheProposalCanBeExecuted() {
    _;
  }

  function test_Write_WhenTheProposalCanBeExecuted_WhenTheProposalCanBeExecuted(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_EXECUTED
    whenTheProposalCanBeExecuted
  {
    // proposal set up to add randomCaller as an editor and member
    IDAOSpace.Action[] memory _actions = new IDAOSpace.Action[](2);
    _actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addEditor, (_getSpaceId(_randomCaller)))
    });
    _actions[1] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addMember, (_getSpaceId(_randomCaller)))
    });
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      0,
      _initialEditorASpaceId,
      block.timestamp,
      block.timestamp + 1,
      IDAOSpace.VotingMode.Slow,
      1,
      1,
      1,
      1,
      _actions
    );

    // set vote to yes
    daoSpaceProxy.workaround_setFormerVote(_proposalId, _initialEditorASpaceId, IDAOSpace.VoteOption.Yes);

    // warp to after last date
    vm.warp(block.timestamp + 2);

    assertFalse(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _getSpaceId(_randomCaller)));
    assertFalse(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _getSpaceId(_randomCaller)));

    // it calls enter on the spaceRegistry with the EDITOR_ADDED action
    bytes16 _daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));
    _mockEnter(
      _spaceRegistry,
      _daoSpaceProxySpaceId,
      _daoSpaceProxySpaceId,
      ActionsConstants.EDITOR_ADDED,
      bytes32(_getSpaceId(_randomCaller)),
      ''
    );

    // it calls enter on the spaceRegistry with the MEMBER_ADDED action
    _mockEnter(
      _spaceRegistry,
      _daoSpaceProxySpaceId,
      _daoSpaceProxySpaceId,
      ActionsConstants.MEMBER_ADDED,
      bytes32(_getSpaceId(_randomCaller)),
      ''
    );

    bytes memory _executeData = abi.encode(_proposalId);
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_EXECUTED, _subject, _executeData);

    (bool _executed,,,,) = daoSpaceProxy.getLatestProposalInformation(_proposalId);

    // it sets the proposal executed to true
    assertTrue(_executed);

    // it loops over the stored proposal actions and performs the external calls
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _getSpaceId(_randomCaller)));
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _getSpaceId(_randomCaller)));
  }

  function test_Write_WhenAnExternalCallFails(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_EXECUTED
    whenTheProposalCanBeExecuted
  {
    // proposal set up to with a deliberately faulty call
    IDAOSpace.Action[] memory _actions = new IDAOSpace.Action[](1);
    _actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(ISpaceRegistry.registerSpaceId, (bytes32(0), ''))
    });
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      0,
      _initialEditorASpaceId,
      block.timestamp,
      block.timestamp + 1,
      IDAOSpace.VotingMode.Slow,
      0,
      1,
      1,
      1,
      _actions
    );

    // set vote to yes
    daoSpaceProxy.workaround_setFormerVote(_proposalId, _initialEditorASpaceId, IDAOSpace.VoteOption.Yes);

    // warp to after last date
    vm.warp(block.timestamp + 2);

    // it reverts with ActionReverted
    vm.expectRevert(IDAOSpace.ActionReverted.selector);

    bytes memory _executeData = abi.encode(_proposalId);
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.PROPOSAL_EXECUTED, _subject, _executeData);
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
    bytes16 _daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));
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
        defaultFastPathAccessForMembers: _votingSettings.defaultFastPathAccessForMembers
      })
    );

    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _initialEditorASpaceId));

    // it calls enter on the spaceRegistry with the EDITOR_REMOVED action
    bytes16 _daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));
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
    bytes16 _randomCallerSpaceId = _getSpaceId(_randomCaller);
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      0,
      _randomCallerSpaceId,
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

    daoSpaceProxy.write(
      _randomCallerSpaceId,
      ActionsConstants.MEMBERSHIP_REQUESTED,
      bytes32(0),
      abi.encode(_proposalId, _randomCallerSpaceId)
    );
  }

  function test_Write_When_fromSpaceIdIsRestricted_When_actionEqualsMEMBERSHIP_REQUESTED()
    external
    whenCalledBySpaceRegistry
    when_actionEqualsMEMBERSHIP_REQUESTED
  {
    bytes16 _randomCallerSpaceId = _getSpaceId(_randomCaller);
    daoSpaceProxy.workaround_grantRole(daoSpaceProxy.FAST_PATH_RESTRICTED(), _randomCallerSpaceId);

    // it reverts with FastPathRestricted
    vm.expectRevert(IDAOSpace.FastPathRestricted.selector);

    daoSpaceProxy.write(
      _randomCallerSpaceId,
      ActionsConstants.MEMBERSHIP_REQUESTED,
      bytes32(0),
      abi.encode(_proposalId, _randomCallerSpaceId)
    );
  }

  function test_Write_WhenTheRequestCanBeMade()
    external
    whenCalledBySpaceRegistry
    when_actionEqualsMEMBERSHIP_REQUESTED
  {
    // get voting settings
    IDAOSpace.VotingSettings memory _votingSettings = daoSpaceProxy.votingSettings();

    bytes16 _randomCallerSpaceId = _getSpaceId(_randomCaller);

    // it calls enter on the spaceRegistry with the PROPOSAL_CREATED action
    IDAOSpace.Action[] memory _actions = new IDAOSpace.Action[](1);
    _actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addMember, (_randomCallerSpaceId))
    });

    bytes16 _daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));

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
        vm.getBlockTimestamp(),
        vm.getBlockTimestamp() + _votingSettings.duration,
        IDAOSpace.VotingMode.Fast,
        _votingSettings.quorum,
        _votingSettings.partialPercentageSupportThreshold,
        _votingSettings.universalPercentageSupportThreshold,
        _votingSettings.flatSupportThreshold
      )
    );

    daoSpaceProxy.write(
      _randomCallerSpaceId,
      ActionsConstants.MEMBERSHIP_REQUESTED,
      bytes32(0),
      abi.encode(_proposalId, _randomCallerSpaceId)
    );

    (, bytes16 _creator, IDAOSpace.ProposalParameters memory _parameters,, IDAOSpace.Action[] memory _actionsA) =
      daoSpaceProxy.getLatestProposalInformation(_proposalId);

    // it increments the proposal version
    assertEq(daoSpaceProxy.latestProposalVersion(_proposalId), 1);

    // it sets the proposal creator to _fromSpaceId
    assertEq(_creator, _randomCallerSpaceId);

    // it sets the proposal start date to block.timestamp
    assertEq(_parameters.startDate, vm.getBlockTimestamp());

    // it sets the proposal last date to block.timestamp plus votingSettings.duration
    assertEq(_parameters.lastDate, vm.getBlockTimestamp() + _votingSettings.duration);

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
    bytes memory _flagData = abi.encode(_getSpaceId(_randomCaller));

    // it reverts with InvalidFromSpace
    vm.expectRevert(IDAOSpace.InvalidFromSpace.selector);
    daoSpaceProxy.write(_initialMemberASpaceId, ActionsConstants.SPACE_FAST_PATH_RESTRICTED, _subject, _flagData);
  }

  function test_Write_When_restrictSpaceParamsAreValid(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsSPACE_FAST_PATH_RESTRICTED
  {
    assertFalse(daoSpaceProxy.hasRole(daoSpaceProxy.FAST_PATH_RESTRICTED(), _getSpaceId(_randomCaller)));

    // initial editor flags themselves
    bytes memory _flagData = abi.encode(_getSpaceId(_randomCaller));
    daoSpaceProxy.write(_initialEditorASpaceId, ActionsConstants.SPACE_FAST_PATH_RESTRICTED, _subject, _flagData);

    // it flags the editor from using the fast path
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.FAST_PATH_RESTRICTED(), _getSpaceId(_randomCaller)));
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
    daoSpaceProxy.write(_getSpaceId(_randomCaller), _action, _subject, _data);
  }

  function test_Write_WhenCalledByNon_spaceRegistry(
    address _caller,
    bytes32 _action,
    bytes32 _subject,
    bytes memory _data
  ) external {
    vm.assume(_caller != _spaceRegistry);

    _mockAddressToSpaceId(_spaceRegistry, _caller, _getSpaceId(_caller));

    // it reverts with InvalidCaller
    vm.expectRevert(IDAOSpace.InvalidCaller.selector);
    vm.prank(_caller);
    daoSpaceProxy.write(_getSpaceId(_randomCaller), _action, _subject, _data);
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

    _mockAddressToSpaceId(_spaceRegistry, address(daoSpaceProxy), _getSpaceId(address(daoSpaceProxy)));

    // it calls enter on the spaceRegistry with the EDITOR_ADDED action
    bytes16 _daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));
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

    // mock hasRole call
    _mockAddressToSpaceId(_spaceRegistry, _caller, _getSpaceId(_caller));

    vm.prank(_caller);

    // it reverts with InvalidCaller
    vm.expectRevert(IDAOSpace.InvalidCaller.selector);
    daoSpaceProxy.addEditor(_newEditorSpaceId);
  }

  /// REMOVE EDITOR ///

  function test_RemoveEditor_When_oldEditorIsNotAnEditor(bytes16 _oldEditorSpaceId) external whenCalledByDAO {
    vm.assume(_oldEditorSpaceId != _initialEditorASpaceId);
    vm.assume(_oldEditorSpaceId != _initialEditorBSpaceId);

    _mockAddressToSpaceId(_spaceRegistry, address(daoSpaceProxy), _getSpaceId(address(daoSpaceProxy)));

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
        defaultFastPathAccessForMembers: _votingSettings.defaultFastPathAccessForMembers
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
        defaultFastPathAccessForMembers: _votingSettings.defaultFastPathAccessForMembers
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
        defaultFastPathAccessForMembers: _votingSettings.defaultFastPathAccessForMembers
      })
    );

    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _initialEditorASpaceId));

    uint256 _totalEditorsBefore = daoSpaceProxy.totalEditors();
    assertEq(_totalEditorsBefore, 2);

    // it calls enter on the spaceRegistry with the EDITOR_REMOVED action
    bytes16 _daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));
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

    _mockAddressToSpaceId(_spaceRegistry, _caller, _getSpaceId(_caller));

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
    bytes16 _daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));
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

  modifier whenDefaultFastPathAccessForMembersIsFalse() {
    assertFalse(daoSpaceProxy.votingSettings().defaultFastPathAccessForMembers);
    _;
  }

  function test_AddMember_When_newMemberIsNotAnEditor(bytes16 _newMemberSpaceId)
    external
    whenCalledByDAO
    when_newMemberIsNotAMember
    whenDefaultFastPathAccessForMembersIsFalse
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
    whenDefaultFastPathAccessForMembersIsFalse
  {
    vm.assume(_newMemberSpaceId != _initialMemberASpaceId);
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

    _mockAddressToSpaceId(_spaceRegistry, _caller, _getSpaceId(_caller));

    // it reverts with InvalidCaller
    vm.expectRevert(IDAOSpace.InvalidCaller.selector);
    daoSpaceProxy.addMember(_newMemberSpaceId);
  }

  /// REMVOE MEMBER ///

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
    bytes16 _daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));
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

    _mockAddressToSpaceId(_spaceRegistry, _caller, _getSpaceId(_caller));

    // it reverts with InvalidCaller
    vm.expectRevert(IDAOSpace.InvalidCaller.selector);
    daoSpaceProxy.removeMember(_oldMemberSpaceId);
  }

  /// UNRESTRICT SPACE ///

  function test_UnrestrictSpace_WhenCalledByDAO() external whenCalledByDAO {
    daoSpaceProxy.workaround_grantRole(daoSpaceProxy.FAST_PATH_RESTRICTED(), _getSpaceId(_randomCaller));

    // it fetches the daoSpaceId from the spaceRegistry
    bytes16 _daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));
    _mockAddressToSpaceId(_spaceRegistry, address(daoSpaceProxy), _daoSpaceProxySpaceId);

    // it calls enter on the spaceRegistry with the SPACE_FAST_PATH_UNRESTRICTED action
    _mockEnter(
      _spaceRegistry,
      _daoSpaceProxySpaceId,
      _daoSpaceProxySpaceId,
      ActionsConstants.SPACE_FAST_PATH_UNRESTRICTED,
      bytes32(_getSpaceId(_randomCaller)),
      ''
    );
    daoSpaceProxy.unrestrictSpace(_getSpaceId(_randomCaller));

    // it revokes the FAST_PATH_RESTRICTED role from _space
    assertFalse(daoSpaceProxy.hasRole(daoSpaceProxy.FAST_PATH_RESTRICTED(), _getSpaceId(_randomCaller)));
  }

  function test_UnrestrictSpace_WhenCalledByNon_DAO(address _caller) external {
    vm.assume(_caller != address(daoSpaceProxy));
    vm.prank(_caller);

    _mockAddressToSpaceId(_spaceRegistry, _caller, _getSpaceId(_caller));

    // it reverts with InvalidCaller
    vm.expectRevert(IDAOSpace.InvalidCaller.selector);
    daoSpaceProxy.unrestrictSpace(_getSpaceId(_randomCaller));
  }

  /// PING ///

  function test_Ping_WhenCalledByDAO(bytes32 _action, bytes32 _subject, bytes calldata _data) external whenCalledByDAO {
    // it fetches the daoSpaceId from the spaceRegistry
    bytes16 _daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));
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

    _mockAddressToSpaceId(_spaceRegistry, _caller, _getSpaceId(_caller));

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

    _mockAddressToSpaceId(_spaceRegistry, _caller, _getSpaceId(_caller));

    // it reverts with InvalidCaller
    vm.expectRevert(IDAOSpace.InvalidCaller.selector);
    daoSpaceProxy.updateVotingSettings(__votingSettings);
  }

  /// FETCH ///

  function test_Fetch_When_actionEqualsPROPOSAL_CREATED(bytes32 _subjectInput, uint256 _votingMode) external view {
    _votingMode = bound(_votingMode, 0, 1);
    bytes memory _data = abi.encode(_proposalId, IDAOSpace.VotingMode(_votingMode), new IDAOSpace.Action[](0));

    // it returns bytes32(_proposalId)
    assertEq(daoSpaceProxy.fetch(ActionsConstants.PROPOSAL_CREATED, _subjectInput, _data), bytes32(_proposalId));
  }

  function test_Fetch_When_actionEqualsPROPOSAL_VOTED(bytes32 _subjectInput, uint256 _voteOption) external view {
    _voteOption = bound(_voteOption, 0, 3);
    bytes memory _data = abi.encode(_proposalId, IDAOSpace.VoteOption(_voteOption));

    // it returns bytes32(_proposalId)
    assertEq(daoSpaceProxy.fetch(ActionsConstants.PROPOSAL_VOTED, _subjectInput, _data), bytes32(_proposalId));
  }

  function test_Fetch_When_actionEqualsPROPOSAL_UPDATED(bytes32 _subjectInput, uint256 _votingMode) external view {
    _votingMode = bound(_votingMode, 0, 1);
    bytes memory _data = abi.encode(_proposalId, IDAOSpace.VotingMode(_votingMode), new IDAOSpace.Action[](0));

    // it returns bytes32(_proposalId)
    assertEq(daoSpaceProxy.fetch(ActionsConstants.PROPOSAL_UPDATED, _subjectInput, _data), bytes32(_proposalId));
  }

  function test_Fetch_When_actionEqualsPROPOSAL_EXECUTED(bytes32 _subjectInput) external view {
    bytes memory _data = abi.encode(_proposalId);

    // it returns bytes32(_proposalId)
    assertEq(daoSpaceProxy.fetch(ActionsConstants.PROPOSAL_EXECUTED, _subjectInput, _data), bytes32(_proposalId));
  }

  function test_Fetch_When_actionEqualsSPACE_LEFT(bytes32 _subjectInput, bytes32 _role) external view {
    bytes memory _data = abi.encode(_role);

    // it returns role
    assertEq(daoSpaceProxy.fetch(ActionsConstants.SPACE_LEFT, _subjectInput, _data), bytes32(_role));
  }

  function test_Fetch_When_actionEqualsMEMBERSHIP_REQUESTED(
    bytes32 _subjectInput,
    bytes16 _newMemberSpaceId
  ) external view {
    bytes memory _data = abi.encode(_proposalId, _newMemberSpaceId);

    // it returns bytes32(_proposalId)
    assertEq(daoSpaceProxy.fetch(ActionsConstants.MEMBERSHIP_REQUESTED, _subjectInput, _data), bytes32(_proposalId));
  }

  function test_Fetch_When_actionEqualsSPACE_FAST_PATH_RESTRICTED(
    bytes32 _subjectInput,
    bytes16 _spaceId
  ) external view {
    bytes memory _data = abi.encode(_spaceId);

    // it returns bytes32(_spaceId)
    assertEq(daoSpaceProxy.fetch(ActionsConstants.SPACE_FAST_PATH_RESTRICTED, _subjectInput, _data), bytes32(_spaceId));
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
      0,
      _initialEditorASpaceId,
      block.timestamp,
      block.timestamp + daoSpaceProxy.votingSettings().duration,
      IDAOSpace.VotingMode.Slow,
      _quorum,
      daoSpaceProxy.votingSettings().partialPercentageSupportThreshold,
      daoSpaceProxy.votingSettings().universalPercentageSupportThreshold,
      daoSpaceProxy.votingSettings().flatSupportThreshold,
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
      0,
      _initialEditorASpaceId,
      block.timestamp,
      block.timestamp + daoSpaceProxy.votingSettings().duration,
      IDAOSpace.VotingMode.Slow,
      _quorum,
      daoSpaceProxy.RATIO_BASE(),
      _universalPercentageSupportThreshold,
      daoSpaceProxy.votingSettings().flatSupportThreshold,
      new IDAOSpace.Action[](0)
    );
    daoSpaceProxy.workaround_setTally(_proposalId, _yes, _no, _abstain);
    daoSpaceProxy.workaround_setTotalEditors(_yes + _no + _abstain + _none);

    // it returns true
    assertTrue(daoSpaceProxy.isSupportThresholdReached(_proposalId));
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
      0,
      _initialEditorASpaceId,
      block.timestamp,
      block.timestamp + daoSpaceProxy.votingSettings().duration,
      IDAOSpace.VotingMode.Slow,
      _quorum,
      daoSpaceProxy.votingSettings().partialPercentageSupportThreshold,
      _universalPercentageSupportThreshold,
      daoSpaceProxy.votingSettings().flatSupportThreshold,
      new IDAOSpace.Action[](0)
    );
    daoSpaceProxy.workaround_setTally(_proposalId, _yes, _no, _abstain);
    daoSpaceProxy.workaround_setTotalEditors(_yes + _no + _abstain + _none);
    vm.warp(block.timestamp + daoSpaceProxy.votingSettings().duration);

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
      0,
      _initialEditorASpaceId,
      block.timestamp,
      block.timestamp + daoSpaceProxy.votingSettings().duration,
      IDAOSpace.VotingMode.Slow,
      _quorum,
      _partialPercentageSupportThreshold,
      _universalPercentageSupportThreshold,
      daoSpaceProxy.votingSettings().flatSupportThreshold,
      new IDAOSpace.Action[](0)
    );
    daoSpaceProxy.workaround_setTally(_proposalId, _yes, _no, _abstain);
    daoSpaceProxy.workaround_setTotalEditors(_yes + _no + _abstain + _none);
    vm.warp(block.timestamp + daoSpaceProxy.votingSettings().duration + 1);

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
      0,
      _initialEditorASpaceId,
      block.timestamp,
      block.timestamp + daoSpaceProxy.votingSettings().duration,
      IDAOSpace.VotingMode.Slow,
      _quorum,
      _partialPercentageSupportThreshold,
      _universalPercentageSupportThreshold,
      daoSpaceProxy.votingSettings().flatSupportThreshold,
      new IDAOSpace.Action[](0)
    );
    daoSpaceProxy.workaround_setTally(_proposalId, _yes, _no, _abstain);
    daoSpaceProxy.workaround_setTotalEditors(_yes + _no + _abstain + _none);
    vm.warp(block.timestamp + daoSpaceProxy.votingSettings().duration + 1);

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
      0,
      _initialEditorASpaceId,
      block.timestamp,
      block.timestamp + daoSpaceProxy.votingSettings().duration,
      IDAOSpace.VotingMode.Fast,
      daoSpaceProxy.votingSettings().quorum,
      daoSpaceProxy.votingSettings().partialPercentageSupportThreshold,
      daoSpaceProxy.votingSettings().universalPercentageSupportThreshold,
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
      0,
      _initialEditorASpaceId,
      block.timestamp,
      block.timestamp + daoSpaceProxy.votingSettings().duration,
      IDAOSpace.VotingMode.Fast,
      daoSpaceProxy.votingSettings().quorum,
      daoSpaceProxy.votingSettings().partialPercentageSupportThreshold,
      daoSpaceProxy.votingSettings().universalPercentageSupportThreshold,
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

  function _createSlowPathProposalToAddEditor() internal view returns (bytes memory _proposalData) {
    IDAOSpace.VotingMode _votingMode = IDAOSpace.VotingMode.Slow;
    IDAOSpace.Action[] memory _actions = new IDAOSpace.Action[](1);
    bytes16 _randomCallerSpaceId = _getSpaceId(_randomCaller);
    _actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addEditor, (_randomCallerSpaceId))
    });
    return abi.encode(_proposalId, _votingMode, _actions);
  }

  /// @dev valid proposal because action is fast path valid
  function _createFastPathProposalToAddMember() internal view returns (bytes memory _proposalData) {
    IDAOSpace.VotingMode _votingMode = IDAOSpace.VotingMode.Fast;
    IDAOSpace.Action[] memory _actions = new IDAOSpace.Action[](1);
    bytes16 _randomCallerSpaceId = _getSpaceId(_randomCaller);
    _actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addMember, (_randomCallerSpaceId))
    });
    return abi.encode(_proposalId, _votingMode, _actions);
  }

  /// @dev invalid proposal because it attempts to perform two actions
  function _createFastPathProposalToAddTwoMembers() internal view returns (bytes memory _proposalData) {
    IDAOSpace.VotingMode _votingMode = IDAOSpace.VotingMode.Fast;
    IDAOSpace.Action[] memory _actions = new IDAOSpace.Action[](2);
    bytes16 _randomCallerSpaceId = _getSpaceId(_randomCaller);
    _actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addMember, (_randomCallerSpaceId))
    });
    _actions[1] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addMember, (_randomCallerSpaceId))
    });
    return abi.encode(_proposalId, _votingMode, _actions);
  }

  /// @dev invalid proposal because the action is not fast path valid
  function _createFastPathProposalToAddEditor() internal view returns (bytes memory _proposalData) {
    IDAOSpace.VotingMode _votingMode = IDAOSpace.VotingMode.Fast;
    IDAOSpace.Action[] memory _actions = new IDAOSpace.Action[](1);
    _actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addEditor, (_getSpaceId(_randomCaller)))
    });
    return abi.encode(_proposalId, _votingMode, _actions);
  }

  /// @dev invalid target because the action attempts to write in another contract
  function _createFastPathProposalToAddMemberOnAnotherContract() internal view returns (bytes memory _proposalData) {
    IDAOSpace.VotingMode _votingMode = IDAOSpace.VotingMode.Fast;
    IDAOSpace.Action[] memory _actions = new IDAOSpace.Action[](1);
    _actions[0] = IDAOSpace.Action({
      to: address(this), value: 0, data: abi.encodeCall(IDAOSpace.addMember, (_getSpaceId(_randomCaller)))
    });
    return abi.encode(_proposalId, _votingMode, _actions);
  }

  /// @dev invalid funds transfer because the action entails a funds transfer
  function _createFastPathProposalToAddMemberAndMoveValue() internal view returns (bytes memory _proposalData) {
    IDAOSpace.VotingMode _votingMode = IDAOSpace.VotingMode.Fast;
    IDAOSpace.Action[] memory _actions = new IDAOSpace.Action[](1);
    _actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 1, data: abi.encodeCall(IDAOSpace.addMember, (_getSpaceId(_randomCaller)))
    });
    return abi.encode(_proposalId, _votingMode, _actions);
  }

  function _createVoteForProposal(IDAOSpace.VoteOption _votingOption) internal view returns (bytes memory _voteData) {
    return abi.encode(_proposalId, _votingOption);
  }

  /// @dev Don't increment nonce here to keep later lookup easier; uses nonce 0. UUID v4 compliant.
  function _getSpaceId(address _account) internal view returns (bytes16 _spaceId) {
    bytes32 _hash = keccak256(abi.encodePacked('grc20.space', _account, uint256(0), block.chainid));
    _hash = _hash & ~(bytes32(uint256(0xf0)) << 200) | (bytes32(uint256(0x40)) << 200);
    _spaceId = bytes16(_hash & ~(bytes32(uint256(0xc0)) << 184) | (bytes32(uint256(0x80)) << 184));
  }
}
