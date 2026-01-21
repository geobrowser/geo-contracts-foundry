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
  bytes16 internal _initialEditorSpaceId = bytes16(keccak256('_initialEditorSpaceId'));
  bytes16 internal _initialMemberSpaceId = bytes16(keccak256('_initialMemberSpaceId'));
  bytes internal _publishEditsData = 'Curiouser and curiouser!';
  bytes16 internal _initialTopicId = bytes16(keccak256('_initialTopicId'));
  bytes16 internal _proposalId = bytes16(keccak256('_proposalId'));

  function setUp() external {
    // set up
    (_owner, _ownerPrivateKey) = makeAddrAndKey('_owner');
    _votingSettings = IDAOSpace.VotingSettings({
      slowPathPercentageThreshold: 5e5, fastPathFlatThreshold: 1, quorum: 1, duration: 2 days
    });
    _initialEditors = new bytes16[](1);
    _initialEditors[0] = _initialEditorSpaceId;
    _initialMembers = new bytes16[](1);
    _initialMembers[0] = _initialMemberSpaceId;

    // proxy set up
    daoSpaceImplementation = new MockDAOSpace();
    daoSpaceBeacon = UnsafeUpgrades.deployBeacon(address(daoSpaceImplementation), _owner);

    // get predicted DAO Space address for external calls and event emissions
    address predictedDAOSpaceProxy = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
    bytes16 predictedDAOSpaceProxySpaceId = _getSpaceId(predictedDAOSpaceProxy);

    // And the space type and version
    _spaceType = keccak256(bytes(daoSpaceImplementation.name()));
    _spaceVersion = abi.encode(daoSpaceImplementation.version());

    // when delegate called
    _mockRegisterSpaceId(_spaceRegistry, _spaceType, _spaceVersion, predictedDAOSpaceProxySpaceId);

    // mock mapping fetch with ping
    _mockAddressToSpaceId(_spaceRegistry, predictedDAOSpaceProxy, predictedDAOSpaceProxySpaceId);

    // it calls enter on the spaceRegistry with the EDITS_PUBLISHED action
    _mockEnter(
      _spaceRegistry,
      predictedDAOSpaceProxySpaceId,
      predictedDAOSpaceProxySpaceId,
      ActionsConstants.EDITS_PUBLISHED,
      '',
      _publishEditsData
    );

    // it calls enter on the spaceRegistry with the TOPIC_SET action
    _mockEnter(
      _spaceRegistry,
      predictedDAOSpaceProxySpaceId,
      predictedDAOSpaceProxySpaceId,
      ActionsConstants.TOPIC_SET,
      bytes32(_initialTopicId),
      ''
    );

    // it calls enter on the spaceRegistry with the EDITOR_ADDED action
    _mockEnter(
      _spaceRegistry,
      predictedDAOSpaceProxySpaceId,
      predictedDAOSpaceProxySpaceId,
      ActionsConstants.EDITOR_ADDED,
      bytes32(_initialEditorSpaceId),
      ''
    );

    // it calls enter on the spaceRegistry with the MEMBER_ADDED action
    _mockEnter(
      _spaceRegistry,
      predictedDAOSpaceProxySpaceId,
      predictedDAOSpaceProxySpaceId,
      ActionsConstants.MEMBER_ADDED,
      bytes32(_initialMemberSpaceId),
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
    address predictedDAOSpaceProxy = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));

    // it calls spaceRegistry to register space ID
    bytes16 predictedDAOSpaceProxySpaceId = _getSpaceId(predictedDAOSpaceProxy);
    _mockRegisterSpaceId(__spaceRegistry, _spaceType, _spaceVersion, predictedDAOSpaceProxySpaceId);

    // mock mapping fetch with ping
    _mockAddressToSpaceId(__spaceRegistry, predictedDAOSpaceProxy, predictedDAOSpaceProxySpaceId);

    // it calls enter on the spaceRegistry with the EDITS_PUBLISHED action
    if (__publishEditsData.length != 0) {
      _mockEnter(
        __spaceRegistry,
        predictedDAOSpaceProxySpaceId,
        predictedDAOSpaceProxySpaceId,
        ActionsConstants.EDITS_PUBLISHED,
        '',
        __publishEditsData
      );
    }

    // it calls enter on the spaceRegistry with the TOPIC_SET action
    if (__initialTopicId != bytes16(0)) {
      _mockEnter(
        __spaceRegistry,
        predictedDAOSpaceProxySpaceId,
        predictedDAOSpaceProxySpaceId,
        ActionsConstants.TOPIC_SET,
        bytes32(__initialTopicId),
        ''
      );
    }

    // it calls enter on the spaceRegistry with the EDITOR_ADDED action
    _mockEnter(
      __spaceRegistry,
      predictedDAOSpaceProxySpaceId,
      predictedDAOSpaceProxySpaceId,
      ActionsConstants.EDITOR_ADDED,
      bytes32(_initialEditorSpaceId),
      ''
    );

    // it calls enter on the spaceRegistry with the MEMBER_ADDED action
    _mockEnter(
      __spaceRegistry,
      predictedDAOSpaceProxySpaceId,
      predictedDAOSpaceProxySpaceId,
      ActionsConstants.MEMBER_ADDED,
      bytes32(_initialMemberSpaceId),
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

    // it grants the new editor the EDITOR role
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _initialEditorSpaceId));

    // it grants the new member the MEMBER role
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _initialMemberSpaceId));

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
    address predictedDAOSpaceProxy = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));

    // it calls spaceRegistry to register space ID
    bytes16 predictedDAOSpaceProxySpaceId = _getSpaceId(predictedDAOSpaceProxy);
    _mockRegisterSpaceId(__spaceRegistry, _spaceType, _spaceVersion, predictedDAOSpaceProxySpaceId);

    // mock mapping fetch with ping
    _mockAddressToSpaceId(__spaceRegistry, predictedDAOSpaceProxy, predictedDAOSpaceProxySpaceId);

    // it calls enter on the spaceRegistry with the EDITS_PUBLISHED action
    if (__publishEditsData.length != 0) {
      _mockEnter(
        __spaceRegistry,
        predictedDAOSpaceProxySpaceId,
        predictedDAOSpaceProxySpaceId,
        ActionsConstants.EDITS_PUBLISHED,
        '',
        __publishEditsData
      );
    }

    // it calls enter on the spaceRegistry with the TOPIC_SET action
    if (__initialTopicId != bytes16(0)) {
      _mockEnter(
        __spaceRegistry,
        predictedDAOSpaceProxySpaceId,
        predictedDAOSpaceProxySpaceId,
        ActionsConstants.TOPIC_SET,
        bytes32(__initialTopicId),
        ''
      );
    }

    // it calls enter on the spaceRegistry with the EDITOR_ADDED action
    _mockEnter(
      __spaceRegistry,
      predictedDAOSpaceProxySpaceId,
      predictedDAOSpaceProxySpaceId,
      ActionsConstants.EDITOR_ADDED,
      bytes32(_initialEditorSpaceId),
      ''
    );

    // it calls enter on the spaceRegistry with the MEMBER_ADDED action
    _mockEnter(
      __spaceRegistry,
      predictedDAOSpaceProxySpaceId,
      predictedDAOSpaceProxySpaceId,
      ActionsConstants.MEMBER_ADDED,
      bytes32(_initialMemberSpaceId),
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

    bytes memory proposalData = _createSlowPathProposalToAddEditor();
    daoSpaceProxy.write(_getSpaceId(_randomCaller), ActionsConstants.PROPOSAL_CREATED, _subject, proposalData);
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
      new IDAOSpace.Action[](0)
    );

    // it reverts with InvalidProposalId
    vm.expectRevert(IDAOSpace.InvalidProposalId.selector);

    bytes memory proposalData = _createSlowPathProposalToAddEditor();
    daoSpaceProxy.write(_getSpaceId(_randomCaller), ActionsConstants.PROPOSAL_CREATED, _subject, proposalData);
  }

  function test_Write_When_createProposalParamsAreValid(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_CREATED
    whenTheVotingModeIsSlow
  {
    // get voting settings
    IDAOSpace.VotingSettings memory votingSettings = daoSpaceProxy.votingSettings();

    // it calls enter on the spaceRegistry with the PROPOSAL_SETTINGS_SELECTED action
    bytes16 daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));
    _mockEnter(
      _spaceRegistry,
      daoSpaceProxySpaceId,
      daoSpaceProxySpaceId,
      ActionsConstants.PROPOSAL_SETTINGS_SELECTED,
      bytes32(_proposalId),
      abi.encode(
        vm.getBlockTimestamp(),
        vm.getBlockTimestamp() + votingSettings.duration,
        IDAOSpace.VotingMode.Slow,
        votingSettings.quorum,
        votingSettings.slowPathPercentageThreshold
      )
    );

    // when called
    bytes memory proposalData = _createSlowPathProposalToAddEditor();
    daoSpaceProxy.write(_initialEditorSpaceId, ActionsConstants.PROPOSAL_CREATED, _subject, proposalData);

    (, bytes16 creator, IDAOSpace.ProposalParameters memory parameters,, IDAOSpace.Action[] memory actions) =
      daoSpaceProxy.getLatestProposalInformation(_proposalId);

    // it increments the proposal version
    assertEq(daoSpaceProxy.latestProposalVersion(_proposalId), 1);

    // it sets the proposal creator to _fromSpaceId
    assertEq(creator, _initialEditorSpaceId);

    // it sets the proposal start date to block.timestamp
    assertEq(parameters.startDate, vm.getBlockTimestamp());

    // it sets the proposal last date to block.timestamp plus votingSettings.duration
    assertEq(parameters.lastDate, vm.getBlockTimestamp() + _votingSettings.duration);

    // it sets the proposal voting mode
    assertEq(uint256(parameters.votingMode), uint256(IDAOSpace.VotingMode.Slow));

    // it sets the proposal support threshold to the slow path percentage threshold
    assertEq(parameters.supportThreshold, _votingSettings.slowPathPercentageThreshold);

    // it stores the decoded proposal actions
    assertEq(actions.length, 1);
    assertEq(actions[0].to, address(daoSpaceProxy));
    assertEq(actions[0].value, 0);
    assertEq(actions[0].data, abi.encodeCall(IDAOSpace.addEditor, (_getSpaceId(_randomCaller))));
  }

  modifier whenTheVotingModeIsFast() {
    _;
  }

  function test_Write_When_fromSpaceIdIsNotAnEditor(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_CREATED
    whenTheVotingModeIsFast
  {
    // it reverts with InvalidFromSpace
    vm.expectRevert(IDAOSpace.InvalidFromSpace.selector);

    bytes memory proposalData = _createFastPathProposalToAddMember();
    daoSpaceProxy.write(_getSpaceId(_randomCaller), ActionsConstants.PROPOSAL_CREATED, _subject, proposalData);
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
      new IDAOSpace.Action[](0)
    );

    // it reverts with InvalidProposalId
    vm.expectRevert(IDAOSpace.InvalidProposalId.selector);

    bytes memory proposalData = _createFastPathProposalToAddMember();
    daoSpaceProxy.write(_getSpaceId(_randomCaller), ActionsConstants.PROPOSAL_CREATED, _subject, proposalData);
  }

  function test_Write_When_fromSpaceIdIsRestricted(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_CREATED
    whenTheVotingModeIsFast
  {
    daoSpaceProxy.workaround_grantRole(daoSpaceProxy.FAST_PATH_RESTRICTED(), _initialEditorSpaceId);

    // it reverts with FastPathRestricted
    vm.expectRevert(IDAOSpace.FastPathRestricted.selector);

    bytes memory proposalData = _createFastPathProposalToAddMember();
    daoSpaceProxy.write(_initialEditorSpaceId, ActionsConstants.PROPOSAL_CREATED, _subject, proposalData);
  }

  function test_Write_WhenTheDecodedProposalActionIsNotLimitedToOneCall(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_CREATED
    whenTheVotingModeIsFast
  {
    // it reverts with OneActionForFastPath
    vm.expectRevert(IDAOSpace.OneActionForFastPath.selector);

    bytes memory proposalData = _createFastPathProposalToAddTwoMembers();
    daoSpaceProxy.write(_initialEditorSpaceId, ActionsConstants.PROPOSAL_CREATED, _subject, proposalData);
  }

  function test_Write_WhenTheFunctionSelectorOfTheDecodedProposalActionIsNotFastPathValid(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_CREATED
    whenTheVotingModeIsFast
  {
    // it reverts with InvalidAction
    vm.expectRevert(IDAOSpace.InvalidAction.selector);

    bytes memory proposalData = _createFastPathProposalToAddEditor();
    daoSpaceProxy.write(_initialEditorSpaceId, ActionsConstants.PROPOSAL_CREATED, _subject, proposalData);
  }

  function test_Write_WhenTheTargetAddressIsNotTheDAOContractItself(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_CREATED
    whenTheVotingModeIsFast
  {
    // it reverts with InvalidTarget
    vm.expectRevert(IDAOSpace.InvalidTarget.selector);

    bytes memory proposalData = _createFastPathProposalToAddMemberOnAnotherContract();
    daoSpaceProxy.write(_initialEditorSpaceId, ActionsConstants.PROPOSAL_CREATED, _subject, proposalData);
  }

  function test_Write_WhenTheProposalAttemptsToTransferValue(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_CREATED
    whenTheVotingModeIsFast
  {
    // it reverts with InvalidFundsTransfer
    vm.expectRevert(IDAOSpace.InvalidFundsTransfer.selector);

    bytes memory proposalData = _createFastPathProposalToAddMemberAndMoveValue();
    daoSpaceProxy.write(_initialEditorSpaceId, ActionsConstants.PROPOSAL_CREATED, _subject, proposalData);
  }

  function test_Write_When_createProposalParamsAreValid_WhenTheVotingModeIsFast(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_CREATED
    whenTheVotingModeIsFast
  {
    // get voting settings
    IDAOSpace.VotingSettings memory votingSettings = daoSpaceProxy.votingSettings();

    // it calls enter on the spaceRegistry with the PROPOSAL_SETTINGS_SELECTED action
    bytes16 daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));
    _mockEnter(
      _spaceRegistry,
      daoSpaceProxySpaceId,
      daoSpaceProxySpaceId,
      ActionsConstants.PROPOSAL_SETTINGS_SELECTED,
      bytes32(_proposalId),
      abi.encode(
        vm.getBlockTimestamp(),
        vm.getBlockTimestamp() + votingSettings.duration,
        IDAOSpace.VotingMode.Fast,
        votingSettings.quorum,
        votingSettings.fastPathFlatThreshold
      )
    );

    // when called
    bytes memory proposalData = _createFastPathProposalToAddMember();
    daoSpaceProxy.write(_initialEditorSpaceId, ActionsConstants.PROPOSAL_CREATED, _subject, proposalData);

    (, bytes16 creator, IDAOSpace.ProposalParameters memory parameters,, IDAOSpace.Action[] memory actions) =
      daoSpaceProxy.getLatestProposalInformation(_proposalId);

    // it increments the proposal version
    assertEq(daoSpaceProxy.latestProposalVersion(_proposalId), 1);

    // it sets the proposal creator to _fromSpaceId
    assertEq(creator, _initialEditorSpaceId);

    // it sets the proposal start date to block.timestamp
    assertEq(parameters.startDate, vm.getBlockTimestamp());

    // it sets the proposal last date to block.timestamp plus votingSettings.duration
    assertEq(parameters.lastDate, vm.getBlockTimestamp() + _votingSettings.duration);

    // it sets the proposal voting mode
    assertEq(uint256(parameters.votingMode), uint256(IDAOSpace.VotingMode.Fast));

    // it sets the proposal support threshold to the fast path flat threshold
    assertEq(parameters.supportThreshold, _votingSettings.fastPathFlatThreshold);

    // it stores the decoded proposal actions
    assertEq(actions.length, 1);
    assertEq(actions[0].to, address(daoSpaceProxy));
    assertEq(actions[0].value, 0);
    assertEq(actions[0].data, abi.encodeCall(IDAOSpace.addMember, (_getSpaceId(_randomCaller))));
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

    bytes memory voteData = _createVoteForProposal(IDAOSpace.VoteOption(_voteOption));
    daoSpaceProxy.write(_initialEditorSpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, voteData);
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
      _initialEditorSpaceId,
      block.timestamp,
      block.timestamp - 1,
      IDAOSpace.VotingMode.Slow,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    // it reverts with CanNotVote
    vm.expectRevert(IDAOSpace.CanNotVote.selector);

    bytes memory voteData = _createVoteForProposal(IDAOSpace.VoteOption(_voteOption));
    daoSpaceProxy.write(_initialEditorSpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, voteData);
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
      _initialEditorSpaceId,
      block.timestamp,
      block.timestamp + 1,
      IDAOSpace.VotingMode.Slow,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    // it reverts with CanNotVote
    vm.expectRevert(IDAOSpace.CanNotVote.selector);

    bytes memory voteData = _createVoteForProposal(IDAOSpace.VoteOption(_voteOption));
    daoSpaceProxy.write(_initialEditorSpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, voteData);
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
      _initialEditorSpaceId,
      block.timestamp,
      block.timestamp + 1,
      IDAOSpace.VotingMode.Slow,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    // it reverts with CanNotVote
    vm.expectRevert(IDAOSpace.CanNotVote.selector);

    bytes memory voteData = _createVoteForProposal(IDAOSpace.VoteOption.None);
    daoSpaceProxy.write(_initialEditorSpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, voteData);
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
      new IDAOSpace.Action[](0)
    );

    _mockAddressToSpaceId(_spaceRegistry, _spaceRegistry, _getSpaceId(_spaceRegistry));

    // it reverts with CanNotVote
    vm.expectRevert(IDAOSpace.CanNotVote.selector);

    bytes memory voteData = _createVoteForProposal(IDAOSpace.VoteOption(_voteOption));
    daoSpaceProxy.write(_getSpaceId(_randomCaller), ActionsConstants.PROPOSAL_VOTED, _subject, voteData);
  }

  modifier when_voteParamsAreValid() {
    _;
  }

  function test_Write_When_voteParamsAreValid(
    bytes32 _subject,
    uint256 _voteOption
  ) external whenCalledBySpaceRegistry when_actionEqualsPROPOSAL_VOTED when_voteParamsAreValid {
    _voteOption = bound(_voteOption, 1, 3);

    // proposal set up
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      0,
      _initialEditorSpaceId,
      block.timestamp,
      block.timestamp + 1,
      IDAOSpace.VotingMode.Slow,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    // vote
    bytes memory voteData = _createVoteForProposal(IDAOSpace.VoteOption(_voteOption));
    daoSpaceProxy.write(_initialEditorSpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, voteData);

    // it stores the current _fromSpaceId vote
    IDAOSpace.VoteOption storedVoteOption = daoSpaceProxy.getLatestProposalVote(_proposalId, _initialEditorSpaceId);
    assertEq(uint256(storedVoteOption), _voteOption);
  }

  function test_Write_WhenTheFormer_fromSpaceIdVoteEqualsYes(bytes32 _subject)
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
      _initialEditorSpaceId,
      block.timestamp,
      block.timestamp + 1,
      IDAOSpace.VotingMode.Slow,
      1,
      1,
      new IDAOSpace.Action[](0)
    );
    // set inital vote to yes and tally
    daoSpaceProxy.workaround_setFormerVote(_proposalId, _initialEditorSpaceId, IDAOSpace.VoteOption.Yes);
    (,,, IDAOSpace.Tally memory tally,) = daoSpaceProxy.getLatestProposalInformation(_proposalId);
    assertEq(tally.yes, 1);

    // vote no
    bytes memory voteData = _createVoteForProposal(IDAOSpace.VoteOption.No);
    daoSpaceProxy.write(_initialEditorSpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, voteData);

    // it decreases the yes vote tally by one
    (,,, tally,) = daoSpaceProxy.getLatestProposalInformation(_proposalId);
    assertEq(tally.yes, 0);
  }

  function test_Write_WhenTheFormer_fromSpaceIdVoteEqualsNo(bytes32 _subject)
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
      _initialEditorSpaceId,
      block.timestamp,
      block.timestamp + 1,
      IDAOSpace.VotingMode.Slow,
      1,
      1,
      new IDAOSpace.Action[](0)
    );
    // set inital vote to no and tally
    daoSpaceProxy.workaround_setFormerVote(_proposalId, _initialEditorSpaceId, IDAOSpace.VoteOption.No);
    (,,, IDAOSpace.Tally memory tally,) = daoSpaceProxy.getLatestProposalInformation(_proposalId);
    assertEq(tally.no, 1);

    // vote yes
    bytes memory voteData = _createVoteForProposal(IDAOSpace.VoteOption.Yes);
    daoSpaceProxy.write(_initialEditorSpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, voteData);

    // it decreases the no vote tally by one
    (,,, tally,) = daoSpaceProxy.getLatestProposalInformation(_proposalId);
    assertEq(tally.no, 0);
  }

  function test_Write_WhenTheFormer_fromSpaceIdVoteEqualsAbstain(bytes32 _subject)
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
      _initialEditorSpaceId,
      block.timestamp,
      block.timestamp + 1,
      IDAOSpace.VotingMode.Slow,
      1,
      1,
      new IDAOSpace.Action[](0)
    );
    // set inital vote to abstain and tally
    daoSpaceProxy.workaround_setFormerVote(_proposalId, _initialEditorSpaceId, IDAOSpace.VoteOption.Abstain);
    (,,, IDAOSpace.Tally memory tally,) = daoSpaceProxy.getLatestProposalInformation(_proposalId);
    assertEq(tally.abstain, 1);

    // vote yes
    bytes memory voteData = _createVoteForProposal(IDAOSpace.VoteOption.Yes);
    daoSpaceProxy.write(_initialEditorSpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, voteData);

    // it decreases the abstain vote tally by one
    (,,, tally,) = daoSpaceProxy.getLatestProposalInformation(_proposalId);
    assertEq(tally.abstain, 0);
  }

  function test_Write_WhenTheCurrent_fromSpaceIdVoteEqualsYes(bytes32 _subject)
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
      _initialEditorSpaceId,
      block.timestamp,
      block.timestamp + 1,
      IDAOSpace.VotingMode.Slow,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    // vote yes
    bytes memory voteData = _createVoteForProposal(IDAOSpace.VoteOption.Yes);
    daoSpaceProxy.write(_initialEditorSpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, voteData);

    // it increases the yes vote tally by one
    (,,, IDAOSpace.Tally memory tally,) = daoSpaceProxy.getLatestProposalInformation(_proposalId);
    assertEq(tally.yes, 1);
  }

  function test_Write_WhenTheCurrent_fromSpaceIdVoteEqualsNo(bytes32 _subject)
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
      _initialEditorSpaceId,
      block.timestamp,
      block.timestamp + 1,
      IDAOSpace.VotingMode.Slow,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    // vote no
    bytes memory voteData = _createVoteForProposal(IDAOSpace.VoteOption.No);
    daoSpaceProxy.write(_initialEditorSpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, voteData);

    // it increases the no vote tally by one
    (,,, IDAOSpace.Tally memory tally,) = daoSpaceProxy.getLatestProposalInformation(_proposalId);
    assertEq(tally.no, 1);
  }

  function test_Write_WhenTheCurrent_fromSpaceIdVoteEqualsAbstain(bytes32 _subject)
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
      _initialEditorSpaceId,
      block.timestamp,
      block.timestamp + 1,
      IDAOSpace.VotingMode.Slow,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    // vote abstain
    bytes memory voteData = _createVoteForProposal(IDAOSpace.VoteOption.Abstain);
    daoSpaceProxy.write(_initialEditorSpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, voteData);

    // it increases the abstain vote tally by one
    (,,, IDAOSpace.Tally memory tally,) = daoSpaceProxy.getLatestProposalInformation(_proposalId);
    assertEq(tally.abstain, 1);
  }

  modifier whenTheProposalVotingModeIsUsingTheFastPath() {
    _;
  }

  function test_Write_WhenTheCurrent_fromSpaceIdVoteEqualsNo_WhenTheProposalVotingModeIsUsingTheFastPath(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_VOTED
    when_voteParamsAreValid
    whenTheProposalVotingModeIsUsingTheFastPath
  {
    // proposal set up
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      0,
      _initialEditorSpaceId,
      block.timestamp,
      block.timestamp + 1e5,
      IDAOSpace.VotingMode.Fast,
      1,
      1,
      new IDAOSpace.Action[](0)
    );

    (, bytes16 creator, IDAOSpace.ProposalParameters memory parameters,,) =
      daoSpaceProxy.getLatestProposalInformation(_proposalId);
    assertEq(uint256(parameters.votingMode), uint256(IDAOSpace.VotingMode.Fast));
    assertEq(parameters.supportThreshold, 1);
    assertEq(parameters.startDate, block.timestamp);
    assertEq(parameters.lastDate, block.timestamp + 1e5);

    // warp forwards to ensure start date is reset
    vm.warp(block.timestamp + 100);

    IDAOSpace.VotingSettings memory votingSettings = daoSpaceProxy.votingSettings();

    // it calls enter on the spaceRegistry with the PROPOSAL_SETTINGS_SELECTED action
    bytes16 daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));
    _mockEnter(
      _spaceRegistry,
      daoSpaceProxySpaceId,
      daoSpaceProxySpaceId,
      ActionsConstants.PROPOSAL_SETTINGS_SELECTED,
      bytes32(_proposalId),
      abi.encode(
        block.timestamp,
        block.timestamp + votingSettings.duration,
        IDAOSpace.VotingMode.Slow,
        votingSettings.quorum,
        votingSettings.slowPathPercentageThreshold
      )
    );

    // vote no
    bytes memory voteData = _createVoteForProposal(IDAOSpace.VoteOption.No);
    daoSpaceProxy.write(_initialEditorSpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, voteData);

    (, creator, parameters,,) = daoSpaceProxy.getLatestProposalInformation(_proposalId);

    // it updates the proposal voting mode to the slow path
    assertEq(uint256(parameters.votingMode), uint256(IDAOSpace.VotingMode.Slow));

    // it updates the proposal support threshold to the slow path percentage threshold
    assertEq(parameters.supportThreshold, daoSpaceProxy.votingSettings().slowPathPercentageThreshold);

    // it updates the proposal start date to block.timestamp
    assertEq(parameters.startDate, block.timestamp);

    // it updates the proposal last date to block.timestamp plus votingSettings.duration
    assertEq(parameters.lastDate, block.timestamp + daoSpaceProxy.votingSettings().duration);
  }

  modifier whenTheCurrent_fromSpaceIdVoteEqualsYes() {
    _;
  }

  function test_Write_WhenTheProposalCanBeExecuted(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_VOTED
    when_voteParamsAreValid
    whenTheProposalVotingModeIsUsingTheFastPath
    whenTheCurrent_fromSpaceIdVoteEqualsYes
  {
    // proposal set up to add randomCaller as an editor
    IDAOSpace.Action[] memory actions = new IDAOSpace.Action[](1);
    actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addEditor, (_getSpaceId(_randomCaller)))
    });
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      0,
      _initialEditorSpaceId,
      block.timestamp,
      block.timestamp + 1e5,
      IDAOSpace.VotingMode.Fast,
      0,
      1,
      actions
    );

    assertFalse(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _getSpaceId(_randomCaller)));

    // it calls enter on the spaceRegistry with the EDITOR_ADDED action
    bytes16 daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));
    _mockEnter(
      _spaceRegistry,
      daoSpaceProxySpaceId,
      daoSpaceProxySpaceId,
      ActionsConstants.EDITOR_ADDED,
      bytes32(_getSpaceId(_randomCaller)),
      ''
    );

    // vote yes
    bytes memory voteData = _createVoteForProposal(IDAOSpace.VoteOption.Yes);
    daoSpaceProxy.write(_initialEditorSpaceId, ActionsConstants.PROPOSAL_VOTED, _subject, voteData);

    // it loops over the stored proposal actions and performs the external callsc
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _getSpaceId(_randomCaller)));
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
      _initialEditorSpaceId,
      block.timestamp,
      block.timestamp + 1e5,
      IDAOSpace.VotingMode.Slow,
      0,
      1,
      new IDAOSpace.Action[](0)
    );

    // it reverts with InvalidCaller
    vm.expectRevert(IDAOSpace.InvalidCaller.selector);

    bytes memory proposalData = _createFastPathProposalToAddMember();
    daoSpaceProxy.write(_getSpaceId(_randomCaller), ActionsConstants.PROPOSAL_UPDATED, _subject, proposalData);
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
      _initialEditorSpaceId,
      block.timestamp,
      block.timestamp + 1e5,
      IDAOSpace.VotingMode.Slow,
      0,
      1,
      new IDAOSpace.Action[](0)
    );

    // it reverts with InvalidProposalId
    vm.expectRevert(IDAOSpace.InvalidProposalId.selector);

    bytes memory proposalData = _createFastPathProposalToAddMember();
    daoSpaceProxy.write(_initialEditorSpaceId, ActionsConstants.PROPOSAL_UPDATED, _subject, proposalData);
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
      _initialEditorSpaceId,
      block.timestamp,
      block.timestamp + 1e5,
      IDAOSpace.VotingMode.Slow,
      0,
      1,
      new IDAOSpace.Action[](0)
    );
    daoSpaceProxy.workaround_setFormerVote(_proposalId, _initialEditorSpaceId, IDAOSpace.VoteOption(_voteOption));
    daoSpaceProxy.workaround_setTally(_proposalId, 1, 1, 1);

    IDAOSpace.VotingSettings memory votingSettings = daoSpaceProxy.votingSettings();

    // it calls enter on the spaceRegistry with the PROPOSAL_SETTINGS_SELECTED action
    bytes16 daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));
    _mockEnter(
      _spaceRegistry,
      daoSpaceProxySpaceId,
      daoSpaceProxySpaceId,
      ActionsConstants.PROPOSAL_SETTINGS_SELECTED,
      bytes32(_proposalId),
      abi.encode(
        block.timestamp,
        block.timestamp + votingSettings.duration,
        IDAOSpace.VotingMode.Fast,
        votingSettings.quorum,
        votingSettings.fastPathFlatThreshold
      )
    );

    bytes memory proposalData = _createFastPathProposalToAddMember();
    daoSpaceProxy.write(_initialEditorSpaceId, ActionsConstants.PROPOSAL_UPDATED, _subject, proposalData);

    (,,, IDAOSpace.Tally memory tally, IDAOSpace.Action[] memory actions) =
      daoSpaceProxy.getLatestProposalInformation(_proposalId);
    IDAOSpace.VoteOption _vote = daoSpaceProxy.getLatestProposalVote(_proposalId, _initialEditorSpaceId);

    // it resets the voting state
    assertEq(tally.abstain, 0);
    assertEq(tally.yes, 0);
    assertEq(tally.no, 0);
    assertEq(uint256(_vote), 0);

    // it updates the proposal with a new version
    assertEq(daoSpaceProxy.latestProposalVersion(_proposalId), 1);
    assertEq(actions.length, 1);

    (,,, tally, actions) = daoSpaceProxy.getProposalInformation(_proposalId, 0);
    _vote = daoSpaceProxy.getProposalVote(_proposalId, 0, _initialEditorSpaceId);

    // it also retains the previous version data
    assertEq(tally.abstain, 1);
    assertEq(tally.yes, 1);
    assertEq(tally.no, 1);
    assertEq(uint256(_vote), _voteOption);
    assertEq(actions.length, 0);
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
      _initialEditorSpaceId,
      block.timestamp,
      block.timestamp + 1,
      IDAOSpace.VotingMode.Fast,
      2,
      1,
      new IDAOSpace.Action[](0)
    );

    // it reverts with CanNotExecute
    vm.expectRevert(IDAOSpace.CanNotExecute.selector);

    bytes memory executeData = abi.encode(_proposalId);
    daoSpaceProxy.write(_initialEditorSpaceId, ActionsConstants.PROPOSAL_EXECUTED, _subject, executeData);
  }

  function test_Write_WhenTheProposalStartDateEqualsZero_When_actionEqualsPROPOSAL_EXECUTED(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_EXECUTED
  {
    // it reverts with CanNotExecute
    vm.expectRevert(IDAOSpace.CanNotExecute.selector);

    bytes memory executeData = abi.encode(_proposalId);
    daoSpaceProxy.write(_initialEditorSpaceId, ActionsConstants.PROPOSAL_EXECUTED, _subject, executeData);
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
      _initialEditorSpaceId,
      block.timestamp,
      block.timestamp + 1,
      IDAOSpace.VotingMode.Slow,
      2,
      1,
      new IDAOSpace.Action[](0)
    );

    vm.warp(block.timestamp + 2);

    // it reverts with CanNotExecute
    vm.expectRevert(IDAOSpace.CanNotExecute.selector);

    bytes memory executeData = abi.encode(_proposalId);
    daoSpaceProxy.write(_initialEditorSpaceId, ActionsConstants.PROPOSAL_EXECUTED, _subject, executeData);
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
    // proposal set up to add randomCaller as an editor
    IDAOSpace.Action[] memory actions = new IDAOSpace.Action[](1);
    actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addEditor, (_getSpaceId(_randomCaller)))
    });
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      0,
      _initialEditorSpaceId,
      block.timestamp,
      block.timestamp + 1,
      IDAOSpace.VotingMode.Slow,
      0,
      1,
      actions
    );

    // set vote to yes
    daoSpaceProxy.workaround_setFormerVote(_proposalId, _initialEditorSpaceId, IDAOSpace.VoteOption.Yes);

    // warp to after last date
    vm.warp(block.timestamp + 2);

    assertFalse(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _getSpaceId(_randomCaller)));

    // it calls enter on the spaceRegistry with the EDITOR_ADDED action
    bytes16 daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));
    _mockEnter(
      _spaceRegistry,
      daoSpaceProxySpaceId,
      daoSpaceProxySpaceId,
      ActionsConstants.EDITOR_ADDED,
      bytes32(_getSpaceId(_randomCaller)),
      ''
    );

    bytes memory executeData = abi.encode(_proposalId);
    daoSpaceProxy.write(_initialEditorSpaceId, ActionsConstants.PROPOSAL_EXECUTED, _subject, executeData);

    // it loops over the stored proposal actions and performs the external calls
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _getSpaceId(_randomCaller)));
  }

  function test_Write_WhenAnExternalCallFails(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_EXECUTED
    whenTheProposalCanBeExecuted
  {
    // proposal set up to with a deliberately faulty call
    IDAOSpace.Action[] memory actions = new IDAOSpace.Action[](1);
    actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(ISpaceRegistry.registerSpaceId, (bytes32(0), ''))
    });
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      0,
      _initialEditorSpaceId,
      block.timestamp,
      block.timestamp + 1,
      IDAOSpace.VotingMode.Slow,
      0,
      1,
      actions
    );

    // set vote to yes
    daoSpaceProxy.workaround_setFormerVote(_proposalId, _initialEditorSpaceId, IDAOSpace.VoteOption.Yes);

    // warp to after last date
    vm.warp(block.timestamp + 2);

    // it reverts with ActionReverted
    vm.expectRevert(IDAOSpace.ActionReverted.selector);

    bytes memory executeData = abi.encode(_proposalId);
    daoSpaceProxy.write(_initialEditorSpaceId, ActionsConstants.PROPOSAL_EXECUTED, _subject, executeData);
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
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _initialMemberSpaceId));

    // it calls enter on the spaceRegistry with the MEMBER_REMOVED action
    bytes16 daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));
    _mockEnter(
      _spaceRegistry,
      daoSpaceProxySpaceId,
      daoSpaceProxySpaceId,
      ActionsConstants.MEMBER_REMOVED,
      bytes32(_initialMemberSpaceId),
      ''
    );

    bytes memory leaveSpaceData = abi.encode(daoSpaceProxy.MEMBER());
    daoSpaceProxy.write(_initialMemberSpaceId, ActionsConstants.SPACE_LEFT, _subject, leaveSpaceData);

    // it revokes the role of MEMBER from the _fromSpaceId
    assertFalse(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _initialMemberSpaceId));
  }

  function test_Write_WhenTheRoleSpecifiedIsEDITORAndThe_fromSpaceIdIsAnEditor(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsSPACE_LEFT
  {
    // Set quorum and fast path flat threshold to 0 so that an editor can be removed
    daoSpaceProxy.workaround_setVotingSettings(
      IDAOSpace.VotingSettings({
        slowPathPercentageThreshold: _votingSettings.slowPathPercentageThreshold,
        fastPathFlatThreshold: 0,
        quorum: 0,
        duration: _votingSettings.duration
      })
    );

    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _initialEditorSpaceId));

    // it calls enter on the spaceRegistry with the EDITOR_REMOVED action
    bytes16 daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));
    _mockEnter(
      _spaceRegistry,
      daoSpaceProxySpaceId,
      daoSpaceProxySpaceId,
      ActionsConstants.EDITOR_REMOVED,
      bytes32(_initialEditorSpaceId),
      ''
    );

    bytes memory leaveSpaceData = abi.encode(daoSpaceProxy.EDITOR());
    daoSpaceProxy.write(_initialEditorSpaceId, ActionsConstants.SPACE_LEFT, _subject, leaveSpaceData);

    // it revokes the role of EDITOR from the _fromSpaceId
    assertFalse(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _initialEditorSpaceId));
  }

  function test_Write_WhenTheRoleIsNotHeldByThe_fromSpaceIdOrTheRoleIsNeitherMEMBERNorEDITOR(
    bytes32 _subject,
    bytes16 _callerSpaceId
  ) external whenCalledBySpaceRegistry when_actionEqualsSPACE_LEFT {
    vm.assume(_callerSpaceId != _initialEditorSpaceId);
    vm.assume(_callerSpaceId != _initialMemberSpaceId);

    // it reverts with InvalidFromSpace
    // role is neither MEMBER or EDITOR
    bytes memory leaveSpaceData = abi.encode(daoSpaceProxy.DAO());
    vm.expectRevert(IDAOSpace.InvalidFromSpace.selector);
    daoSpaceProxy.write(_callerSpaceId, ActionsConstants.SPACE_LEFT, _subject, leaveSpaceData);

    // _fromSpaceId doesn't have role
    leaveSpaceData = abi.encode(daoSpaceProxy.MEMBER());
    vm.expectRevert(IDAOSpace.InvalidFromSpace.selector);
    daoSpaceProxy.write(_initialEditorSpaceId, ActionsConstants.SPACE_LEFT, _subject, leaveSpaceData);

    // _fromSpaceId doesn't have role
    leaveSpaceData = abi.encode(daoSpaceProxy.EDITOR());
    vm.expectRevert(IDAOSpace.InvalidFromSpace.selector);
    daoSpaceProxy.write(_initialMemberSpaceId, ActionsConstants.SPACE_LEFT, _subject, leaveSpaceData);
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
    bytes16 randomCallerSpaceId = _getSpaceId(_randomCaller);
    daoSpaceProxy.workaround_createProposal(
      _proposalId, false, 0, randomCallerSpaceId, 1, 1, IDAOSpace.VotingMode.Fast, 1, 1, new IDAOSpace.Action[](0)
    );

    // it reverts with InvalidProposalId
    vm.expectRevert(IDAOSpace.InvalidProposalId.selector);

    daoSpaceProxy.write(
      randomCallerSpaceId,
      ActionsConstants.MEMBERSHIP_REQUESTED,
      bytes32(0),
      abi.encode(_proposalId, randomCallerSpaceId)
    );
  }

  function test_Write_When_fromSpaceIdIsRestricted_When_actionEqualsMEMBERSHIP_REQUESTED()
    external
    whenCalledBySpaceRegistry
    when_actionEqualsMEMBERSHIP_REQUESTED
  {
    bytes16 randomCallerSpaceId = _getSpaceId(_randomCaller);
    daoSpaceProxy.workaround_grantRole(daoSpaceProxy.FAST_PATH_RESTRICTED(), randomCallerSpaceId);

    // it reverts with FastPathRestricted
    vm.expectRevert(IDAOSpace.FastPathRestricted.selector);

    daoSpaceProxy.write(
      randomCallerSpaceId,
      ActionsConstants.MEMBERSHIP_REQUESTED,
      bytes32(0),
      abi.encode(_proposalId, randomCallerSpaceId)
    );
  }

  function test_Write_WhenTheRequestCanBeMade()
    external
    whenCalledBySpaceRegistry
    when_actionEqualsMEMBERSHIP_REQUESTED
  {
    // get voting settings
    IDAOSpace.VotingSettings memory votingSettings = daoSpaceProxy.votingSettings();

    bytes16 randomCallerSpaceId = _getSpaceId(_randomCaller);

    // it calls enter on the spaceRegistry with the PROPOSAL_CREATED action
    IDAOSpace.Action[] memory actions = new IDAOSpace.Action[](1);
    actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addMember, (randomCallerSpaceId))
    });

    bytes16 daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));

    // Mock addressToSpaceId for _ping calls (called twice: once for PROPOSAL_CREATED, once for PROPOSAL_SETTINGS_SELECTED)
    _mockAddressToSpaceId(_spaceRegistry, address(daoSpaceProxy), daoSpaceProxySpaceId);
    _mockAddressToSpaceId(_spaceRegistry, address(daoSpaceProxy), daoSpaceProxySpaceId);

    // it calls enter on the spaceRegistry with the PROPOSAL_CREATED action
    _mockEnter(
      _spaceRegistry,
      daoSpaceProxySpaceId,
      daoSpaceProxySpaceId,
      ActionsConstants.PROPOSAL_CREATED,
      bytes32(_proposalId),
      abi.encode(_proposalId, IDAOSpace.VotingMode.Fast, actions)
    );

    // it calls enter on the spaceRegistry with the PROPOSAL_SETTINGS_SELECTED action
    _mockEnter(
      _spaceRegistry,
      daoSpaceProxySpaceId,
      daoSpaceProxySpaceId,
      ActionsConstants.PROPOSAL_SETTINGS_SELECTED,
      bytes32(_proposalId),
      abi.encode(
        vm.getBlockTimestamp(),
        vm.getBlockTimestamp() + votingSettings.duration,
        IDAOSpace.VotingMode.Fast,
        votingSettings.quorum,
        votingSettings.fastPathFlatThreshold
      )
    );

    daoSpaceProxy.write(
      randomCallerSpaceId,
      ActionsConstants.MEMBERSHIP_REQUESTED,
      bytes32(0),
      abi.encode(_proposalId, randomCallerSpaceId)
    );

    // it creates a fast path proposal to add the new member
    (, bytes16 creator, IDAOSpace.ProposalParameters memory parameters,, IDAOSpace.Action[] memory actionsA) =
      daoSpaceProxy.getLatestProposalInformation(_proposalId);

    // it increments the proposal version
    assertEq(daoSpaceProxy.latestProposalVersion(_proposalId), 1);

    // it sets the proposal creator to _fromSpaceId
    assertEq(creator, randomCallerSpaceId);

    // it sets the proposal start date to block.timestamp
    assertEq(parameters.startDate, vm.getBlockTimestamp());

    // it sets the proposal last date to block.timestamp plus votingSettings.duration
    assertEq(parameters.lastDate, vm.getBlockTimestamp() + _votingSettings.duration);

    // it sets the proposal voting mode
    assertEq(uint256(parameters.votingMode), uint256(IDAOSpace.VotingMode.Fast));

    // it sets the proposal support threshold to the slow path percentage threshold
    assertEq(parameters.supportThreshold, _votingSettings.fastPathFlatThreshold);

    // it stores the decoded proposal actions
    assertEq(actionsA.length, 1);
    assertEq(actionsA[0].to, address(daoSpaceProxy));
    assertEq(actionsA[0].value, 0);
    assertEq(actionsA[0].data, abi.encodeCall(IDAOSpace.addMember, (randomCallerSpaceId)));
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
    bytes memory flagData = abi.encode(_getSpaceId(_randomCaller));

    // it reverts with InvalidFromSpace
    vm.expectRevert(IDAOSpace.InvalidFromSpace.selector);
    daoSpaceProxy.write(_initialMemberSpaceId, ActionsConstants.SPACE_FAST_PATH_RESTRICTED, _subject, flagData);
  }

  function test_Write_When_restrictSpaceParamsAreValid(bytes32 _subject)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsSPACE_FAST_PATH_RESTRICTED
  {
    assertFalse(daoSpaceProxy.hasRole(daoSpaceProxy.FAST_PATH_RESTRICTED(), _getSpaceId(_randomCaller)));

    // initial editor flags themselves
    bytes memory flagData = abi.encode(_getSpaceId(_randomCaller));
    daoSpaceProxy.write(_initialEditorSpaceId, ActionsConstants.SPACE_FAST_PATH_RESTRICTED, _subject, flagData);

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
    address _sender,
    address _from,
    address _to,
    bytes32 _action,
    bytes32 _subject,
    bytes calldata _data,
    bytes calldata _signature
  ) external {
    vm.prank(_from);

    // it reverts with VerifyDisabled
    vm.expectRevert(IDAOSpace.VerifyDisabled.selector);
    bytes16 toSpaceId = _getSpaceId(_to);
    daoSpaceProxy.verify(_sender, toSpaceId, _action, _subject, _data, _signature);
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
    daoSpaceProxy.addEditor(_initialEditorSpaceId);
  }

  function test_AddEditor_When_newEditorIsNotAnEditor(bytes16 _newEditorSpaceId) external whenCalledByDAO {
    vm.assume(_newEditorSpaceId != _initialEditorSpaceId);

    assertFalse(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _newEditorSpaceId));

    uint256 totalEditorsBefore = daoSpaceProxy.totalEditors();
    assertEq(totalEditorsBefore, 1);

    _mockAddressToSpaceId(_spaceRegistry, address(daoSpaceProxy), _getSpaceId(address(daoSpaceProxy)));

    // it calls enter on the spaceRegistry with the EDITOR_ADDED action
    bytes16 daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));
    _mockEnter(
      _spaceRegistry,
      daoSpaceProxySpaceId,
      daoSpaceProxySpaceId,
      ActionsConstants.EDITOR_ADDED,
      bytes32(_newEditorSpaceId),
      ''
    );
    daoSpaceProxy.addEditor(_newEditorSpaceId);

    // it increments totalEditors
    assertEq(daoSpaceProxy.totalEditors(), totalEditorsBefore + 1);

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
    vm.assume(_oldEditorSpaceId != _initialEditorSpaceId);

    _mockAddressToSpaceId(_spaceRegistry, address(daoSpaceProxy), _getSpaceId(address(daoSpaceProxy)));

    // it reverts with InvalidSpaceIdForRole
    vm.expectRevert(IDAOSpace.InvalidSpaceIdForRole.selector);
    daoSpaceProxy.removeEditor(_oldEditorSpaceId);
  }

  function test_RemoveEditor_WhenTheVotingSettingsQuorumEqualsTotalEditors() external whenCalledByDAO {
    daoSpaceProxy.workaround_setVotingSettings(
      IDAOSpace.VotingSettings({
        slowPathPercentageThreshold: _votingSettings.slowPathPercentageThreshold,
        fastPathFlatThreshold: 0,
        quorum: _votingSettings.quorum,
        duration: _votingSettings.duration
      })
    );

    // it reverts with InvalidSetting
    vm.expectRevert(IDAOSpace.InvalidSetting.selector);
    daoSpaceProxy.removeEditor(_initialEditorSpaceId);
  }

  function test_RemoveEditor_WhenTheVotingSettingsFastPathFlatThresholdEqualsTotalEditors() external whenCalledByDAO {
    daoSpaceProxy.workaround_setVotingSettings(
      IDAOSpace.VotingSettings({
        slowPathPercentageThreshold: _votingSettings.slowPathPercentageThreshold,
        fastPathFlatThreshold: _votingSettings.fastPathFlatThreshold,
        quorum: 0,
        duration: _votingSettings.duration
      })
    );

    // it reverts with InvalidSetting
    vm.expectRevert(IDAOSpace.InvalidSetting.selector);
    daoSpaceProxy.removeEditor(_initialEditorSpaceId);
  }

  function test_RemoveEditor_WhenInputParamsAreValid() external whenCalledByDAO {
    // Set quorum and fast path flat threshold to 0 so that an editor can be removed
    daoSpaceProxy.workaround_setVotingSettings(
      IDAOSpace.VotingSettings({
        slowPathPercentageThreshold: _votingSettings.slowPathPercentageThreshold,
        fastPathFlatThreshold: 0,
        quorum: 0,
        duration: _votingSettings.duration
      })
    );

    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _initialEditorSpaceId));

    uint256 totalEditorsBefore = daoSpaceProxy.totalEditors();
    assertEq(totalEditorsBefore, 1);

    // it calls enter on the spaceRegistry with the EDITOR_REMOVED action
    bytes16 daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));
    _mockEnter(
      _spaceRegistry,
      daoSpaceProxySpaceId,
      daoSpaceProxySpaceId,
      ActionsConstants.EDITOR_REMOVED,
      bytes32(_initialEditorSpaceId),
      ''
    );
    daoSpaceProxy.removeEditor(_initialEditorSpaceId);

    // it decrements totalEditors
    assertEq(daoSpaceProxy.totalEditors(), totalEditorsBefore - 1);

    // it removes the EDITOR role from _oldEditor
    assertFalse(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _initialEditorSpaceId));
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
    daoSpaceProxy.addMember(_initialMemberSpaceId);
  }

  function test_AddMember_When_newMemberIsNotAMember(bytes16 _newMemberSpaceId) external whenCalledByDAO {
    vm.assume(_newMemberSpaceId != _initialMemberSpaceId);
    assertFalse(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _newMemberSpaceId));

    // it calls enter on the spaceRegistry with the MEMBER_ADDED action
    bytes16 daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));
    _mockEnter(
      _spaceRegistry,
      daoSpaceProxySpaceId,
      daoSpaceProxySpaceId,
      ActionsConstants.MEMBER_ADDED,
      bytes32(_newMemberSpaceId),
      ''
    );
    daoSpaceProxy.addMember(_newMemberSpaceId);

    // it grants _newMember the MEMBER role
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _newMemberSpaceId));
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
    vm.assume(_oldMemberSpaceId != _initialMemberSpaceId);

    // it reverts with InvalidSpaceIdForRole
    vm.expectRevert(IDAOSpace.InvalidSpaceIdForRole.selector);
    daoSpaceProxy.removeMember(_oldMemberSpaceId);
  }

  function test_RemoveMember_When_oldMemberIsAMember() external whenCalledByDAO {
    assertTrue(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _initialMemberSpaceId));

    // it calls enter on the spaceRegistry with the MEMBER_REMOVED action
    bytes16 daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));
    _mockEnter(
      _spaceRegistry,
      daoSpaceProxySpaceId,
      daoSpaceProxySpaceId,
      ActionsConstants.MEMBER_REMOVED,
      bytes32(_initialMemberSpaceId),
      ''
    );
    daoSpaceProxy.removeMember(_initialMemberSpaceId);

    // it removes the MEMBER role from _oldMember
    assertFalse(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _initialMemberSpaceId));
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
    bytes16 daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));
    _mockAddressToSpaceId(_spaceRegistry, address(daoSpaceProxy), daoSpaceProxySpaceId);

    // it calls enter on the spaceRegistry with the SPACE_FAST_PATH_UNRESTRICTED action
    _mockEnter(
      _spaceRegistry,
      daoSpaceProxySpaceId,
      daoSpaceProxySpaceId,
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
    bytes16 daoSpaceProxySpaceId = _getSpaceId(address(daoSpaceProxy));
    _mockAddressToSpaceId(_spaceRegistry, address(daoSpaceProxy), daoSpaceProxySpaceId);

    // it calls enter on the spaceRegistry with the input variables passed
    _mockEnter(_spaceRegistry, daoSpaceProxySpaceId, daoSpaceProxySpaceId, _action, _subject, _data);
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

  function test_UpdateVotingSettings_WhenSlowPathPercentageThresholdIsGreaterThanRATIO_BASE(uint256 _slowPathPercentageThreshold)
    external
    whenCalledByDAO
  {
    vm.assume(_slowPathPercentageThreshold > daoSpaceProxy.RATIO_BASE());
    _votingSettings.slowPathPercentageThreshold = _slowPathPercentageThreshold;

    // it reverts with InvalidSetting
    vm.expectRevert(IDAOSpace.InvalidSetting.selector);
    daoSpaceProxy.updateVotingSettings(_votingSettings);
  }

  function test_UpdateVotingSettings_WhenFastPathFlatThresholdIsGreaterThanTotalEditors(uint256 _fastPathFlatThreshold)
    external
    whenCalledByDAO
  {
    vm.assume(_fastPathFlatThreshold > daoSpaceProxy.totalEditors());
    _votingSettings.fastPathFlatThreshold = _fastPathFlatThreshold;

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
    __votingSettings.slowPathPercentageThreshold = bound(
      __votingSettings.slowPathPercentageThreshold, 0, daoSpaceProxy.RATIO_BASE()
    );
    __votingSettings.fastPathFlatThreshold =
      bound(__votingSettings.fastPathFlatThreshold, 0, daoSpaceProxy.totalEditors());
    __votingSettings.quorum = bound(__votingSettings.quorum, 0, daoSpaceProxy.totalEditors());
    __votingSettings.duration = bound(
      __votingSettings.duration, daoSpaceProxy.MINIMUM_VOTING_DURATION(), daoSpaceProxy.MINIMUM_VOTING_DURATION() * 100
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

  modifier whenTheProposalVotingModeIsUsingTheSlowPath() {
    _;
  }

  function test_IsSupportThresholdReached_WhenTheBlockTimestampIsLessThanOrEqualToTheProposalLastDate()
    external
    whenTheProposalVotingModeIsUsingTheSlowPath
  {
    // set up
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      0,
      _initialEditorSpaceId,
      block.timestamp,
      block.timestamp + daoSpaceProxy.votingSettings().duration,
      IDAOSpace.VotingMode.Slow,
      daoSpaceProxy.votingSettings().slowPathPercentageThreshold,
      daoSpaceProxy.votingSettings().quorum,
      new IDAOSpace.Action[](0)
    );

    // it returns false
    assertFalse(daoSpaceProxy.isSupportThresholdReached(_proposalId));
  }

  function test_IsSupportThresholdReached_WhenTheVotingQuorumHasNotBeenReached(
    uint256 _yes,
    uint256 _no,
    uint256 _abstain,
    uint256 _quorum,
    uint256 _slowPathPercentageThreshold
  ) external whenTheProposalVotingModeIsUsingTheSlowPath {
    // set up
    _yes = bound(_yes, 0, 1e3);
    _no = bound(_no, 0, 1e3);
    _abstain = bound(_abstain, 0, 1e3);
    _quorum = bound(_quorum, _yes + _no + _abstain + 1, 1e4);
    _slowPathPercentageThreshold = bound(_slowPathPercentageThreshold, 1, daoSpaceProxy.RATIO_BASE());
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      0,
      _initialEditorSpaceId,
      block.timestamp,
      block.timestamp + daoSpaceProxy.votingSettings().duration,
      IDAOSpace.VotingMode.Slow,
      _slowPathPercentageThreshold,
      _quorum,
      new IDAOSpace.Action[](0)
    );
    daoSpaceProxy.workaround_setTally(_proposalId, _yes, _no, _abstain);
    vm.warp(block.timestamp + daoSpaceProxy.votingSettings().duration + 1);

    // it returns false
    assertFalse(daoSpaceProxy.isSupportThresholdReached(_proposalId));
  }

  function test_IsSupportThresholdReached_WhenTheYesVotesAreNotGreaterThanThePercentageSupportThreshold(
    uint256 _yes,
    uint256 _no,
    uint256 _abstain,
    uint256 _slowPathPercentageThreshold
  ) external whenTheProposalVotingModeIsUsingTheSlowPath {
    // set up
    _yes = bound(_yes, 0, 1e3);
    _no = bound(_no, 0, 1e3);
    _abstain = bound(_abstain, 0, 1e3);
    _slowPathPercentageThreshold = bound(_slowPathPercentageThreshold, 1, daoSpaceProxy.RATIO_BASE());
    vm.assume(
      (daoSpaceProxy.RATIO_BASE() - (_slowPathPercentageThreshold - 1)) * _yes
        <= (_slowPathPercentageThreshold - 1) * _no
    );
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      0,
      _initialEditorSpaceId,
      block.timestamp,
      block.timestamp + daoSpaceProxy.votingSettings().duration,
      IDAOSpace.VotingMode.Slow,
      _slowPathPercentageThreshold,
      daoSpaceProxy.votingSettings().quorum,
      new IDAOSpace.Action[](0)
    );
    daoSpaceProxy.workaround_setTally(_proposalId, _yes, _no, _abstain);
    vm.warp(block.timestamp + daoSpaceProxy.votingSettings().duration + 1);

    // it returns false
    assertFalse(daoSpaceProxy.isSupportThresholdReached(_proposalId));
  }

  function test_IsSupportThresholdReached_WhenTheYesVotesAreGreaterThanThePercentageSupportThreshold(
    uint256 _yes,
    uint256 _no,
    uint256 _abstain,
    uint256 _slowPathPercentageThreshold
  ) external whenTheProposalVotingModeIsUsingTheSlowPath {
    // set up
    _yes = bound(_yes, 0, 1e3);
    _no = bound(_no, 0, 1e3);
    _abstain = bound(_abstain, 0, 1e3);
    _slowPathPercentageThreshold = bound(_slowPathPercentageThreshold, 1, daoSpaceProxy.RATIO_BASE());
    vm.assume(
      (daoSpaceProxy.RATIO_BASE() - (_slowPathPercentageThreshold - 1)) * _yes
        > (_slowPathPercentageThreshold - 1) * _no
    );
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      0,
      _initialEditorSpaceId,
      block.timestamp,
      block.timestamp + daoSpaceProxy.votingSettings().duration,
      IDAOSpace.VotingMode.Slow,
      _slowPathPercentageThreshold,
      daoSpaceProxy.votingSettings().quorum,
      new IDAOSpace.Action[](0)
    );
    daoSpaceProxy.workaround_setTally(_proposalId, _yes, _no, _abstain);
    vm.warp(block.timestamp + daoSpaceProxy.votingSettings().duration + 1);

    // it returns true
    assertTrue(daoSpaceProxy.isSupportThresholdReached(_proposalId));
  }

  function test_IsSupportThresholdReached_WhenTheYesVotesAreNotGreaterThanTheFlatSupportThreshold(
    uint256 _yes,
    uint256 _fastPathFlatThreshold
  ) external whenTheProposalVotingModeIsUsingTheFastPath {
    // set up
    _fastPathFlatThreshold = bound(_fastPathFlatThreshold, 1, 1e3);
    _yes = bound(_yes, 0, 1e3);
    vm.assume(_yes <= (_fastPathFlatThreshold - 1));
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      0,
      _initialEditorSpaceId,
      block.timestamp,
      block.timestamp + daoSpaceProxy.votingSettings().duration,
      IDAOSpace.VotingMode.Fast,
      _fastPathFlatThreshold,
      daoSpaceProxy.votingSettings().quorum,
      new IDAOSpace.Action[](0)
    );
    daoSpaceProxy.workaround_setTally(_proposalId, _yes, 0, 0);

    // it returns false
    assertFalse(daoSpaceProxy.isSupportThresholdReached(_proposalId));
  }

  function test_IsSupportThresholdReached_WhenTheYesVotesAreGreaterThanTheFlatSupportThreshold(
    uint256 _yes,
    uint256 _fastPathFlatThreshold
  ) external whenTheProposalVotingModeIsUsingTheFastPath {
    // set up
    _fastPathFlatThreshold = bound(_fastPathFlatThreshold, 1, 1e3);
    _yes = bound(_yes, 0, 1e3);
    vm.assume(_yes > (_fastPathFlatThreshold - 1));
    daoSpaceProxy.workaround_createProposal(
      _proposalId,
      false,
      0,
      _initialEditorSpaceId,
      block.timestamp,
      block.timestamp + daoSpaceProxy.votingSettings().duration,
      IDAOSpace.VotingMode.Fast,
      _fastPathFlatThreshold,
      daoSpaceProxy.votingSettings().quorum,
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

  function _createSlowPathProposalToAddEditor() internal view returns (bytes memory) {
    IDAOSpace.VotingMode votingMode = IDAOSpace.VotingMode.Slow;
    IDAOSpace.Action[] memory actions = new IDAOSpace.Action[](1);
    bytes16 randomCallerSpaceId = _getSpaceId(_randomCaller);
    actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addEditor, (randomCallerSpaceId))
    });
    return abi.encode(_proposalId, votingMode, actions);
  }

  /// @dev valid proposal because action is fast path valid
  function _createFastPathProposalToAddMember() internal view returns (bytes memory) {
    IDAOSpace.VotingMode votingMode = IDAOSpace.VotingMode.Fast;
    IDAOSpace.Action[] memory actions = new IDAOSpace.Action[](1);
    bytes16 randomCallerSpaceId = _getSpaceId(_randomCaller);
    actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addMember, (randomCallerSpaceId))
    });
    return abi.encode(_proposalId, votingMode, actions);
  }

  /// @dev invalid proposal because it attempts to perform two actions
  function _createFastPathProposalToAddTwoMembers() internal view returns (bytes memory) {
    IDAOSpace.VotingMode votingMode = IDAOSpace.VotingMode.Fast;
    IDAOSpace.Action[] memory actions = new IDAOSpace.Action[](2);
    bytes16 randomCallerSpaceId = _getSpaceId(_randomCaller);
    actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addMember, (randomCallerSpaceId))
    });
    actions[1] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addMember, (randomCallerSpaceId))
    });
    return abi.encode(_proposalId, votingMode, actions);
  }

  /// @dev invalid proposal because the action is not fast path valid
  function _createFastPathProposalToAddEditor() internal view returns (bytes memory) {
    IDAOSpace.VotingMode votingMode = IDAOSpace.VotingMode.Fast;
    IDAOSpace.Action[] memory actions = new IDAOSpace.Action[](1);
    actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addEditor, (_getSpaceId(_randomCaller)))
    });
    return abi.encode(_proposalId, votingMode, actions);
  }

  /// @dev invalid target because the action attempts to write in another contract
  function _createFastPathProposalToAddMemberOnAnotherContract() internal view returns (bytes memory) {
    IDAOSpace.VotingMode votingMode = IDAOSpace.VotingMode.Fast;
    IDAOSpace.Action[] memory actions = new IDAOSpace.Action[](1);
    actions[0] = IDAOSpace.Action({
      to: address(this), value: 0, data: abi.encodeCall(IDAOSpace.addMember, (_getSpaceId(_randomCaller)))
    });
    return abi.encode(_proposalId, votingMode, actions);
  }

  /// @dev invalid funds transfer because the action entails a funds transfer
  function _createFastPathProposalToAddMemberAndMoveValue() internal view returns (bytes memory) {
    IDAOSpace.VotingMode votingMode = IDAOSpace.VotingMode.Fast;
    IDAOSpace.Action[] memory actions = new IDAOSpace.Action[](1);
    actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 1, data: abi.encodeCall(IDAOSpace.addMember, (_getSpaceId(_randomCaller)))
    });
    return abi.encode(_proposalId, votingMode, actions);
  }

  function _createVoteForProposal(IDAOSpace.VoteOption _votingOption) internal view returns (bytes memory) {
    return abi.encode(_proposalId, _votingOption);
  }

  /// @dev Don't incrememnt nonce here to keep later lookup easier
  function _getSpaceId(address _account) internal view returns (bytes16 _spaceId) {
    return bytes16(keccak256(abi.encodePacked('grc20.space', _account, uint256(0), block.chainid)));
  }
}
