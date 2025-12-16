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
    _votingSettings = IDAOSpace.VotingSettings({
      slowPathPercentageThreshold: 5e5, fastPathFlatThreshold: 1, quorum: 1, duration: 2 days
    });
    _initialEditors = new address[](1);
    _initialEditors[0] = _initialEditor;
    _initialMembers = new address[](1);
    _initialMembers[0] = _initialMember;

    // proxy set up
    daoSpaceImplementation = new MockDAOSpace();
    daoSpaceBeacon = UnsafeUpgrades.deployBeacon(address(daoSpaceImplementation), _owner);

    // get predicted DAO Space address for external calls and event emissions
    address predictedDAOSpaceProxy = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));

    // when delegate called
    _mockRegisterSpaceId(_spaceRegistry);

    // it calls enter on the spaceRegistry with the EDITOR_ADDED action
    _mockEnter(
      _spaceRegistry,
      predictedDAOSpaceProxy,
      predictedDAOSpaceProxy,
      ActionsConstants.EDITOR_ADDED,
      bytes32(bytes20(_initialEditor)),
      ''
    );

    // it calls enter on the spaceRegistry with the MEMBER_ADDED action
    _mockEnter(
      _spaceRegistry,
      predictedDAOSpaceProxy,
      predictedDAOSpaceProxy,
      ActionsConstants.MEMBER_ADDED,
      bytes32(bytes20(_initialMember)),
      ''
    );

    // when deployed
    daoSpaceProxy = MockDAOSpace(
      UnsafeUpgrades.deployBeaconProxy(
        daoSpaceBeacon,
        abi.encodeCall(
          IDAOSpace.initialize, (abi.encode(_spaceRegistry, _votingSettings, _initialEditors, _initialMembers))
        )
      )
    );
  }

  /// CONSTANTS ///

  function test_Constants_WhenDeployed() external view {
    // it sets MINIMUM_VOTING_DURATION to 2 days
    assertEq(daoSpaceProxy.MINIMUM_VOTING_DURATION(), 2 days);

    // it sets RATIO_BASE to 10e6
    assertEq(daoSpaceProxy.RATIO_BASE(), 10e6);

    // it sets SPACE_REGISTRY to keccak256('SPACE_REGISTRY')
    assertEq(daoSpaceProxy.SPACE_REGISTRY(), keccak256('SPACE_REGISTRY'));

    // it sets EDITOR to keccak256('EDITOR')
    assertEq(daoSpaceProxy.EDITOR(), keccak256('EDITOR'));

    // it sets MEMBER to keccak256('MEMBER')
    assertEq(daoSpaceProxy.MEMBER(), keccak256('MEMBER'));

    // it sets DAO to keccak256('DAO')
    assertEq(daoSpaceProxy.DAO(), keccak256('DAO'));
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

  function test_Initialize_WhenDelegateCalled(address __spaceRegistry) external whenDelegateCalled {
    _assumeFuzzable(__spaceRegistry);

    // get predicted DAO Space address for external calls and event emissions
    address predictedDAOSpaceProxy = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));

    // it calls spaceRegistry to register space ID
    _mockRegisterSpaceId(__spaceRegistry);

    // it calls enter on the spaceRegistry with the EDITOR_ADDED action
    _mockEnter(
      __spaceRegistry,
      predictedDAOSpaceProxy,
      predictedDAOSpaceProxy,
      ActionsConstants.EDITOR_ADDED,
      bytes32(bytes20(_initialEditor)),
      ''
    );

    // it calls enter on the spaceRegistry with the MEMBER_ADDED action
    _mockEnter(
      __spaceRegistry,
      predictedDAOSpaceProxy,
      predictedDAOSpaceProxy,
      ActionsConstants.MEMBER_ADDED,
      bytes32(bytes20(_initialMember)),
      ''
    );

    // when delegate called
    daoSpaceProxy = MockDAOSpace(
      UnsafeUpgrades.deployBeaconProxy(
        daoSpaceBeacon,
        abi.encodeCall(
          IDAOSpace.initialize, (abi.encode(__spaceRegistry, _votingSettings, _initialEditors, _initialMembers))
        )
      )
    );

    // it sets the spaceRegistry
    assertEq(address(daoSpaceProxy.spaceRegistry()), __spaceRegistry);

    // it sets the voting settings
    (uint256 slowPathPercentageThreshold, uint256 fastPathFlatThreshold, uint256 quorum, uint256 duration) =
      daoSpaceProxy.votingSettings();
    assertEq(slowPathPercentageThreshold, _votingSettings.slowPathPercentageThreshold);
    assertEq(fastPathFlatThreshold, _votingSettings.fastPathFlatThreshold);
    assertEq(quorum, _votingSettings.quorum);
    assertEq(duration, _votingSettings.duration);

    // it grants the new editor the EDITOR role
    assertEq(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _initialEditor), true);

    // it grants the new member the MEMBER role
    assertEq(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _initialMember), true);

    // it grants itself the DAO role
    assertEq(daoSpaceProxy.hasRole(daoSpaceProxy.DAO(), address(daoSpaceProxy)), true);

    // it sets addMember as a valid fast path action
    assertEq(daoSpaceProxy.actionIsFastPathValid(IDAOSpace.addMember.selector), true);

    // it sets removeMember as a valid fast path action
    assertEq(daoSpaceProxy.actionIsFastPathValid(IDAOSpace.removeMember.selector), true);

    // it sets publish as a valid fast path action
    assertEq(daoSpaceProxy.actionIsFastPathValid(IDAOSpace.publish.selector), true);

    // it sets flag as a valid fast path action
    assertEq(daoSpaceProxy.actionIsFastPathValid(IDAOSpace.flag.selector), true);

    // it sets unflag as a valid fast path action
    assertEq(daoSpaceProxy.actionIsFastPathValid(IDAOSpace.unflag.selector), true);
  }

  function test_Initialize_WhenDelegateCalledAgain(address __spaceRegistry) external whenDelegateCalled {
    _assumeFuzzable(__spaceRegistry);

    // get predicted DAO Space address for external calls and event emissions
    address predictedDAOSpaceProxy = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));

    // it calls spaceRegistry to register space ID
    _mockRegisterSpaceId(__spaceRegistry);

    // it calls enter on the spaceRegistry with the EDITOR_ADDED action
    _mockEnter(
      __spaceRegistry,
      predictedDAOSpaceProxy,
      predictedDAOSpaceProxy,
      ActionsConstants.EDITOR_ADDED,
      bytes32(bytes20(_initialEditor)),
      ''
    );

    // it calls enter on the spaceRegistry with the MEMBER_ADDED action
    _mockEnter(
      __spaceRegistry,
      predictedDAOSpaceProxy,
      predictedDAOSpaceProxy,
      ActionsConstants.MEMBER_ADDED,
      bytes32(bytes20(_initialMember)),
      ''
    );

    // when delegate called
    daoSpaceProxy = MockDAOSpace(
      UnsafeUpgrades.deployBeaconProxy(
        daoSpaceBeacon,
        abi.encodeCall(
          IDAOSpace.initialize, (abi.encode(__spaceRegistry, _votingSettings, _initialEditors, _initialMembers))
        )
      )
    );

    // it reverts with InvalidInitialization
    vm.expectRevert(Initializable.InvalidInitialization.selector);

    // when delegate called again
    daoSpaceProxy.initialize(abi.encode(__spaceRegistry, _votingSettings, _initialEditors, _initialMembers));
  }

  function test_Initialize_WhenCalled() external {
    // it reverts with InvalidInitialization
    vm.expectRevert(Initializable.InvalidInitialization.selector);

    // when called again
    daoSpaceProxy.initialize(abi.encode(_spaceRegistry, _votingSettings, _initialEditors, _initialMembers));
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

  function test_Write_When_fromSpaceIsNotAMemberOrEditor(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_CREATED
    whenTheVotingModeIsSlow
  {
    // it reverts with InvalidFromSpace
    vm.expectRevert(IDAOSpace.InvalidFromSpace.selector);

    bytes memory proposalData = _createSlowPathProposalToAddEditor();
    daoSpaceProxy.write(_randomCaller, ActionsConstants.PROPOSAL_CREATED, _topic, proposalData);
  }

  function test_Write_When_createProposalParamsAreValid(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_CREATED
    whenTheVotingModeIsSlow
  {
    // get initial proposal count
    uint256 initialProposalCounter = daoSpaceProxy.proposalCounter();

    // when called
    bytes memory proposalData = _createSlowPathProposalToAddEditor();
    daoSpaceProxy.write(_initialEditor, ActionsConstants.PROPOSAL_CREATED, _topic, proposalData);

    // it incremments the proposal counter
    assertEq(daoSpaceProxy.proposalCounter(), initialProposalCounter + 1);

    (, IDAOSpace.ProposalParameters memory parameters,, IDAOSpace.Action[] memory actions) =
      daoSpaceProxy.getProposalInformation(initialProposalCounter);

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
    assertEq(actions[0].data, abi.encodeCall(IDAOSpace.addEditor, (_randomCaller)));
  }

  modifier whenTheVotingModeIsFast() {
    _;
  }

  function test_Write_When_fromSpaceIsNotAnEditor(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_CREATED
    whenTheVotingModeIsFast
  {
    // it reverts with InvalidFromSpace
    vm.expectRevert(IDAOSpace.InvalidFromSpace.selector);

    bytes memory proposalData = _createFastPathProposalToAddMember();
    daoSpaceProxy.write(_randomCaller, ActionsConstants.PROPOSAL_CREATED, _topic, proposalData);
  }

  function test_Write_When_fromSpaceIsAFlaggedEditor(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_CREATED
    whenTheVotingModeIsFast
  {
    daoSpaceProxy.workaround_setEditorToFlagged(_initialEditor, true);

    // it reverts with EditorFlagged
    vm.expectRevert(IDAOSpace.EditorFlagged.selector);

    bytes memory proposalData = _createFastPathProposalToAddMember();
    daoSpaceProxy.write(_initialEditor, ActionsConstants.PROPOSAL_CREATED, _topic, proposalData);
  }

  function test_Write_WhenTheDecodedProposalActionIsNotLimitedToOneCall(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_CREATED
    whenTheVotingModeIsFast
  {
    // it reverts with OneActionForFastPath
    vm.expectRevert(IDAOSpace.OneActionForFastPath.selector);

    bytes memory proposalData = _createFastPathProposalToAddTwoMembers();
    daoSpaceProxy.write(_initialEditor, ActionsConstants.PROPOSAL_CREATED, _topic, proposalData);
  }

  function test_Write_WhenTheFunctionSelectorOfTheDecodedProposalActionIsNotFastPathValid(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_CREATED
    whenTheVotingModeIsFast
  {
    // it reverts with InvalidAction
    vm.expectRevert(IDAOSpace.InvalidAction.selector);

    bytes memory proposalData = _createFastPathProposalToAddEditor();
    daoSpaceProxy.write(_initialEditor, ActionsConstants.PROPOSAL_CREATED, _topic, proposalData);
  }

  function test_Write_When_createProposalParamsAreValid_WhenTheVotingModeIsFast(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_CREATED
    whenTheVotingModeIsFast
  {
    // get initial proposal count
    uint256 initialProposalCounter = daoSpaceProxy.proposalCounter();

    // when called
    bytes memory proposalData = _createFastPathProposalToAddMember();
    daoSpaceProxy.write(_initialEditor, ActionsConstants.PROPOSAL_CREATED, _topic, proposalData);

    // it incremments the proposal counter
    assertEq(daoSpaceProxy.proposalCounter(), initialProposalCounter + 1);

    (, IDAOSpace.ProposalParameters memory parameters,, IDAOSpace.Action[] memory actions) =
      daoSpaceProxy.getProposalInformation(initialProposalCounter);

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
    assertEq(actions[0].data, abi.encodeCall(IDAOSpace.addMember, (_randomCaller)));
  }

  /// WRITE - PROPOSAL_VOTED ///

  modifier when_actionEqualsPROPOSAL_VOTED() {
    _;
  }

  function test_Write_WhenTheProposalStartDateEqualsZero(
    bytes32 _topic,
    uint256 _voteOption
  ) external whenCalledBySpaceRegistry when_actionEqualsPROPOSAL_VOTED {
    _voteOption = bound(_voteOption, 1, 3);

    // it reverts with CanNotVote
    vm.expectRevert(IDAOSpace.CanNotVote.selector);

    bytes memory voteData = _createVoteForFirstProposal(IDAOSpace.VoteOption(_voteOption));
    daoSpaceProxy.write(_initialEditor, ActionsConstants.PROPOSAL_VOTED, _topic, voteData);
  }

  function test_Write_WhenTheBlockTimestampIsGreaterThanTheLastDate(
    bytes32 _topic,
    uint256 _voteOption
  ) external whenCalledBySpaceRegistry when_actionEqualsPROPOSAL_VOTED {
    _voteOption = bound(_voteOption, 1, 3);

    // proposal set up
    daoSpaceProxy.workaround_createProposal(
      0, block.timestamp, block.timestamp - 1, IDAOSpace.VotingMode.Slow, 1, 1, new IDAOSpace.Action[](0), false
    );

    // it reverts with CanNotVote
    vm.expectRevert(IDAOSpace.CanNotVote.selector);

    bytes memory voteData = _createVoteForFirstProposal(IDAOSpace.VoteOption(_voteOption));
    daoSpaceProxy.write(_initialEditor, ActionsConstants.PROPOSAL_VOTED, _topic, voteData);
  }

  function test_Write_WhenTheProposalHasBeenExecuted(
    bytes32 _topic,
    uint256 _voteOption
  ) external whenCalledBySpaceRegistry when_actionEqualsPROPOSAL_VOTED {
    _voteOption = bound(_voteOption, 1, 3);

    // proposal set up
    daoSpaceProxy.workaround_createProposal(
      0, block.timestamp, block.timestamp + 1, IDAOSpace.VotingMode.Slow, 1, 1, new IDAOSpace.Action[](0), true
    );

    // it reverts with CanNotVote
    vm.expectRevert(IDAOSpace.CanNotVote.selector);

    bytes memory voteData = _createVoteForFirstProposal(IDAOSpace.VoteOption(_voteOption));
    daoSpaceProxy.write(_initialEditor, ActionsConstants.PROPOSAL_VOTED, _topic, voteData);
  }

  function test_Write_WhenTheVoteOptionEqualsNone(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_VOTED
  {
    // proposal set up
    daoSpaceProxy.workaround_createProposal(
      0, block.timestamp, block.timestamp + 1, IDAOSpace.VotingMode.Slow, 1, 1, new IDAOSpace.Action[](0), false
    );

    // it reverts with CanNotVote
    vm.expectRevert(IDAOSpace.CanNotVote.selector);

    bytes memory voteData = _createVoteForFirstProposal(IDAOSpace.VoteOption(0));
    daoSpaceProxy.write(_initialEditor, ActionsConstants.PROPOSAL_VOTED, _topic, voteData);
  }

  function test_Write_WhenThe_fromSpaceIsNotAnEditor(
    bytes32 _topic,
    uint256 _voteOption
  ) external whenCalledBySpaceRegistry when_actionEqualsPROPOSAL_VOTED {
    _voteOption = bound(_voteOption, 1, 3);

    // proposal set up
    daoSpaceProxy.workaround_createProposal(
      0, block.timestamp, block.timestamp + 1, IDAOSpace.VotingMode.Slow, 1, 1, new IDAOSpace.Action[](0), false
    );

    // it reverts with CanNotVote
    vm.expectRevert(IDAOSpace.CanNotVote.selector);

    bytes memory voteData = _createVoteForFirstProposal(IDAOSpace.VoteOption(_voteOption));
    daoSpaceProxy.write(_randomCaller, ActionsConstants.PROPOSAL_VOTED, _topic, voteData);
  }

  modifier when_voteParamsAreValid() {
    _;
  }

  function test_Write_When_voteParamsAreValid(
    bytes32 _topic,
    uint256 _voteOption
  ) external whenCalledBySpaceRegistry when_actionEqualsPROPOSAL_VOTED when_voteParamsAreValid {
    _voteOption = bound(_voteOption, 1, 3);

    // proposal set up
    daoSpaceProxy.workaround_createProposal(
      0, block.timestamp, block.timestamp + 1, IDAOSpace.VotingMode.Slow, 1, 1, new IDAOSpace.Action[](0), false
    );

    // vote
    bytes memory voteData = _createVoteForFirstProposal(IDAOSpace.VoteOption(_voteOption));
    daoSpaceProxy.write(_initialEditor, ActionsConstants.PROPOSAL_VOTED, _topic, voteData);

    // it stores the current _fromSpace vote
    IDAOSpace.VoteOption storedVoteOption = daoSpaceProxy.getProposalVote(0, _initialEditor);
    assertEq(uint256(storedVoteOption), _voteOption);
  }

  function test_Write_WhenTheFormer_fromSpaceVoteEqualsYes(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_VOTED
    when_voteParamsAreValid
  {
    // proposal set up
    daoSpaceProxy.workaround_createProposal(
      0, block.timestamp, block.timestamp + 1, IDAOSpace.VotingMode.Slow, 1, 1, new IDAOSpace.Action[](0), false
    );
    // set inital vote to yes and tally
    daoSpaceProxy.workaround_setFormerVote(0, _initialEditor, IDAOSpace.VoteOption(2));
    (,, IDAOSpace.Tally memory tally,) = daoSpaceProxy.getProposalInformation(0);
    assertEq(tally.yes, 1);

    // vote no
    bytes memory voteData = _createVoteForFirstProposal(IDAOSpace.VoteOption(3));
    daoSpaceProxy.write(_initialEditor, ActionsConstants.PROPOSAL_VOTED, _topic, voteData);

    // it decreases the yes vote tally by one
    (,, tally,) = daoSpaceProxy.getProposalInformation(0);
    assertEq(tally.yes, 0);
  }

  function test_Write_WhenTheFormer_fromSpaceVoteEqualsNo(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_VOTED
    when_voteParamsAreValid
  {
    // proposal set up
    daoSpaceProxy.workaround_createProposal(
      0, block.timestamp, block.timestamp + 1, IDAOSpace.VotingMode.Slow, 1, 1, new IDAOSpace.Action[](0), false
    );
    // set inital vote to no and tally
    daoSpaceProxy.workaround_setFormerVote(0, _initialEditor, IDAOSpace.VoteOption(3));
    (,, IDAOSpace.Tally memory tally,) = daoSpaceProxy.getProposalInformation(0);
    assertEq(tally.no, 1);

    // vote yes
    bytes memory voteData = _createVoteForFirstProposal(IDAOSpace.VoteOption(2));
    daoSpaceProxy.write(_initialEditor, ActionsConstants.PROPOSAL_VOTED, _topic, voteData);

    // it decreases the no vote tally by one
    (,, tally,) = daoSpaceProxy.getProposalInformation(0);
    assertEq(tally.no, 0);
  }

  function test_Write_WhenTheFormer_fromSpaceVoteEqualsAbstain(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_VOTED
    when_voteParamsAreValid
  {
    // proposal set up
    daoSpaceProxy.workaround_createProposal(
      0, block.timestamp, block.timestamp + 1, IDAOSpace.VotingMode.Slow, 1, 1, new IDAOSpace.Action[](0), false
    );
    // set inital vote to abstain and tally
    daoSpaceProxy.workaround_setFormerVote(0, _initialEditor, IDAOSpace.VoteOption(1));
    (,, IDAOSpace.Tally memory tally,) = daoSpaceProxy.getProposalInformation(0);
    assertEq(tally.abstain, 1);

    // vote yes
    bytes memory voteData = _createVoteForFirstProposal(IDAOSpace.VoteOption(2));
    daoSpaceProxy.write(_initialEditor, ActionsConstants.PROPOSAL_VOTED, _topic, voteData);

    // it decreases the abstain vote tally by one
    (,, tally,) = daoSpaceProxy.getProposalInformation(0);
    assertEq(tally.abstain, 0);
  }

  function test_Write_WhenTheCurrent_fromSpaceVoteEqualsYes(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_VOTED
    when_voteParamsAreValid
  {
    // proposal set up
    daoSpaceProxy.workaround_createProposal(
      0, block.timestamp, block.timestamp + 1, IDAOSpace.VotingMode.Slow, 1, 1, new IDAOSpace.Action[](0), false
    );

    // vote yes
    bytes memory voteData = _createVoteForFirstProposal(IDAOSpace.VoteOption(2));
    daoSpaceProxy.write(_initialEditor, ActionsConstants.PROPOSAL_VOTED, _topic, voteData);

    // it increases the yes vote tally by one
    (,, IDAOSpace.Tally memory tally,) = daoSpaceProxy.getProposalInformation(0);
    assertEq(tally.yes, 1);
  }

  function test_Write_WhenTheCurrent_fromSpaceVoteEqualsNo(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_VOTED
    when_voteParamsAreValid
  {
    // proposal set up
    daoSpaceProxy.workaround_createProposal(
      0, block.timestamp, block.timestamp + 1, IDAOSpace.VotingMode.Slow, 1, 1, new IDAOSpace.Action[](0), false
    );

    // vote no
    bytes memory voteData = _createVoteForFirstProposal(IDAOSpace.VoteOption(3));
    daoSpaceProxy.write(_initialEditor, ActionsConstants.PROPOSAL_VOTED, _topic, voteData);

    // it increases the no vote tally by one
    (,, IDAOSpace.Tally memory tally,) = daoSpaceProxy.getProposalInformation(0);
    assertEq(tally.no, 1);
  }

  function test_Write_WhenTheCurrent_fromSpaceVoteEqualsAbstain(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_VOTED
    when_voteParamsAreValid
  {
    // proposal set up
    daoSpaceProxy.workaround_createProposal(
      0, block.timestamp, block.timestamp + 1, IDAOSpace.VotingMode.Slow, 1, 1, new IDAOSpace.Action[](0), false
    );

    // vote abstain
    bytes memory voteData = _createVoteForFirstProposal(IDAOSpace.VoteOption(1));
    daoSpaceProxy.write(_initialEditor, ActionsConstants.PROPOSAL_VOTED, _topic, voteData);

    // it increases the abstain vote tally by one
    (,, IDAOSpace.Tally memory tally,) = daoSpaceProxy.getProposalInformation(0);
    assertEq(tally.abstain, 1);
  }

  modifier whenTheProposalVotingModeIsUsingTheFastPath() {
    _;
  }

  function test_Write_WhenTheCurrent_fromSpaceVoteEqualsNo_WhenTheProposalVotingModeIsUsingTheFastPath(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_VOTED
    when_voteParamsAreValid
    whenTheProposalVotingModeIsUsingTheFastPath
  {
    // proposal set up
    daoSpaceProxy.workaround_createProposal(
      0, block.timestamp, block.timestamp + 1e5, IDAOSpace.VotingMode.Fast, 1, 1, new IDAOSpace.Action[](0), false
    );

    (, IDAOSpace.ProposalParameters memory parameters,,) = daoSpaceProxy.getProposalInformation(0);
    assertEq(uint256(parameters.votingMode), uint256(IDAOSpace.VotingMode.Fast));
    assertEq(parameters.supportThreshold, 1);
    assertEq(parameters.startDate, block.timestamp);
    assertEq(parameters.lastDate, block.timestamp + 1e5);

    // warp forwards to ensure start date is reset
    vm.warp(block.timestamp + 100);

    // vote no
    bytes memory voteData = _createVoteForFirstProposal(IDAOSpace.VoteOption(3));
    daoSpaceProxy.write(_initialEditor, ActionsConstants.PROPOSAL_VOTED, _topic, voteData);

    (, parameters,,) = daoSpaceProxy.getProposalInformation(0);
    (uint256 slowPathPercentageThreshold,,, uint256 duration) = daoSpaceProxy.votingSettings();

    // it updates the proposal voting mode to the slow path
    assertEq(uint256(parameters.votingMode), uint256(IDAOSpace.VotingMode.Slow));

    // it updates the proposal support threshold to the slow path percentage threshold
    assertEq(parameters.supportThreshold, slowPathPercentageThreshold);

    // it updates the proposal start date to block.timestamp
    assertEq(parameters.startDate, block.timestamp);

    // it updates the proposal last date to block.timestamp plus votingSettings.duration
    assertEq(parameters.lastDate, block.timestamp + duration);
  }

  modifier whenTheCurrent_fromSpaceVoteEqualsYes() {
    _;
  }

  function test_Write_WhenTheProposalCanBeExecuted(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_VOTED
    when_voteParamsAreValid
    whenTheProposalVotingModeIsUsingTheFastPath
    whenTheCurrent_fromSpaceVoteEqualsYes
  {
    // proposal set up to add randomCaller as an editor
    IDAOSpace.Action[] memory actions = new IDAOSpace.Action[](1);
    actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addEditor, (_randomCaller))
    });
    daoSpaceProxy.workaround_createProposal(
      0, block.timestamp, block.timestamp + 1e5, IDAOSpace.VotingMode.Fast, 0, 1, actions, false
    );

    assertEq(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _randomCaller), false);

    // it calls enter on the spaceRegistry with the EDITOR_ADDED action
    _mockEnter(
      _spaceRegistry,
      address(daoSpaceProxy),
      address(daoSpaceProxy),
      ActionsConstants.EDITOR_ADDED,
      bytes32(bytes20(_randomCaller)),
      ''
    );

    // vote yes
    bytes memory voteData = _createVoteForFirstProposal(IDAOSpace.VoteOption(2));
    daoSpaceProxy.write(_initialEditor, ActionsConstants.PROPOSAL_VOTED, _topic, voteData);

    // it loops over the stored proposal actions and performs the external calls
    assertEq(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _randomCaller), true);
  }

  /// WRITE - EXECUTE PROPOSAL ///

  modifier when_actionEqualsPROPOSAL_EXECUTED() {
    _;
  }

  function test_Write_WhenTheProposalHasAlreadyBeenExecuted(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_EXECUTED
  {
    // set up proposal
    daoSpaceProxy.workaround_createProposal(
      0, block.timestamp, block.timestamp + 1, IDAOSpace.VotingMode.Fast, 2, 1, new IDAOSpace.Action[](0), true
    );

    // it reverts with CanNotExecute
    vm.expectRevert(IDAOSpace.CanNotExecute.selector);

    bytes memory executeData = abi.encode(0);
    daoSpaceProxy.write(_initialEditor, ActionsConstants.PROPOSAL_EXECUTED, _topic, executeData);
  }

  function test_Write_WhenTheProposalStartDateEqualsZero_When_actionEqualsPROPOSAL_EXECUTED(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_EXECUTED
  {
    // it reverts with CanNotExecute
    vm.expectRevert(IDAOSpace.CanNotExecute.selector);

    bytes memory executeData = abi.encode(0);
    daoSpaceProxy.write(_initialEditor, ActionsConstants.PROPOSAL_EXECUTED, _topic, executeData);
  }

  function test_Write_WhenTheSupportThresholdHasNotBeenReached(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_EXECUTED
  {
    // set up proposal
    daoSpaceProxy.workaround_createProposal(
      0, block.timestamp, block.timestamp + 1, IDAOSpace.VotingMode.Slow, 2, 1, new IDAOSpace.Action[](0), false
    );

    vm.warp(block.timestamp + 2);

    // it reverts with CanNotExecute
    vm.expectRevert(IDAOSpace.CanNotExecute.selector);

    bytes memory executeData = abi.encode(0);
    daoSpaceProxy.write(_initialEditor, ActionsConstants.PROPOSAL_EXECUTED, _topic, executeData);
  }

  modifier whenTheProposalCanBeExecuted() {
    _;
  }

  function test_Write_WhenTheProposalCanBeExecuted_WhenTheProposalCanBeExecuted(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_EXECUTED
    whenTheProposalCanBeExecuted
  {
    // proposal set up to add randomCaller as an editor
    IDAOSpace.Action[] memory actions = new IDAOSpace.Action[](1);
    actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addEditor, (_randomCaller))
    });
    daoSpaceProxy.workaround_createProposal(
      0, block.timestamp, block.timestamp + 1, IDAOSpace.VotingMode.Slow, 0, 1, actions, false
    );

    // set vote to yes
    daoSpaceProxy.workaround_setFormerVote(0, _initialEditor, IDAOSpace.VoteOption(2));

    // warp to after last date
    vm.warp(block.timestamp + 2);

    assertEq(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _randomCaller), false);

    // it calls enter on the spaceRegistry with the EDITOR_ADDED action
    _mockEnter(
      _spaceRegistry,
      address(daoSpaceProxy),
      address(daoSpaceProxy),
      ActionsConstants.EDITOR_ADDED,
      bytes32(bytes20(_randomCaller)),
      ''
    );

    bytes memory executeData = abi.encode(0);
    daoSpaceProxy.write(_initialEditor, ActionsConstants.PROPOSAL_EXECUTED, _topic, executeData);

    // it loops over the stored proposal actions and performs the external calls
    assertEq(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _randomCaller), true);
  }

  function test_Write_WhenAnExternalCallFails(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsPROPOSAL_EXECUTED
    whenTheProposalCanBeExecuted
  {
    // proposal set up to with a deliberately faulty call
    IDAOSpace.Action[] memory actions = new IDAOSpace.Action[](1);
    actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(ISpaceRegistry.registerSpaceId, ())
    });
    daoSpaceProxy.workaround_createProposal(
      0, block.timestamp, block.timestamp + 1, IDAOSpace.VotingMode.Slow, 0, 1, actions, false
    );

    // set vote to yes
    daoSpaceProxy.workaround_setFormerVote(0, _initialEditor, IDAOSpace.VoteOption(2));

    // warp to after last date
    vm.warp(block.timestamp + 2);

    // it reverts with ActionReverted
    vm.expectRevert(IDAOSpace.ActionReverted.selector);

    bytes memory executeData = abi.encode(0);
    daoSpaceProxy.write(_initialEditor, ActionsConstants.PROPOSAL_EXECUTED, _topic, executeData);
  }

  /// WRITE - SPACE_LEFT ///

  modifier when_actionEqualsSPACE_LEFT() {
    _;
  }

  function test_Write_WhenTheRoleSpecifiedIsMEMBERAndThe_fromSpaceIsAMember(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsSPACE_LEFT
  {
    assertEq(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _initialMember), true);

    // it calls enter on the spaceRegistry with the MEMBER_REMOVED action
    _mockEnter(
      _spaceRegistry,
      address(daoSpaceProxy),
      address(daoSpaceProxy),
      ActionsConstants.MEMBER_REMOVED,
      bytes32(bytes20(_initialMember)),
      ''
    );

    bytes memory leaveData = abi.encode(daoSpaceProxy.MEMBER());
    daoSpaceProxy.write(_initialMember, ActionsConstants.SPACE_LEFT, _topic, leaveData);

    // it revokes the role of MEMBER from the _fromSpace
    assertEq(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _initialMember), false);
  }

  function test_Write_WhenTheRoleSpecifiedIsEDITORAndThe_fromSpaceIsAnEditor(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsSPACE_LEFT
  {
    // Set quorum to 0 so that an editor can be removed
    daoSpaceProxy.workaround_setVotingSettings(
      IDAOSpace.VotingSettings({
        slowPathPercentageThreshold: _votingSettings.slowPathPercentageThreshold,
        fastPathFlatThreshold: _votingSettings.fastPathFlatThreshold,
        quorum: 0,
        duration: _votingSettings.duration
      })
    );

    assertEq(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _initialEditor), true);

    daoSpaceProxy.workaround_setEditorToFlagged(_initialEditor, true);
    assertEq(daoSpaceProxy.isEditorFlagged(_initialEditor), true);

    // it calls enter on the spaceRegistry with the EDITOR_REMOVED action
    _mockEnter(
      _spaceRegistry,
      address(daoSpaceProxy),
      address(daoSpaceProxy),
      ActionsConstants.EDITOR_REMOVED,
      bytes32(bytes20(_initialEditor)),
      ''
    );

    bytes memory leaveData = abi.encode(daoSpaceProxy.EDITOR());
    daoSpaceProxy.write(_initialEditor, ActionsConstants.SPACE_LEFT, _topic, leaveData);

    // it revokes the role of EDITOR from the _fromSpace
    assertEq(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _initialEditor), false);

    // it unflags the editor from using the fast path
    assertEq(daoSpaceProxy.isEditorFlagged(_initialEditor), false);
  }

  function test_Write_WhenTheRoleIsNotHeldByThe_fromSpaceOrTheRoleIsNeitherMEMBERNorEDITOR(
    bytes32 _topic,
    address _caller
  ) external whenCalledBySpaceRegistry when_actionEqualsSPACE_LEFT {
    vm.assume(_caller != _initialEditor);
    vm.assume(_caller != _initialMember);

    // it reverts with InvalidFromSpace
    // role is neither MEMBER or EDITOR
    bytes memory leaveData = abi.encode(daoSpaceProxy.DAO());
    vm.expectRevert(IDAOSpace.InvalidFromSpace.selector);
    daoSpaceProxy.write(_caller, ActionsConstants.SPACE_LEFT, _topic, leaveData);

    // _fromSpace doesn't have role
    leaveData = abi.encode(daoSpaceProxy.MEMBER());
    vm.expectRevert(IDAOSpace.InvalidFromSpace.selector);
    daoSpaceProxy.write(_initialEditor, ActionsConstants.SPACE_LEFT, _topic, leaveData);

    // _fromSpace doesn't have role
    leaveData = abi.encode(daoSpaceProxy.EDITOR());
    vm.expectRevert(IDAOSpace.InvalidFromSpace.selector);
    daoSpaceProxy.write(_initialMember, ActionsConstants.SPACE_LEFT, _topic, leaveData);
  }

  /// WRITE - FLAG EDITOR ///

  modifier when_actionEqualsEDITOR_FLAGGED() {
    _;
  }

  function test_Write_WhenThe_fromSpaceIsNotAnEditor_When_actionEqualsEDITOR_FLAGGED(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsEDITOR_FLAGGED
  {
    bytes memory flagData = abi.encode(_initialEditor);

    // it reverts with InvalidFromSpace
    vm.expectRevert(IDAOSpace.InvalidFromSpace.selector);
    daoSpaceProxy.write(_initialMember, ActionsConstants.EDITOR_FLAGGED, _topic, flagData);
  }

  function test_Write_WhenTheToBeFlaggedEditorIsNotAnEditor(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsEDITOR_FLAGGED
  {
    bytes memory flagData = abi.encode(_initialMember);

    // it reverts with NotEditor
    vm.expectRevert(IDAOSpace.NotEditor.selector);
    daoSpaceProxy.write(_initialEditor, ActionsConstants.EDITOR_FLAGGED, _topic, flagData);
  }

  function test_Write_When_leaveParamsAreValid(bytes32 _topic)
    external
    whenCalledBySpaceRegistry
    when_actionEqualsEDITOR_FLAGGED
  {
    assertEq(daoSpaceProxy.isEditorFlagged(_initialEditor), false);

    // initial editor flags themselves
    bytes memory flagData = abi.encode(_initialEditor);
    daoSpaceProxy.write(_initialEditor, ActionsConstants.EDITOR_FLAGGED, _topic, flagData);

    // it flags the editor from using the fast path
    assertEq(daoSpaceProxy.isEditorFlagged(_initialEditor), true);
  }

  /// WRITE - REVERT ///

  function test_Write_When_actionDoesNotEqualAnyExpectedConstant(
    bytes32 _action,
    bytes32 _topic,
    bytes memory _data
  ) external whenCalledBySpaceRegistry {
    vm.assume(_action != ActionsConstants.PROPOSAL_CREATED);
    vm.assume(_action != ActionsConstants.PROPOSAL_VOTED);
    vm.assume(_action != ActionsConstants.PROPOSAL_EXECUTED);
    vm.assume(_action != ActionsConstants.SPACE_LEFT);
    vm.assume(_action != ActionsConstants.EDITOR_FLAGGED);

    // it reverts with InvalidAction
    vm.expectRevert(IDAOSpace.InvalidAction.selector);
    daoSpaceProxy.write(_randomCaller, _action, _topic, _data);
  }

  function test_Write_WhenCalledByNon_spaceRegistry(
    address _caller,
    bytes32 _action,
    bytes32 _topic,
    bytes memory _data
  ) external {
    vm.assume(_caller != _spaceRegistry);

    // it reverts with InvalidCaller
    vm.expectRevert(IDAOSpace.InvalidCaller.selector);
    vm.prank(_caller);
    daoSpaceProxy.write(_randomCaller, _action, _topic, _data);
  }

  /// VERIFY ///

  function test_Verify_WhenCalled(
    address _from,
    address _to,
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data,
    bytes calldata _signature
  ) external {
    vm.prank(_from);

    // it reverts with VerifyDisabled
    vm.expectRevert(IDAOSpace.VerifyDisabled.selector);
    daoSpaceProxy.verify(_to, _action, _topic, _data, _signature);
  }

  /// ADD EDITOR ///

  modifier whenCalledByDAO() {
    vm.startPrank(address(daoSpaceProxy));
    _;
    vm.stopPrank();
  }

  function test_AddEditor_When_newEditorIsAnEditor() external whenCalledByDAO {
    // it reverts with InvalidAddressForRole
    vm.expectRevert(IDAOSpace.InvalidAddressForRole.selector);
    daoSpaceProxy.addEditor(_initialEditor);
  }

  function test_AddEditor_When_newEditorIsNotAnEditor(address _newEditor) external whenCalledByDAO {
    vm.assume(_newEditor != _initialEditor);
    assertEq(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _newEditor), false);

    uint256 totalEditorsBefore = daoSpaceProxy.totalEditors();
    assertEq(totalEditorsBefore, 1);

    // it calls enter on the spaceRegistry with the EDITOR_ADDED action
    _mockEnter(
      _spaceRegistry,
      address(daoSpaceProxy),
      address(daoSpaceProxy),
      ActionsConstants.EDITOR_ADDED,
      bytes32(bytes20(_newEditor)),
      ''
    );
    daoSpaceProxy.addEditor(_newEditor);

    // it increments totalEditors
    assertEq(daoSpaceProxy.totalEditors(), totalEditorsBefore + 1);

    // it grants _newEditor the EDITOR role
    assertEq(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _newEditor), true);
  }

  function test_AddEditor_WhenCalledByNon_DAO(address _caller, address _newEditor) external {
    vm.assume(_caller != address(daoSpaceProxy));
    vm.prank(_caller);

    // it reverts with InvalidCaller
    vm.expectRevert(IDAOSpace.InvalidCaller.selector);
    daoSpaceProxy.addEditor(_newEditor);
  }

  /// REMOVE EDITOR ///

  function test_RemoveEditor_When_oldEditorIsNotAnEditor(address _oldEditor) external whenCalledByDAO {
    vm.assume(_oldEditor != _initialEditor);

    // it reverts with InvalidAddressForRole
    vm.expectRevert(IDAOSpace.InvalidAddressForRole.selector);
    daoSpaceProxy.removeEditor(_oldEditor);
  }

  function test_RemoveEditor_WhenTheVotingSettingsQuorumIsGreaterThanTotalEditorsMinusOne() external whenCalledByDAO {
    // it reverts with InvalidSetting
    vm.expectRevert(IDAOSpace.InvalidSetting.selector);
    daoSpaceProxy.removeEditor(_initialEditor);
  }

  function test_RemoveEditor_WhenInputParamsAreValid() external whenCalledByDAO {
    // Set quorum to 0 so that an editor can be removed
    daoSpaceProxy.workaround_setVotingSettings(
      IDAOSpace.VotingSettings({
        slowPathPercentageThreshold: _votingSettings.slowPathPercentageThreshold,
        fastPathFlatThreshold: _votingSettings.fastPathFlatThreshold,
        quorum: 0,
        duration: _votingSettings.duration
      })
    );

    assertEq(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _initialEditor), true);

    // Set editor to flagged
    daoSpaceProxy.workaround_setEditorToFlagged(_initialEditor, true);
    assertEq(daoSpaceProxy.isEditorFlagged(_initialEditor), true);

    uint256 totalEditorsBefore = daoSpaceProxy.totalEditors();
    assertEq(totalEditorsBefore, 1);

    // it calls enter on the spaceRegistry with the EDITOR_REMOVED action
    _mockEnter(
      _spaceRegistry,
      address(daoSpaceProxy),
      address(daoSpaceProxy),
      ActionsConstants.EDITOR_REMOVED,
      bytes32(bytes20(_initialEditor)),
      ''
    );
    daoSpaceProxy.removeEditor(_initialEditor);

    // it decrements totalEditors
    assertEq(daoSpaceProxy.totalEditors(), totalEditorsBefore - 1);

    // it unflags the editor from using the fast path
    assertEq(daoSpaceProxy.isEditorFlagged(_initialEditor), false);

    // it removes the EDITOR role from _oldEditor
    assertEq(daoSpaceProxy.hasRole(daoSpaceProxy.EDITOR(), _initialEditor), false);
  }

  function test_RemoveEditor_WhenCalledByNon_DAO(address _caller, address _oldEditor) external {
    vm.assume(_caller != address(daoSpaceProxy));
    vm.prank(_caller);

    // it reverts with InvalidCaller
    vm.expectRevert(IDAOSpace.InvalidCaller.selector);
    daoSpaceProxy.removeEditor(_oldEditor);
  }

  /// ADD MEMBER ///

  function test_AddMember_When_newMemberIsAMember() external whenCalledByDAO {
    // it reverts with InvalidAddressForRole
    vm.expectRevert(IDAOSpace.InvalidAddressForRole.selector);
    daoSpaceProxy.addMember(_initialMember);
  }

  function test_AddMember_When_newMemberIsNotAMember(address _newMember) external whenCalledByDAO {
    vm.assume(_newMember != _initialMember);
    assertEq(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _newMember), false);

    // it calls enter on the spaceRegistry with the MEMBER_ADDED action
    _mockEnter(
      _spaceRegistry,
      address(daoSpaceProxy),
      address(daoSpaceProxy),
      ActionsConstants.MEMBER_ADDED,
      bytes32(bytes20(_newMember)),
      ''
    );
    daoSpaceProxy.addMember(_newMember);

    // it grants _newMember the MEMBER role
    assertEq(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _newMember), true);
  }

  function test_AddMember_WhenCalledByNon_DAO(address _caller, address _newMember) external {
    vm.assume(_caller != address(daoSpaceProxy));
    vm.prank(_caller);

    // it reverts with InvalidCaller
    vm.expectRevert(IDAOSpace.InvalidCaller.selector);
    daoSpaceProxy.addMember(_newMember);
  }

  /// REMVOE MEMBER ///

  function test_RemoveMember_When_oldMemberIsNotAMember(address _oldMember) external whenCalledByDAO {
    vm.assume(_oldMember != _initialMember);

    // it reverts with InvalidAddressForRole
    vm.expectRevert(IDAOSpace.InvalidAddressForRole.selector);
    daoSpaceProxy.removeMember(_oldMember);
  }

  function test_RemoveMember_When_oldMemberIsAMember() external whenCalledByDAO {
    assertEq(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _initialMember), true);

    // it calls enter on the spaceRegistry with the MEMBER_REMOVED action
    _mockEnter(
      _spaceRegistry,
      address(daoSpaceProxy),
      address(daoSpaceProxy),
      ActionsConstants.MEMBER_REMOVED,
      bytes32(bytes20(_initialMember)),
      ''
    );
    daoSpaceProxy.removeMember(_initialMember);

    // it removes the MEMBER role from _oldMember
    assertEq(daoSpaceProxy.hasRole(daoSpaceProxy.MEMBER(), _initialMember), false);
  }

  function test_RemoveMember_WhenCalledByNon_DAO(address _caller, address _oldMember) external {
    vm.assume(_caller != address(daoSpaceProxy));
    vm.prank(_caller);

    // it reverts with InvalidCaller
    vm.expectRevert(IDAOSpace.InvalidCaller.selector);
    daoSpaceProxy.removeMember(_oldMember);
  }

  /// UNFLAG EDITOR ///

  function test_UnflagEditor_When_unflaggedEditorIsNotAnEditor(address _unflaggedEditor) external whenCalledByDAO {
    vm.assume(_unflaggedEditor != _initialEditor);

    // it reverts with NotEditor
    vm.expectRevert(IDAOSpace.NotEditor.selector);
    daoSpaceProxy.unflagEditor(_unflaggedEditor);
  }

  function test_UnflagEditor_When_unflaggedEditorIsAnEditor() external whenCalledByDAO {
    daoSpaceProxy.workaround_setEditorToFlagged(_initialEditor, true);
    assertEq(daoSpaceProxy.isEditorFlagged(_initialEditor), true);

    // it calls enter on the spaceRegistry with the EDITOR_UNFLAGGED action
    _mockEnter(
      _spaceRegistry,
      address(daoSpaceProxy),
      address(daoSpaceProxy),
      ActionsConstants.EDITOR_UNFLAGGED,
      bytes32(bytes20(_initialEditor)),
      ''
    );
    daoSpaceProxy.unflagEditor(_initialEditor);

    // it unflags the editor from using the fast path
    assertEq(daoSpaceProxy.isEditorFlagged(_initialEditor), false);
  }

  function test_UnflagEditor_WhenCalledByNon_DAO(address _caller, address _unflaggedEditor) external {
    vm.assume(_caller != address(daoSpaceProxy));
    vm.prank(_caller);

    // it reverts with InvalidCaller
    vm.expectRevert(IDAOSpace.InvalidCaller.selector);
    daoSpaceProxy.unflagEditor(_unflaggedEditor);
  }

  /// PING ///

  function test_Ping_WhenCalledByDAO(bytes32 _action, bytes32 _topic, bytes calldata _data) external whenCalledByDAO {
    // it calls enter on the spaceRegistry with the input variables passed
    _mockEnter(_spaceRegistry, address(daoSpaceProxy), address(daoSpaceProxy), _action, _topic, _data);
    daoSpaceProxy.ping(_action, _topic, _data);
  }

  function test_Ping_WhenCalledByNon_DAO(
    address _caller,
    bytes32 _action,
    bytes32 _topic,
    bytes calldata _data
  ) external {
    vm.assume(_caller != address(daoSpaceProxy));
    vm.prank(_caller);

    // it reverts with InvalidCaller
    vm.expectRevert(IDAOSpace.InvalidCaller.selector);
    daoSpaceProxy.ping(_action, _topic, _data);
  }

  /// PUBLISH ///

  function test_Publish_WhenCalledByDAO(
    bytes32 _topic,
    bytes memory _editsContentUri,
    bytes memory _editsMetadata
  ) external whenCalledByDAO {
    // it calls enter on the spaceRegistry with the EDITS_PUBLISHED action
    _mockEnter(
      _spaceRegistry,
      address(daoSpaceProxy),
      address(daoSpaceProxy),
      ActionsConstants.EDITS_PUBLISHED,
      _topic,
      abi.encode(_editsContentUri, _editsMetadata)
    );
    daoSpaceProxy.publish(_topic, _editsContentUri, _editsMetadata);
  }

  function test_Publish_WhenCalledByNon_DAO(
    address _caller,
    bytes32 _topic,
    bytes memory _editsContentUri,
    bytes memory _editsMetadata
  ) external {
    vm.assume(_caller != address(daoSpaceProxy));
    vm.prank(_caller);

    // it reverts with InvalidCaller
    vm.expectRevert(IDAOSpace.InvalidCaller.selector);
    daoSpaceProxy.publish(_topic, _editsContentUri, _editsMetadata);
  }

  /// FLAG ///

  function test_Flag_WhenCalledByDAO(bytes32 _topic, bytes calldata _flaggedId) external whenCalledByDAO {
    // it calls enter on the spaceRegistry with the FLAGGED action
    _mockEnter(
      _spaceRegistry, address(daoSpaceProxy), address(daoSpaceProxy), ActionsConstants.FLAGGED, _topic, _flaggedId
    );
    daoSpaceProxy.flag(_topic, _flaggedId);
  }

  function test_Flag_WhenCalledByNon_DAO(address _caller, bytes32 _topic, bytes calldata _flaggedId) external {
    vm.assume(_caller != address(daoSpaceProxy));
    vm.prank(_caller);

    // it reverts with InvalidCaller
    vm.expectRevert(IDAOSpace.InvalidCaller.selector);
    daoSpaceProxy.flag(_topic, _flaggedId);
  }

  /// UNFLAG ///

  function test_Unflag_WhenCalledByDAO(bytes32 _topic, bytes calldata _unflaggedId) external whenCalledByDAO {
    // it calls enter on the spaceRegistry with the UNFLAGGED action
    _mockEnter(
      _spaceRegistry, address(daoSpaceProxy), address(daoSpaceProxy), ActionsConstants.UNFLAGGED, _topic, _unflaggedId
    );
    daoSpaceProxy.unflag(_topic, _unflaggedId);
  }

  function test_Unflag_WhenCalledByNon_DAO(address _caller, bytes32 _topic, bytes calldata _unflaggedId) external {
    vm.assume(_caller != address(daoSpaceProxy));
    vm.prank(_caller);

    // it reverts with InvalidCaller
    vm.expectRevert(IDAOSpace.InvalidCaller.selector);
    daoSpaceProxy.unflag(_topic, _unflaggedId);
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
    uint256 _slowPathPercentageThreshold,
    uint256 _fastPathFlatThreshold,
    uint256 _quorum,
    uint256 _duration
  ) external whenCalledByDAO {
    _slowPathPercentageThreshold = bound(_slowPathPercentageThreshold, 0, daoSpaceProxy.RATIO_BASE());
    _fastPathFlatThreshold = bound(_fastPathFlatThreshold, 0, daoSpaceProxy.totalEditors());
    _quorum = bound(_quorum, 0, daoSpaceProxy.totalEditors());
    _duration = bound(_duration, daoSpaceProxy.MINIMUM_VOTING_DURATION(), daoSpaceProxy.MINIMUM_VOTING_DURATION() * 100);
    _votingSettings.slowPathPercentageThreshold = _slowPathPercentageThreshold;
    _votingSettings.fastPathFlatThreshold = _fastPathFlatThreshold;
    _votingSettings.quorum = _quorum;
    _votingSettings.duration = _duration;

    daoSpaceProxy.updateVotingSettings(_votingSettings);

    // it updates the voting settings
    (uint256 slowPathPercentageThreshold, uint256 fastPathFlatThreshold, uint256 quorum, uint256 duration) =
      daoSpaceProxy.votingSettings();
    assertEq(slowPathPercentageThreshold, _slowPathPercentageThreshold);
    assertEq(fastPathFlatThreshold, _fastPathFlatThreshold);
    assertEq(quorum, _quorum);
    assertEq(duration, _duration);
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

  function test_Fetch_When_actionEqualsPROPOSAL_CREATED(bytes32 _topicInput, bytes calldata _data) external view {
    // it returns bytes32(proposalCounter)
    assertEq(
      daoSpaceProxy.fetch(ActionsConstants.PROPOSAL_CREATED, _topicInput, _data),
      bytes32(daoSpaceProxy.proposalCounter())
    );
  }

  function test_Fetch_When_actionEqualsPROPOSAL_VOTED(
    bytes32 _topicInput,
    uint256 _proposalId,
    uint256 _voteOption
  ) external {
    _voteOption = bound(_voteOption, 0, 3);
    bytes memory _data = abi.encode(_proposalId, IDAOSpace.VoteOption(_voteOption));

    // it returns bytes32(_proposalId)
    assertEq(daoSpaceProxy.fetch(ActionsConstants.PROPOSAL_VOTED, _topicInput, _data), bytes32(_proposalId));
  }

  function test_Fetch_When_actionEqualsPROPOSAL_EXECUTED(bytes32 _topicInput, uint256 _proposalId) external {
    bytes memory _data = abi.encode(_proposalId);

    // it returns bytes32(_proposalId)
    assertEq(daoSpaceProxy.fetch(ActionsConstants.PROPOSAL_EXECUTED, _topicInput, _data), bytes32(_proposalId));
  }

  function test_Fetch_When_actionEqualsSPACE_LEFT(bytes32 _topicInput, bytes32 _role) external {
    bytes memory _data = abi.encode(_role);

    // it returns role
    assertEq(daoSpaceProxy.fetch(ActionsConstants.SPACE_LEFT, _topicInput, _data), bytes32(_role));
  }

  function test_Fetch_When_actionEqualsEDITOR_FLAGGED(bytes32 _topicInput, address _flaggedEditor) external {
    bytes memory _data = abi.encode(_flaggedEditor);

    // it returns bytes32(bytes20(_flaggedEditor))
    assertEq(daoSpaceProxy.fetch(ActionsConstants.EDITOR_FLAGGED, _topicInput, _data), bytes32(bytes20(_flaggedEditor)));
  }

  function test_Fetch_When_actionEqualsAnythingElse(
    bytes32 _action,
    bytes32 _topicInput,
    bytes calldata _data
  ) external view {
    vm.assume(_action != ActionsConstants.PROPOSAL_CREATED);
    vm.assume(_action != ActionsConstants.PROPOSAL_VOTED);
    vm.assume(_action != ActionsConstants.PROPOSAL_EXECUTED);
    vm.assume(_action != ActionsConstants.EDITOR_FLAGGED);
    vm.assume(_action != ActionsConstants.SPACE_LEFT);

    // it returns _topicInput
    assertEq(daoSpaceProxy.fetch(_action, _topicInput, _data), _topicInput);
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
    (uint256 slowPathPercentageThreshold,, uint256 quorum, uint256 duration) = daoSpaceProxy.votingSettings();
    daoSpaceProxy.workaround_createProposal(
      0,
      block.timestamp,
      block.timestamp + duration,
      IDAOSpace.VotingMode.Slow,
      slowPathPercentageThreshold,
      quorum,
      new IDAOSpace.Action[](0),
      false
    );

    // it returns false
    assertEq(daoSpaceProxy.isSupportThresholdReached(0), false);
  }

  function test_IsSupportThresholdReached_WhenTheVotingQuorumHasNotBeenReached(
    uint256 _yes,
    uint256 _no,
    uint256 _abstain,
    uint256 _quorum,
    uint256 _slowPathPercentageThreshold
  ) external whenTheProposalVotingModeIsUsingTheSlowPath {
    // set up
    (,,, uint256 duration) = daoSpaceProxy.votingSettings();
    _yes = bound(_yes, 0, 1e3);
    _no = bound(_no, 0, 1e3);
    _abstain = bound(_abstain, 0, 1e3);
    _quorum = bound(_quorum, _yes + _no + _abstain + 1, 1e4);
    _slowPathPercentageThreshold = bound(_slowPathPercentageThreshold, 1, daoSpaceProxy.RATIO_BASE());
    daoSpaceProxy.workaround_createProposal(
      0,
      block.timestamp,
      block.timestamp + duration,
      IDAOSpace.VotingMode.Slow,
      _slowPathPercentageThreshold,
      _quorum,
      new IDAOSpace.Action[](0),
      false
    );
    daoSpaceProxy.workaround_setTally(0, _yes, _no, _abstain);
    vm.warp(block.timestamp + duration + 1);

    // it returns false
    assertEq(daoSpaceProxy.isSupportThresholdReached(0), false);
  }

  function test_IsSupportThresholdReached_WhenTheYesVotesAreNotGreaterThanThePercentageSupportThreshold(
    uint256 _yes,
    uint256 _no,
    uint256 _abstain,
    uint256 _slowPathPercentageThreshold
  ) external whenTheProposalVotingModeIsUsingTheSlowPath {
    // set up
    (,, uint256 quorum, uint256 duration) = daoSpaceProxy.votingSettings();
    _yes = bound(_yes, 0, 1e3);
    _no = bound(_no, 0, 1e3);
    _abstain = bound(_abstain, 0, 1e3);
    _slowPathPercentageThreshold = bound(_slowPathPercentageThreshold, 1, daoSpaceProxy.RATIO_BASE());
    vm.assume(
      (daoSpaceProxy.RATIO_BASE() - (_slowPathPercentageThreshold - 1)) * _yes
        <= (_slowPathPercentageThreshold - 1) * _no
    );
    daoSpaceProxy.workaround_createProposal(
      0,
      block.timestamp,
      block.timestamp + duration,
      IDAOSpace.VotingMode.Slow,
      _slowPathPercentageThreshold,
      quorum,
      new IDAOSpace.Action[](0),
      false
    );
    daoSpaceProxy.workaround_setTally(0, _yes, _no, _abstain);
    vm.warp(block.timestamp + duration + 1);

    // it returns false
    assertEq(daoSpaceProxy.isSupportThresholdReached(0), false);
  }

  function test_IsSupportThresholdReached_WhenTheYesVotesAreGreaterThanThePercentageSupportThreshold(
    uint256 _yes,
    uint256 _no,
    uint256 _abstain,
    uint256 _slowPathPercentageThreshold
  ) external whenTheProposalVotingModeIsUsingTheSlowPath {
    // set up
    (,, uint256 quorum, uint256 duration) = daoSpaceProxy.votingSettings();
    _yes = bound(_yes, 0, 1e3);
    _no = bound(_no, 0, 1e3);
    _abstain = bound(_abstain, 0, 1e3);
    _slowPathPercentageThreshold = bound(_slowPathPercentageThreshold, 1, daoSpaceProxy.RATIO_BASE());
    vm.assume(
      (daoSpaceProxy.RATIO_BASE() - (_slowPathPercentageThreshold - 1)) * _yes
        > (_slowPathPercentageThreshold - 1) * _no
    );
    daoSpaceProxy.workaround_createProposal(
      0,
      block.timestamp,
      block.timestamp + duration,
      IDAOSpace.VotingMode.Slow,
      _slowPathPercentageThreshold,
      quorum,
      new IDAOSpace.Action[](0),
      false
    );
    daoSpaceProxy.workaround_setTally(0, _yes, _no, _abstain);
    vm.warp(block.timestamp + duration + 1);

    // it returns true
    assertEq(daoSpaceProxy.isSupportThresholdReached(0), true);
  }

  function test_IsSupportThresholdReached_WhenTheYesVotesAreNotGreaterThanTheFlatSupportThreshold(
    uint256 _yes,
    uint256 _fastPathFlatThreshold
  ) external whenTheProposalVotingModeIsUsingTheFastPath {
    // set up
    (,, uint256 quorum, uint256 duration) = daoSpaceProxy.votingSettings();
    _fastPathFlatThreshold = bound(_fastPathFlatThreshold, 1, 1e3);
    _yes = bound(_yes, 0, 1e3);
    vm.assume(_yes <= (_fastPathFlatThreshold - 1));
    daoSpaceProxy.workaround_createProposal(
      0,
      block.timestamp,
      block.timestamp + duration,
      IDAOSpace.VotingMode.Fast,
      _fastPathFlatThreshold,
      quorum,
      new IDAOSpace.Action[](0),
      false
    );
    daoSpaceProxy.workaround_setTally(0, _yes, 0, 0);

    // it returns false
    assertEq(daoSpaceProxy.isSupportThresholdReached(0), false);
  }

  function test_IsSupportThresholdReached_WhenTheYesVotesAreGreaterThanTheFlatSupportThreshold(
    uint256 _yes,
    uint256 _fastPathFlatThreshold
  ) external whenTheProposalVotingModeIsUsingTheFastPath {
    // set up
    (,, uint256 quorum, uint256 duration) = daoSpaceProxy.votingSettings();
    _fastPathFlatThreshold = bound(_fastPathFlatThreshold, 1, 1e3);
    _yes = bound(_yes, 0, 1e3);
    vm.assume(_yes > (_fastPathFlatThreshold - 1));
    daoSpaceProxy.workaround_createProposal(
      0,
      block.timestamp,
      block.timestamp + duration,
      IDAOSpace.VotingMode.Fast,
      _fastPathFlatThreshold,
      quorum,
      new IDAOSpace.Action[](0),
      false
    );
    daoSpaceProxy.workaround_setTally(0, _yes, 0, 0);

    // it returns true
    assertEq(daoSpaceProxy.isSupportThresholdReached(0), true);
  }

  /// VERSION ///

  function test_Version_WhenCalled() external view {
    // it returns semantic version
    assertEq(daoSpaceProxy.version(), '1.0.0');
  }

  /// HELPERS ///

  function _mockRegisterSpaceId(address __spaceRegistry) internal {
    _mockAndExpect(__spaceRegistry, abi.encodeCall(ISpaceRegistry.registerSpaceId, ()), abi.encode());
  }

  function _mockEnter(
    address __spaceRegistry,
    address _from,
    address _to,
    bytes32 _action,
    bytes32 _topic,
    bytes memory _data
  ) internal {
    _mockAndExpect(
      __spaceRegistry, abi.encodeCall(ISpaceRegistry.enter, (_from, _to, _action, _topic, _data, '')), abi.encode()
    );
  }

  function _createSlowPathProposalToAddEditor() internal view returns (bytes memory) {
    IDAOSpace.VotingMode votingMode = IDAOSpace.VotingMode.Slow;
    IDAOSpace.Action[] memory actions = new IDAOSpace.Action[](1);
    actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addEditor, (_randomCaller))
    });
    return abi.encode(votingMode, actions);
  }

  /// @dev valid proposal because action is fast path valid
  function _createFastPathProposalToAddMember() internal view returns (bytes memory) {
    IDAOSpace.VotingMode votingMode = IDAOSpace.VotingMode.Fast;
    IDAOSpace.Action[] memory actions = new IDAOSpace.Action[](1);
    actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addMember, (_randomCaller))
    });
    return abi.encode(votingMode, actions);
  }

  /// @dev invalid proposal because it attempts to perform two actions
  function _createFastPathProposalToAddTwoMembers() internal view returns (bytes memory) {
    IDAOSpace.VotingMode votingMode = IDAOSpace.VotingMode.Fast;
    IDAOSpace.Action[] memory actions = new IDAOSpace.Action[](2);
    actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addMember, (_randomCaller))
    });
    actions[1] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addMember, (_randomCaller))
    });
    return abi.encode(votingMode, actions);
  }

  /// @dev invalid proposal because action is not fast path valid
  function _createFastPathProposalToAddEditor() internal view returns (bytes memory) {
    IDAOSpace.VotingMode votingMode = IDAOSpace.VotingMode.Fast;
    IDAOSpace.Action[] memory actions = new IDAOSpace.Action[](1);
    actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.addEditor, (_randomCaller))
    });
    return abi.encode(votingMode, actions);
  }

  function _createVoteForFirstProposal(IDAOSpace.VoteOption _votingOption) internal pure returns (bytes memory) {
    return abi.encode(0, _votingOption);
  }
}
