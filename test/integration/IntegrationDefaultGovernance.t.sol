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

  function test_DefaultGovernance_CreateProposals() external {
    // Proposal 0: Slow path
    bytes16 _slowPathProposalId = '0';
    _createSlowPathProposal(_slowPathProposalId);

    Proposal memory _slowPathProposal;
    (, _slowPathProposal.creator, _slowPathProposal.parameters,,) =
      daoSpaceProxy.getLatestProposalInformation(_slowPathProposalId);
    assertEq(_slowPathProposal.creator, _eoaSpaceId);
    assertEq(uint8(_slowPathProposal.parameters.votingMode), uint8(IDAOSpace.VotingMode.Slow));
    assertEq(daoSpaceProxy.latestProposalVersion(_slowPathProposalId), 1);

    vm.expectRevert(IDAOSpace.InvalidProposalId.selector);
    // Proposal 1: Fast path
    _createFastPathProposal(_slowPathProposalId);

    // Proposal 1: Fast path
    bytes16 _fastPathProposalId = '1';
    _createFastPathProposal(_fastPathProposalId);

    Proposal memory _fastPathProposal;
    (, _fastPathProposal.creator, _fastPathProposal.parameters,,) =
      daoSpaceProxy.getLatestProposalInformation(_fastPathProposalId);
    assertEq(_fastPathProposal.creator, _eoaSpaceId);
    assertEq(uint8(_fastPathProposal.parameters.votingMode), uint8(IDAOSpace.VotingMode.Fast));
    assertEq(daoSpaceProxy.latestProposalVersion(_fastPathProposalId), 1);
  }

  function test_DefaultGovernance_VoteProposals() external {
    // Proposal 0: Fast path
    bytes16 _fastPathProposalId = '0';
    _createFastPathProposal(_fastPathProposalId);
    // Vote: Abstain
    _voteProposal({_proposalId: _fastPathProposalId, _proposalVersion: 1, _voteOption: IDAOSpace.VoteOption.Abstain});

    Proposal memory _fastPathProposal;
    (_fastPathProposal.executed,, _fastPathProposal.parameters, _fastPathProposal.tally,) =
      daoSpaceProxy.getLatestProposalInformation(_fastPathProposalId);
    assertEq(_fastPathProposal.tally.abstain, 1);
    assertEq(_fastPathProposal.tally.yes, 0);
    assertEq(_fastPathProposal.tally.no, 0);
    assertEq(
      uint8(daoSpaceProxy.getLatestProposalVote(_fastPathProposalId, _eoaSpaceId)), uint8(IDAOSpace.VoteOption.Abstain)
    );
    assertEq(uint8(_fastPathProposal.parameters.votingMode), uint8(IDAOSpace.VotingMode.Fast));
    assertFalse(_fastPathProposal.executed);

    vm.expectRevert(IDAOSpace.CanNotVote.selector);
    // Vote: None
    _voteProposal({_proposalId: _fastPathProposalId, _proposalVersion: 1, _voteOption: IDAOSpace.VoteOption.None});

    // // Vote: No
    _voteProposal({_proposalId: _fastPathProposalId, _proposalVersion: 1, _voteOption: IDAOSpace.VoteOption.No});

    (_fastPathProposal.executed,, _fastPathProposal.parameters, _fastPathProposal.tally,) =
      daoSpaceProxy.getLatestProposalInformation(_fastPathProposalId);
    assertEq(_fastPathProposal.tally.abstain, 0);
    assertEq(_fastPathProposal.tally.yes, 0);
    assertEq(_fastPathProposal.tally.no, 1);
    assertEq(
      uint8(daoSpaceProxy.getLatestProposalVote(_fastPathProposalId, _eoaSpaceId)), uint8(IDAOSpace.VoteOption.No)
    );
    assertEq(uint8(_fastPathProposal.parameters.votingMode), uint8(IDAOSpace.VotingMode.Slow));
    assertFalse(_fastPathProposal.executed);

    // Proposal 1: Fast path
    bytes16 _fastPathProposalBisId = '1';
    _createFastPathProposal(_fastPathProposalBisId);
    // Vote: Yes
    _voteProposal({_proposalId: _fastPathProposalBisId, _proposalVersion: 1, _voteOption: IDAOSpace.VoteOption.Yes});

    Proposal memory _fastPathProposalBis;
    (_fastPathProposalBis.executed,, _fastPathProposalBis.parameters, _fastPathProposalBis.tally,) =
      daoSpaceProxy.getLatestProposalInformation(_fastPathProposalBisId);
    assertEq(_fastPathProposalBis.tally.abstain, 0);
    assertEq(_fastPathProposalBis.tally.yes, 1);
    assertEq(_fastPathProposalBis.tally.no, 0);
    assertEq(
      uint8(daoSpaceProxy.getLatestProposalVote(_fastPathProposalBisId, _eoaSpaceId)), uint8(IDAOSpace.VoteOption.Yes)
    );
    assertEq(uint8(_fastPathProposalBis.parameters.votingMode), uint8(IDAOSpace.VotingMode.Fast));
    assertTrue(_fastPathProposalBis.executed);

    vm.expectRevert(IDAOSpace.CanNotVote.selector);
    // Vote: Abstain
    _voteProposal({_proposalId: _fastPathProposalBisId, _proposalVersion: 1, _voteOption: IDAOSpace.VoteOption.Abstain});
  }

  function test_DefaultGovernance_ExecuteProposals() external {
    assertTrue(daoSpaceProxy.hasRole(daoSpaceImplementation.EDITOR(), _eoaSpaceId));
    assertTrue(daoSpaceProxy.hasRole(daoSpaceImplementation.MEMBER(), _eoaSpaceId));

    // Proposal 0: Fast path
    bytes16 _fastPathProposalId = '0';
    _createFastPathProposal(_fastPathProposalId);
    // Vote: Yes
    _voteProposal({_proposalId: _fastPathProposalId, _proposalVersion: 1, _voteOption: IDAOSpace.VoteOption.Yes});
    // Execute: removeMember();

    Proposal memory _fastPathProposal;
    (_fastPathProposal.executed,, _fastPathProposal.parameters,,) =
      daoSpaceProxy.getLatestProposalInformation(_fastPathProposalId);
    assertEq(uint8(_fastPathProposal.parameters.votingMode), uint8(IDAOSpace.VotingMode.Fast));
    assertTrue(_fastPathProposal.executed);
    assertTrue(daoSpaceProxy.hasRole(daoSpaceImplementation.EDITOR(), _eoaSpaceId));
    assertFalse(daoSpaceProxy.hasRole(daoSpaceImplementation.MEMBER(), _eoaSpaceId));

    vm.expectRevert(IDAOSpace.CanNotExecute.selector);
    // Execute: removeMember();
    _executeProposal(_fastPathProposalId);

    // Proposal 1: Slow path
    bytes16 _slowPathProposalId = '1';
    _createSlowPathProposal(_slowPathProposalId);
    // Vote: No
    _voteProposal({_proposalId: _slowPathProposalId, _proposalVersion: 1, _voteOption: IDAOSpace.VoteOption.No});

    vm.expectRevert(IDAOSpace.CanNotExecute.selector);
    // Execute: removeEditor();
    _executeProposal(_slowPathProposalId);

    skip(daoSpaceImplementation.MINIMUM_VOTING_DURATION() + 1);
    vm.expectRevert(IDAOSpace.CanNotExecute.selector);
    // Execute: removeEditor();
    _executeProposal(_slowPathProposalId);

    Proposal memory _slowPathProposal;
    (_slowPathProposal.executed,, _slowPathProposal.parameters,,) =
      daoSpaceProxy.getLatestProposalInformation(_slowPathProposalId);
    assertEq(uint8(_slowPathProposal.parameters.votingMode), uint8(IDAOSpace.VotingMode.Slow));
    assertFalse(_slowPathProposal.executed);
    assertTrue(daoSpaceProxy.hasRole(daoSpaceImplementation.EDITOR(), _eoaSpaceId));
    assertFalse(daoSpaceProxy.hasRole(daoSpaceImplementation.MEMBER(), _eoaSpaceId));

    // Proposal 2: Slow path
    bytes16 _slowPathProposalBisId = '2';
    _createSlowPathProposal(_slowPathProposalBisId);
    // Vote: Yes
    _voteProposal({_proposalId: _slowPathProposalBisId, _proposalVersion: 1, _voteOption: IDAOSpace.VoteOption.Yes});

    skip(daoSpaceImplementation.MINIMUM_VOTING_DURATION() + 1);
    // Execute: removeEditor();
    _executeProposal(_slowPathProposalBisId);

    Proposal memory _slowPathProposalBis;
    (_slowPathProposalBis.executed,, _slowPathProposalBis.parameters,,) =
      daoSpaceProxy.getLatestProposalInformation(_slowPathProposalBisId);
    assertEq(uint8(_slowPathProposalBis.parameters.votingMode), uint8(IDAOSpace.VotingMode.Slow));
    assertTrue(_slowPathProposalBis.executed);
    assertFalse(daoSpaceProxy.hasRole(daoSpaceImplementation.EDITOR(), _eoaSpaceId));
    assertFalse(daoSpaceProxy.hasRole(daoSpaceImplementation.MEMBER(), _eoaSpaceId));
  }

  function test_DefaultGovernance_UpdateProposal() external {
    // Proposal 0: Slow path
    bytes16 _slowPathProposalId = '0';
    _createSlowPathProposal(_slowPathProposalId);
    // Update: Fast path
    _updateProposalPath(_slowPathProposalId, IDAOSpace.VotingMode.Fast);

    Proposal memory _slowPathProposal;
    (, _slowPathProposal.creator, _slowPathProposal.parameters,,) =
      daoSpaceProxy.getLatestProposalInformation(_slowPathProposalId);
    assertEq(_slowPathProposal.creator, _eoaSpaceId);
    assertEq(uint8(_slowPathProposal.parameters.votingMode), uint8(IDAOSpace.VotingMode.Fast));
    assertEq(daoSpaceProxy.latestProposalVersion(_slowPathProposalId), 2);
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
    _restrictSpace();

    assertTrue(daoSpaceProxy.hasRole(daoSpaceImplementation.EDITOR(), _eoaSpaceId));
    assertTrue(daoSpaceProxy.hasRole(daoSpaceImplementation.FAST_PATH_RESTRICTED(), _eoaSpaceId));

    vm.expectRevert(IDAOSpace.FastPathRestricted.selector);
    // Proposal 0: Fast path
    bytes16 _fastPathProposalId = '0';
    _createFastPathProposal(_fastPathProposalId);
  }

  function _createSlowPathProposal(bytes16 _proposalId) internal {
    IDAOSpace.Action[] memory _actions = new IDAOSpace.Action[](1);
    _actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.removeEditor, (_eoaSpaceId))
    });
    bytes memory _createProposalData = abi.encode(_proposalId, IDAOSpace.VotingMode.Slow, _actions);

    vm.prank(eoaSpace);
    // PROPOSAL_CREATED
    spaceRegistryProxy.enter(
      _eoaSpaceId, _daoSpaceProxyId, ActionsConstants.PROPOSAL_CREATED, '', _createProposalData, ''
    );
  }

  function _createFastPathProposal(bytes16 _proposalId) internal {
    IDAOSpace.Action[] memory _actions = new IDAOSpace.Action[](1);
    _actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.removeMember, (_eoaSpaceId))
    });
    bytes memory _createProposalData = abi.encode(_proposalId, IDAOSpace.VotingMode.Fast, _actions);

    vm.prank(eoaSpace);
    // PROPOSAL_CREATED
    spaceRegistryProxy.enter(
      _eoaSpaceId, _daoSpaceProxyId, ActionsConstants.PROPOSAL_CREATED, '', _createProposalData, ''
    );
  }

  function _voteProposal(bytes16 _proposalId, uint8 _proposalVersion, IDAOSpace.VoteOption _voteOption) internal {
    bytes memory _voteProposalData = abi.encode(_proposalId, _proposalVersion, _voteOption);

    vm.prank(eoaSpace);
    // PROPOSAL_VOTED
    spaceRegistryProxy.enter(_eoaSpaceId, _daoSpaceProxyId, ActionsConstants.PROPOSAL_VOTED, '', _voteProposalData, '');
  }

  function _executeProposal(bytes16 _proposalId) internal {
    bytes memory _executeProposalData = abi.encode(_proposalId);

    vm.prank(eoaSpace);
    // PROPOSAL_EXECUTED
    spaceRegistryProxy.enter(
      _eoaSpaceId, _daoSpaceProxyId, ActionsConstants.PROPOSAL_EXECUTED, '', _executeProposalData, ''
    );
  }

  function _updateProposalPath(bytes16 _proposalId, IDAOSpace.VotingMode _votingMode) internal {
    IDAOSpace.Action[] memory _actions = new IDAOSpace.Action[](1);
    _actions[0] = IDAOSpace.Action({
      to: address(daoSpaceProxy), value: 0, data: abi.encodeCall(IDAOSpace.removeMember, (_eoaSpaceId))
    });
    bytes memory _updateProposalData = abi.encode(_proposalId, _votingMode, _actions);

    vm.prank(eoaSpace);
    // PROPOSAL_UPDATED
    spaceRegistryProxy.enter(
      _eoaSpaceId, _daoSpaceProxyId, ActionsConstants.PROPOSAL_UPDATED, '', _updateProposalData, ''
    );
  }

  function _leaveSpace(bytes32 _role) internal {
    bytes memory _leaveSpaceData = abi.encode(_role);

    vm.prank(eoaSpace);
    // SPACE_LEFT
    spaceRegistryProxy.enter(_eoaSpaceId, _daoSpaceProxyId, ActionsConstants.SPACE_LEFT, '', _leaveSpaceData, '');
  }

  function _restrictSpace() internal {
    bytes memory _restrictSpaceData = abi.encode(_eoaSpaceId);

    vm.prank(eoaSpace);
    // SPACE_FAST_PATH_RESTRICTED
    spaceRegistryProxy.enter(
      _eoaSpaceId, _daoSpaceProxyId, ActionsConstants.SPACE_FAST_PATH_RESTRICTED, '', _restrictSpaceData, ''
    );
  }
}
