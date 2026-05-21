// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {IntegrationBase} from 'test/integration/IntegrationBase.t.sol';

import {IDAOSpace} from 'interfaces/IDAOSpace.sol';

import 'src/ActionsConstants.sol' as ActionsConstants;

contract IntegrationDefaultGovernance is IntegrationBase {
  struct Proposal {
    bool executed;
    bytes16 creator;
    IDAOSpace.ProposalParameters parameters;
    IDAOSpace.Tally tally;
    IDAOSpace.Action[] actions;
  }

  function setUp() public override {
    IntegrationBase.setUp();
    vm.selectFork(_geoForkId);
  }

  function test_DefaultGovernance_ExecutionGracePeriodAndExecuteBy() external {
    IDAOSpace.VotingSettings memory _deployedVotingSettings = daoSpaceProxy.votingSettings();
    assertEq(_deployedVotingSettings.executionGracePeriod, _votingSettings.executionGracePeriod);

    bytes16 _proposalId = 'exec-grace';
    _createSlowPathProposal(_proposalId, _verifierSpaceProxyId);
    _voteProposal({
      _voterSpaceId: _eoaSpaceId, _proposalId: _proposalId, _proposalVersion: 1, _voteOption: IDAOSpace.VoteOption.Yes
    });

    (,, IDAOSpace.ProposalParameters memory _params,,) = daoSpaceProxy.getLatestProposalInformation(_proposalId);
    assertEq(_params.executeBy, _params.lastDate + _deployedVotingSettings.executionGracePeriod);

    vm.warp(_params.lastDate + 1);
    assertTrue(daoSpaceProxy.canExecuteProposal(_proposalId));

    vm.warp(_params.executeBy + 1);
    assertFalse(daoSpaceProxy.canExecuteProposal(_proposalId));
    vm.expectRevert(IDAOSpace.CanNotExecute.selector);
    _executeProposal(_proposalId);

    vm.warp(_params.executeBy);
    assertTrue(daoSpaceProxy.canExecuteProposal(_proposalId));
    _executeProposal(_proposalId);

    (bool _executed,,,,) = daoSpaceProxy.getLatestProposalInformation(_proposalId);
    assertTrue(_executed);
    assertFalse(daoSpaceProxy.hasRole(daoSpaceImplementation.EDITOR(), _verifierSpaceProxyId));
  }

  function test_DefaultGovernance_CreateProposals() external {
    // Proposal 0: Slow path
    bytes16 _slowPathProposalId = '0';
    _createSlowPathProposal(_slowPathProposalId, _verifierSpaceProxyId);

    Proposal memory _slowPathProposal;
    (, _slowPathProposal.creator, _slowPathProposal.parameters,,) =
      daoSpaceProxy.getLatestProposalInformation(_slowPathProposalId);
    assertEq(_slowPathProposal.creator, _eoaSpaceId);
    assertEq(uint8(_slowPathProposal.parameters.votingMode), uint8(IDAOSpace.VotingMode.Slow));
    assertEq(daoSpaceProxy.latestProposalVersion(_slowPathProposalId), 1);

    vm.expectRevert(IDAOSpace.InvalidProposalId.selector);
    // Proposal 1: Fast path
    _createFastPathProposal(_slowPathProposalId, _verifierSpaceProxyId);

    // Proposal 1: Fast path
    bytes16 _fastPathProposalId = '1';
    _createFastPathProposal(_fastPathProposalId, _verifierSpaceProxyId);

    Proposal memory _fastPathProposal;
    (, _fastPathProposal.creator, _fastPathProposal.parameters,,) =
      daoSpaceProxy.getLatestProposalInformation(_fastPathProposalId);
    assertEq(_fastPathProposal.creator, _eoaSpaceId);
    assertEq(uint8(_fastPathProposal.parameters.votingMode), uint8(IDAOSpace.VotingMode.Fast));
    assertEq(daoSpaceProxy.latestProposalVersion(_fastPathProposalId), 1);
  }

  function test_DefaultGovernance_VoteProposals() external {
    // Proposal 0: Path escalation
    bytes16 _pathEscalationProposalId = '0';
    _createFastPathProposal(_pathEscalationProposalId, _verifierSpaceProxyId);

    (,, IDAOSpace.ProposalParameters memory _pathEscalationParams,,) =
      daoSpaceProxy.getLatestProposalInformation(_pathEscalationProposalId);
    assertEq(_pathEscalationParams.startDate, 0);
    assertEq(_pathEscalationParams.lastDate, 0);
    assertEq(_pathEscalationParams.executeBy, 0);

    vm.warp(vm.getBlockTimestamp() + _votingSettings.duration + 1 days);
    assertFalse(daoSpaceProxy.canExecuteProposal(_pathEscalationProposalId));

    // Vote: Abstain
    _voteProposal({
      _voterSpaceId: _eoaSpaceId,
      _proposalId: _pathEscalationProposalId,
      _proposalVersion: 1,
      _voteOption: IDAOSpace.VoteOption.Abstain
    });

    Proposal memory _pathEscalationProposal;
    (_pathEscalationProposal.executed,, _pathEscalationProposal.parameters, _pathEscalationProposal.tally,) =
      daoSpaceProxy.getLatestProposalInformation(_pathEscalationProposalId);
    assertEq(_pathEscalationProposal.tally.abstain, 1);
    assertEq(_pathEscalationProposal.tally.yes, 0);
    assertEq(_pathEscalationProposal.tally.no, 0);
    assertEq(
      uint8(daoSpaceProxy.getLatestProposalVote(_pathEscalationProposalId, _eoaSpaceId)),
      uint8(IDAOSpace.VoteOption.Abstain)
    );
    assertEq(uint8(_pathEscalationProposal.parameters.votingMode), uint8(IDAOSpace.VotingMode.Fast));
    assertFalse(_pathEscalationProposal.executed);
    assertGt(_pathEscalationProposal.parameters.startDate, 0);
    assertGt(_pathEscalationProposal.parameters.lastDate, _pathEscalationProposal.parameters.startDate);
    assertGt(_pathEscalationProposal.parameters.executeBy, _pathEscalationProposal.parameters.lastDate);

    vm.warp(_pathEscalationProposal.parameters.lastDate + 1);
    vm.expectRevert(IDAOSpace.CanNotVote.selector);
    _voteProposal({
      _voterSpaceId: _eoaSpaceId,
      _proposalId: _pathEscalationProposalId,
      _proposalVersion: 1,
      _voteOption: IDAOSpace.VoteOption.No
    });

    vm.warp(_pathEscalationProposal.parameters.startDate + 1);

    vm.expectRevert(IDAOSpace.CanNotVote.selector);
    // Vote: None
    _voteProposal({
      _voterSpaceId: _eoaSpaceId,
      _proposalId: _pathEscalationProposalId,
      _proposalVersion: 1,
      _voteOption: IDAOSpace.VoteOption.None
    });

    // Vote: No
    _voteProposal({
      _voterSpaceId: _eoaSpaceId,
      _proposalId: _pathEscalationProposalId,
      _proposalVersion: 1,
      _voteOption: IDAOSpace.VoteOption.No
    });

    (_pathEscalationProposal.executed,, _pathEscalationProposal.parameters, _pathEscalationProposal.tally,) =
      daoSpaceProxy.getLatestProposalInformation(_pathEscalationProposalId);
    assertEq(_pathEscalationProposal.tally.abstain, 0);
    assertEq(_pathEscalationProposal.tally.yes, 0);
    assertEq(_pathEscalationProposal.tally.no, 1);
    assertEq(
      uint8(daoSpaceProxy.getLatestProposalVote(_pathEscalationProposalId, _eoaSpaceId)), uint8(IDAOSpace.VoteOption.No)
    );
    assertEq(uint8(_pathEscalationProposal.parameters.votingMode), uint8(IDAOSpace.VotingMode.Slow));
    assertFalse(_pathEscalationProposal.executed);

    // Vote: Yes
    _voteProposal({
      _voterSpaceId: _eoaSpaceId,
      _proposalId: _pathEscalationProposalId,
      _proposalVersion: 1,
      _voteOption: IDAOSpace.VoteOption.Yes
    });
    // Vote: Yes
    _voteProposal({
      _voterSpaceId: _verifierSpaceProxyId,
      _proposalId: _pathEscalationProposalId,
      _proposalVersion: 1,
      _voteOption: IDAOSpace.VoteOption.Yes
    });

    (_pathEscalationProposal.executed,, _pathEscalationProposal.parameters, _pathEscalationProposal.tally,) =
      daoSpaceProxy.getLatestProposalInformation(_pathEscalationProposalId);
    assertEq(_pathEscalationProposal.tally.abstain, 0);
    assertEq(_pathEscalationProposal.tally.yes, 2);
    assertEq(_pathEscalationProposal.tally.no, 0);
    assertEq(
      uint8(daoSpaceProxy.getLatestProposalVote(_pathEscalationProposalId, _eoaSpaceId)),
      uint8(IDAOSpace.VoteOption.Yes)
    );
    assertEq(
      uint8(daoSpaceProxy.getLatestProposalVote(_pathEscalationProposalId, _verifierSpaceProxyId)),
      uint8(IDAOSpace.VoteOption.Yes)
    );
    assertEq(uint8(_pathEscalationProposal.parameters.votingMode), uint8(IDAOSpace.VotingMode.Slow));
    assertTrue(_pathEscalationProposal.executed);

    // Proposal 1: Fast path
    bytes16 _fastPathProposalId = '1';
    _createFastPathProposal(_fastPathProposalId, _eoaSpaceId);

    (,, IDAOSpace.ProposalParameters memory _fastPathParams,,) =
      daoSpaceProxy.getLatestProposalInformation(_fastPathProposalId);
    assertEq(_fastPathParams.startDate, 0);
    assertEq(_fastPathParams.lastDate, 0);
    assertEq(_fastPathParams.executeBy, 0);

    vm.warp(vm.getBlockTimestamp() + _votingSettings.duration + 1 days);

    // Vote: Yes
    _voteProposal({
      _voterSpaceId: _eoaSpaceId,
      _proposalId: _fastPathProposalId,
      _proposalVersion: 1,
      _voteOption: IDAOSpace.VoteOption.Yes
    });

    Proposal memory _fastPathProposal;
    (_fastPathProposal.executed,, _fastPathProposal.parameters, _fastPathProposal.tally,) =
      daoSpaceProxy.getLatestProposalInformation(_fastPathProposalId);
    assertEq(_fastPathProposal.tally.abstain, 0);
    assertEq(_fastPathProposal.tally.yes, 1);
    assertEq(_fastPathProposal.tally.no, 0);
    assertEq(
      uint8(daoSpaceProxy.getLatestProposalVote(_fastPathProposalId, _eoaSpaceId)), uint8(IDAOSpace.VoteOption.Yes)
    );
    assertEq(uint8(_fastPathProposal.parameters.votingMode), uint8(IDAOSpace.VotingMode.Fast));
    assertTrue(_fastPathProposal.executed);
    assertGt(_fastPathProposal.parameters.startDate, 0);
    assertGt(_fastPathProposal.parameters.lastDate, _fastPathProposal.parameters.startDate);
    assertGt(_fastPathProposal.parameters.executeBy, _fastPathProposal.parameters.lastDate);

    vm.warp(_fastPathProposal.parameters.lastDate + 1);
    vm.expectRevert(IDAOSpace.CanNotVote.selector);
    // Vote: Abstain
    _voteProposal({
      _voterSpaceId: _eoaSpaceId,
      _proposalId: _fastPathProposalId,
      _proposalVersion: 1,
      _voteOption: IDAOSpace.VoteOption.Abstain
    });
  }

  function test_DefaultGovernance_ExecuteProposals() external {
    assertTrue(daoSpaceProxy.hasRole(daoSpaceImplementation.EDITOR(), _eoaSpaceId));
    assertTrue(daoSpaceProxy.hasRole(daoSpaceImplementation.MEMBER(), _eoaSpaceId));
    assertTrue(daoSpaceProxy.hasRole(daoSpaceImplementation.EDITOR(), _verifierSpaceProxyId));
    assertTrue(daoSpaceProxy.hasRole(daoSpaceImplementation.MEMBER(), _verifierSpaceProxyId));

    // Proposal 0: Fast path (early execution)
    bytes16 _fastPathProposalId = '0';
    _createFastPathProposal(_fastPathProposalId, _verifierSpaceProxyId);
    // Vote: Yes
    _voteProposal({
      _voterSpaceId: _eoaSpaceId,
      _proposalId: _fastPathProposalId,
      _proposalVersion: 1,
      _voteOption: IDAOSpace.VoteOption.Yes
    });
    // Execute: removeMember(_verifierSpaceProxyId);

    Proposal memory _fastPathProposal;
    (_fastPathProposal.executed,, _fastPathProposal.parameters,,) =
      daoSpaceProxy.getLatestProposalInformation(_fastPathProposalId);
    assertEq(uint8(_fastPathProposal.parameters.votingMode), uint8(IDAOSpace.VotingMode.Fast));
    assertTrue(_fastPathProposal.executed);
    assertFalse(daoSpaceProxy.canExecuteProposal(_fastPathProposalId));
    assertTrue(daoSpaceProxy.hasRole(daoSpaceImplementation.EDITOR(), _eoaSpaceId));
    assertTrue(daoSpaceProxy.hasRole(daoSpaceImplementation.MEMBER(), _eoaSpaceId));
    assertTrue(daoSpaceProxy.hasRole(daoSpaceImplementation.EDITOR(), _verifierSpaceProxyId));
    assertFalse(daoSpaceProxy.hasRole(daoSpaceImplementation.MEMBER(), _verifierSpaceProxyId));

    vm.expectRevert(IDAOSpace.CanNotExecute.selector);
    // Execute: removeMember(_verifierSpaceProxyId);
    _executeProposal(_fastPathProposalId);

    // Proposal 1: Slow path (no execution)
    bytes16 _slowPathProposalId = '1';
    _createSlowPathProposal(_slowPathProposalId, _verifierSpaceProxyId);
    // Vote: No
    _voteProposal({
      _voterSpaceId: _eoaSpaceId,
      _proposalId: _slowPathProposalId,
      _proposalVersion: 1,
      _voteOption: IDAOSpace.VoteOption.No
    });

    assertFalse(daoSpaceProxy.canExecuteProposal(_slowPathProposalId));
    vm.expectRevert(IDAOSpace.CanNotExecute.selector);
    // Execute: removeEditor(_verifierSpaceProxyId);
    _executeProposal(_slowPathProposalId);

    skip(daoSpaceImplementation.MINIMUM_VOTING_DURATION() + 1);
    assertFalse(daoSpaceProxy.canExecuteProposal(_slowPathProposalId));
    vm.expectRevert(IDAOSpace.CanNotExecute.selector);
    // Execute: removeEditor(_verifierSpaceProxyId);
    _executeProposal(_slowPathProposalId);

    Proposal memory _slowPathProposal;
    (_slowPathProposal.executed,, _slowPathProposal.parameters,,) =
      daoSpaceProxy.getLatestProposalInformation(_slowPathProposalId);
    assertEq(uint8(_slowPathProposal.parameters.votingMode), uint8(IDAOSpace.VotingMode.Slow));
    assertFalse(_slowPathProposal.executed);
    assertTrue(daoSpaceProxy.hasRole(daoSpaceImplementation.EDITOR(), _eoaSpaceId));
    assertTrue(daoSpaceProxy.hasRole(daoSpaceImplementation.MEMBER(), _eoaSpaceId));
    assertTrue(daoSpaceProxy.hasRole(daoSpaceImplementation.EDITOR(), _verifierSpaceProxyId));
    assertFalse(daoSpaceProxy.hasRole(daoSpaceImplementation.MEMBER(), _verifierSpaceProxyId));

    // Proposal 2: Slow path (late execution)
    bytes16 _slowPathProposalBisId = '2';
    _createSlowPathProposal(_slowPathProposalBisId, _verifierSpaceProxyId);
    // Vote: Yes
    _voteProposal({
      _voterSpaceId: _eoaSpaceId,
      _proposalId: _slowPathProposalBisId,
      _proposalVersion: 1,
      _voteOption: IDAOSpace.VoteOption.Yes
    });

    skip(daoSpaceImplementation.MINIMUM_VOTING_DURATION() + 1);
    assertTrue(daoSpaceProxy.canExecuteProposal(_slowPathProposalBisId));
    // Execute: removeEditor(_verifierSpaceProxyId);
    _executeProposal(_slowPathProposalBisId);

    Proposal memory _slowPathProposalBis;
    (_slowPathProposalBis.executed,, _slowPathProposalBis.parameters,,) =
      daoSpaceProxy.getLatestProposalInformation(_slowPathProposalBisId);
    assertEq(uint8(_slowPathProposalBis.parameters.votingMode), uint8(IDAOSpace.VotingMode.Slow));
    assertTrue(_slowPathProposalBis.executed);
    assertFalse(daoSpaceProxy.canExecuteProposal(_slowPathProposalBisId));
    assertTrue(daoSpaceProxy.hasRole(daoSpaceImplementation.EDITOR(), _eoaSpaceId));
    assertTrue(daoSpaceProxy.hasRole(daoSpaceImplementation.MEMBER(), _eoaSpaceId));
    assertFalse(daoSpaceProxy.hasRole(daoSpaceImplementation.EDITOR(), _verifierSpaceProxyId));
    assertFalse(daoSpaceProxy.hasRole(daoSpaceImplementation.MEMBER(), _verifierSpaceProxyId));

    // Proposal 3: Slow path (early execution)
    bytes16 _slowPathProposalTerId = '3';
    _createSlowPathProposal(_slowPathProposalTerId, _eoaSpaceId);
    // Vote: Yes
    _voteProposal({
      _voterSpaceId: _eoaSpaceId,
      _proposalId: _slowPathProposalTerId,
      _proposalVersion: 1,
      _voteOption: IDAOSpace.VoteOption.Yes
    });
    // Execute: removeEditor(_eoaSpaceId);

    Proposal memory _slowPathProposalTer;
    (_slowPathProposalTer.executed,, _slowPathProposalTer.parameters,,) =
      daoSpaceProxy.getLatestProposalInformation(_slowPathProposalTerId);
    assertEq(uint8(_slowPathProposalTer.parameters.votingMode), uint8(IDAOSpace.VotingMode.Slow));
    assertTrue(_slowPathProposalTer.executed);
    assertFalse(daoSpaceProxy.canExecuteProposal(_slowPathProposalTerId));
    assertFalse(daoSpaceProxy.hasRole(daoSpaceImplementation.EDITOR(), _eoaSpaceId));
    assertTrue(daoSpaceProxy.hasRole(daoSpaceImplementation.MEMBER(), _eoaSpaceId));
    assertFalse(daoSpaceProxy.hasRole(daoSpaceImplementation.EDITOR(), _verifierSpaceProxyId));
    assertFalse(daoSpaceProxy.hasRole(daoSpaceImplementation.MEMBER(), _verifierSpaceProxyId));
  }

  function test_DefaultGovernance_UpdateProposal() external {
    // Proposal 0: Slow path
    bytes16 _slowPathProposalId = '0';
    _createSlowPathProposal(_slowPathProposalId, _verifierSpaceProxyId);
    // Vote: Yes (starts voting window on version 1)
    _voteProposal({
      _voterSpaceId: _eoaSpaceId,
      _proposalId: _slowPathProposalId,
      _proposalVersion: 1,
      _voteOption: IDAOSpace.VoteOption.Yes
    });

    (,, IDAOSpace.ProposalParameters memory _v1Params, IDAOSpace.Tally memory _v1Tally,) =
      daoSpaceProxy.getProposalInformation(_slowPathProposalId, 1);
    assertGt(_v1Params.startDate, 0);
    assertGt(_v1Params.lastDate, _v1Params.startDate);
    assertGt(_v1Params.executeBy, _v1Params.lastDate);
    assertEq(_v1Tally.yes, 1);
    assertEq(uint8(daoSpaceProxy.getProposalVote(_slowPathProposalId, 1, _eoaSpaceId)), uint8(IDAOSpace.VoteOption.Yes));

    vm.warp(_v1Params.lastDate + 1);

    // Update: Fast path
    _updateProposalPath(_slowPathProposalId, IDAOSpace.VotingMode.Fast, _verifierSpaceProxyId);

    Proposal memory _slowPathProposal;
    (, _slowPathProposal.creator, _slowPathProposal.parameters, _slowPathProposal.tally,) =
      daoSpaceProxy.getLatestProposalInformation(_slowPathProposalId);
    assertEq(_slowPathProposal.creator, _eoaSpaceId);
    assertEq(uint8(_slowPathProposal.parameters.votingMode), uint8(IDAOSpace.VotingMode.Fast));
    assertEq(daoSpaceProxy.latestProposalVersion(_slowPathProposalId), 2);
    assertEq(_slowPathProposal.parameters.startDate, 0);
    assertEq(_slowPathProposal.parameters.lastDate, 0);
    assertEq(_slowPathProposal.parameters.executeBy, 0);
    assertEq(_slowPathProposal.tally.yes, 0);
    assertEq(_slowPathProposal.tally.no, 0);
    assertEq(_slowPathProposal.tally.abstain, 0);
    assertEq(
      uint8(daoSpaceProxy.getLatestProposalVote(_slowPathProposalId, _eoaSpaceId)), uint8(IDAOSpace.VoteOption.None)
    );
    assertFalse(daoSpaceProxy.canExecuteProposal(_slowPathProposalId));

    (,, IDAOSpace.ProposalParameters memory _v1ParamsAfter, IDAOSpace.Tally memory _v1TallyAfter,) =
      daoSpaceProxy.getProposalInformation(_slowPathProposalId, 1);
    assertEq(_v1ParamsAfter.startDate, _v1Params.startDate);
    assertEq(_v1ParamsAfter.lastDate, _v1Params.lastDate);
    assertEq(_v1ParamsAfter.executeBy, _v1Params.executeBy);
    assertEq(_v1TallyAfter.yes, 1);
    assertEq(uint8(daoSpaceProxy.getProposalVote(_slowPathProposalId, 1, _eoaSpaceId)), uint8(IDAOSpace.VoteOption.Yes));
  }

  function test_DefaultGovernance_RequestMembership() external {
    assertFalse(daoSpaceProxy.hasRole(daoSpaceImplementation.MEMBER(), _daoSpaceProxyId));

    // Proposal 0: Request membership (fast path)
    bytes16 _requestMembershipProposalId = '0';
    _requestMembership(_requestMembershipProposalId, _daoSpaceProxyId);
    // Vote: Yes
    _voteProposal({
      _voterSpaceId: _eoaSpaceId,
      _proposalId: _requestMembershipProposalId,
      _proposalVersion: 1,
      _voteOption: IDAOSpace.VoteOption.Yes
    });
    // Execute: addMember();

    assertTrue(daoSpaceProxy.hasRole(daoSpaceImplementation.MEMBER(), _daoSpaceProxyId));

    vm.expectRevert(IDAOSpace.InvalidSpaceIdForRole.selector);
    // Proposal 1: Request membership (fast path)
    bytes16 _requestMembershipProposalBisId = '1';
    _requestMembership(_requestMembershipProposalBisId, _daoSpaceProxyId);
  }

  function test_DefaultGovernance_LeaveSpace() external {
    assertTrue(daoSpaceProxy.hasRole(daoSpaceImplementation.EDITOR(), _eoaSpaceId));
    assertTrue(daoSpaceProxy.hasRole(daoSpaceImplementation.MEMBER(), _eoaSpaceId));

    // Leave: EDITOR
    bytes32 _editorRole = daoSpaceImplementation.EDITOR();
    _leaveSpace(_editorRole);

    assertFalse(daoSpaceProxy.hasRole(daoSpaceImplementation.EDITOR(), _eoaSpaceId));
    assertTrue(daoSpaceProxy.hasRole(daoSpaceImplementation.MEMBER(), _eoaSpaceId));

    vm.expectRevert(IDAOSpace.InvalidFromSpace.selector);
    // Leave: EDITOR
    _leaveSpace(_editorRole);

    // Leave: MEMBER
    bytes32 _memberRole = daoSpaceImplementation.MEMBER();
    _leaveSpace(_memberRole);

    assertFalse(daoSpaceProxy.hasRole(daoSpaceImplementation.EDITOR(), _eoaSpaceId));
    assertFalse(daoSpaceProxy.hasRole(daoSpaceImplementation.MEMBER(), _eoaSpaceId));
  }

  function test_DefaultGovernance_RestrictSpace() external {
    assertTrue(daoSpaceProxy.hasRole(daoSpaceImplementation.EDITOR(), _eoaSpaceId));
    assertFalse(daoSpaceProxy.hasRole(daoSpaceImplementation.FAST_PATH_RESTRICTED(), _eoaSpaceId));

    // Restrict: EDITOR
    _restrictSpace(_eoaSpaceId);

    assertTrue(daoSpaceProxy.hasRole(daoSpaceImplementation.EDITOR(), _eoaSpaceId));
    assertTrue(daoSpaceProxy.hasRole(daoSpaceImplementation.FAST_PATH_RESTRICTED(), _eoaSpaceId));

    vm.expectRevert(IDAOSpace.InvalidSpaceIdForRole.selector);
    // Restrict: EDITOR
    _restrictSpace(_eoaSpaceId);

    vm.expectRevert(IDAOSpace.FastPathRestricted.selector);
    // Proposal 0: Fast path
    bytes16 _fastPathProposalId = '0';
    _createFastPathProposal(_fastPathProposalId, _verifierSpaceProxyId);
  }

  function _createSlowPathProposal(bytes16 _proposalId, bytes16 _editorSpaceId) internal {
    IDAOSpace.Action[] memory _actions = new IDAOSpace.Action[](1);
    _actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.removeEditor, (_editorSpaceId))
    });
    bytes memory _createProposalData = abi.encode(_proposalId, IDAOSpace.VotingMode.Slow, _actions);

    vm.prank(eoaSpace);
    // PROPOSAL_CREATED
    spaceRegistryProxy.enter(
      _eoaSpaceId, _daoSpaceProxyId, ActionsConstants.PROPOSAL_CREATED, '', _createProposalData, ''
    );
  }

  function _createFastPathProposal(bytes16 _proposalId, bytes16 _memberSpaceId) internal {
    IDAOSpace.Action[] memory _actions = new IDAOSpace.Action[](1);
    _actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.removeMember, (_memberSpaceId))
    });
    bytes memory _createProposalData = abi.encode(_proposalId, IDAOSpace.VotingMode.Fast, _actions);

    vm.prank(eoaSpace);
    // PROPOSAL_CREATED
    spaceRegistryProxy.enter(
      _eoaSpaceId, _daoSpaceProxyId, ActionsConstants.PROPOSAL_CREATED, '', _createProposalData, ''
    );
  }

  function _voteProposal(
    bytes16 _voterSpaceId,
    bytes16 _proposalId,
    uint8 _proposalVersion,
    IDAOSpace.VoteOption _voteOption
  ) internal {
    bytes memory _voteProposalData = abi.encode(_proposalId, _proposalVersion, _voteOption);

    if (_voterSpaceId == _eoaSpaceId) {
      vm.prank(eoaSpace);
    } else if (_voterSpaceId == _verifierSpaceProxyId) {
      vm.prank(address(verifierSpaceProxy));
    }
    // PROPOSAL_VOTED
    spaceRegistryProxy.enter(
      _voterSpaceId, _daoSpaceProxyId, ActionsConstants.PROPOSAL_VOTED, '', _voteProposalData, ''
    );
  }

  function _executeProposal(bytes16 _proposalId) internal {
    bytes memory _executeProposalData = abi.encode(_proposalId);

    vm.prank(eoaSpace);
    // PROPOSAL_EXECUTED
    spaceRegistryProxy.enter(
      _eoaSpaceId, _daoSpaceProxyId, ActionsConstants.PROPOSAL_EXECUTED, '', _executeProposalData, ''
    );
  }

  function _updateProposalPath(bytes16 _proposalId, IDAOSpace.VotingMode _votingMode, bytes16 _memberSpaceId) internal {
    IDAOSpace.Action[] memory _actions = new IDAOSpace.Action[](1);
    _actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.removeMember, (_memberSpaceId))
    });
    bytes memory _updateProposalData = abi.encode(_proposalId, _votingMode, _actions);

    vm.prank(eoaSpace);
    // PROPOSAL_UPDATED
    spaceRegistryProxy.enter(
      _eoaSpaceId, _daoSpaceProxyId, ActionsConstants.PROPOSAL_UPDATED, '', _updateProposalData, ''
    );
  }

  function _requestMembership(bytes16 _proposalId, bytes16 _newMemberSpaceId) internal {
    bytes memory _requestMembershipData = abi.encode(_proposalId, _newMemberSpaceId);

    vm.prank(eoaSpace);
    // MEMBERSHIP_REQUESTED
    spaceRegistryProxy.enter(
      _eoaSpaceId, _daoSpaceProxyId, ActionsConstants.MEMBERSHIP_REQUESTED, '', _requestMembershipData, ''
    );
  }

  function _leaveSpace(bytes32 _role) internal {
    bytes memory _leaveSpaceData = abi.encode(_role);

    vm.prank(eoaSpace);
    // SPACE_LEFT
    spaceRegistryProxy.enter(_eoaSpaceId, _daoSpaceProxyId, ActionsConstants.SPACE_LEFT, '', _leaveSpaceData, '');
  }

  function _restrictSpace(bytes16 _newRestrictedSpaceId) internal {
    bytes memory _restrictSpaceData = abi.encode(_newRestrictedSpaceId);

    vm.prank(eoaSpace);
    // SPACE_FAST_PATH_RESTRICTED
    spaceRegistryProxy.enter(
      _eoaSpaceId, _daoSpaceProxyId, ActionsConstants.SPACE_FAST_PATH_RESTRICTED, '', _restrictSpaceData, ''
    );
  }
}
