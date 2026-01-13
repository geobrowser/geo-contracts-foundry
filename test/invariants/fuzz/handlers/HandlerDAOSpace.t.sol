// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {DAOSpace} from 'contracts/DAOSpace.sol';
import {SpaceRegistry} from 'contracts/SpaceRegistry.sol';
import {IDAOSpace} from 'interfaces/IDAOSpace.sol';
import 'src/ActionsConstants.sol' as ActionsConstants;

import {BaseHandler} from 'test/invariants/fuzz/handlers/BaseHandler.t.sol';

/// @notice Handler for DAOSpace governance operations
contract HandlerDAOSpace is BaseHandler {
  bool public lastTxSucceeded;

  constructor(
    SpaceRegistry _spaceRegistry,
    address[] memory _eoaActors,
    address[] memory _daoSpaceActors,
    address[] memory _verifierSpaceActors
  ) BaseHandler(_spaceRegistry, _eoaActors, _daoSpaceActors, _verifierSpaceActors) {}

  function handler_daoSpace_addEditor(uint256 _daoSpaceSeed, uint256 _editorSeed) external {
    if (!_hasActors()) return;

    address daoSpace = daoSpaceActors[bound(_daoSpaceSeed, 0, daoSpaceActors.length - 1)];
    address newEditor = eoaActors[bound(_editorSeed, 0, eoaActors.length - 1)];
    bytes16 newEditorSpaceId = spaceRegistry.addressToSpaceId(newEditor);

    vm.prank(daoSpace);
    try DAOSpace(daoSpace).addEditor(newEditorSpaceId) {
      ghost_editorsAdded[daoSpace]++;
      if (!ghost_isEditor[daoSpace][newEditor]) {
        ghost_daoEditors[daoSpace].push(newEditor);
        ghost_isEditor[daoSpace][newEditor] = true;
      }
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function handler_daoSpace_removeEditor(uint256 _daoSpaceSeed, uint256 _editorSeed) external {
    if (!_hasActors()) return;

    address daoSpace = daoSpaceActors[bound(_daoSpaceSeed, 0, daoSpaceActors.length - 1)];
    address editorToRemove = eoaActors[bound(_editorSeed, 0, eoaActors.length - 1)];
    bytes16 editorSpaceId = spaceRegistry.addressToSpaceId(editorToRemove);
    DAOSpace dao = DAOSpace(daoSpace);
    bool wasEditor = dao.hasRole(dao.EDITOR(), editorSpaceId);

    vm.prank(daoSpace);
    try dao.removeEditor(editorSpaceId) {
      if (wasEditor) {
        ghost_editorsRemoved[daoSpace]++;
        ghost_isEditor[daoSpace][editorToRemove] = false;
      }
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function handler_daoSpace_addMember(uint256 _daoSpaceSeed, uint256 _memberSeed) external {
    if (!_hasActors()) return;

    address daoSpace = daoSpaceActors[bound(_daoSpaceSeed, 0, daoSpaceActors.length - 1)];
    address newMember = eoaActors[bound(_memberSeed, 0, eoaActors.length - 1)];
    bytes16 newMemberSpaceId = spaceRegistry.addressToSpaceId(newMember);

    vm.prank(daoSpace);
    try DAOSpace(daoSpace).addMember(newMemberSpaceId) {
      ghost_membersAdded[daoSpace]++;
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function handler_daoSpace_removeMember(uint256 _daoSpaceSeed, uint256 _memberSeed) external {
    if (!_hasActors()) return;

    address daoSpace = daoSpaceActors[bound(_daoSpaceSeed, 0, daoSpaceActors.length - 1)];
    address memberToRemove = eoaActors[bound(_memberSeed, 0, eoaActors.length - 1)];
    bytes16 memberSpaceId = spaceRegistry.addressToSpaceId(memberToRemove);
    DAOSpace dao = DAOSpace(daoSpace);
    bool wasMember = dao.hasRole(dao.MEMBER(), memberSpaceId);

    vm.prank(daoSpace);
    try dao.removeMember(memberSpaceId) {
      if (wasMember) {
        ghost_membersRemoved[daoSpace]++;
      }
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function handler_daoSpace_updateVotingSettings(
    uint256 _daoSpaceSeed,
    uint256 _thresholdSeed,
    uint256 _flatThresholdSeed,
    uint256 _quorumSeed
  ) external {
    if (daoSpaceActors.length == 0) {
      lastTxSucceeded = false;
      return;
    }

    address daoSpace = daoSpaceActors[bound(_daoSpaceSeed, 0, daoSpaceActors.length - 1)];
    IDAOSpace.VotingSettings memory newSettings = IDAOSpace.VotingSettings({
      slowPathPercentageThreshold: bound(_thresholdSeed, 0, 2e6),
      fastPathFlatThreshold: bound(_flatThresholdSeed, 0, 100),
      quorum: bound(_quorumSeed, 0, 100),
      duration: bound(_quorumSeed, 0, 30 days)
    });

    vm.prank(daoSpace);
    try DAOSpace(daoSpace).updateVotingSettings(newSettings) {
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function handler_daoSpace_createProposal(uint256 _daoSpaceSeed, uint256 _votingModeSeed) external {
    if (daoSpaceActors.length == 0) {
      lastTxSucceeded = false;
      return;
    }

    address daoSpace = daoSpaceActors[bound(_daoSpaceSeed, 0, daoSpaceActors.length - 1)];
    bytes16 daoSpaceId = spaceRegistry.addressToSpaceId(daoSpace);
    bytes16 senderSpaceId = spaceRegistry.addressToSpaceId(msg.sender);
    bytes16 proposalId = bytes16(keccak256(abi.encodePacked(daoSpace, ghost_proposalCounter++)));
    IDAOSpace.VotingMode votingMode = (_votingModeSeed % 2 == 0) ? IDAOSpace.VotingMode.Slow : IDAOSpace.VotingMode.Fast;

    IDAOSpace.Action[] memory actions = new IDAOSpace.Action[](1);
    actions[0] = IDAOSpace.Action({
      to: daoSpace, value: 0, data: abi.encodeCall(IDAOSpace.addMember, (bytes16(0x12340000000000000000000000000000)))
    });

    vm.prank(msg.sender);
    try spaceRegistry.enter(
      senderSpaceId,
      daoSpaceId,
      ActionsConstants.PROPOSAL_CREATED,
      bytes32(0),
      abi.encode(proposalId, votingMode, actions),
      ''
    ) {
      ghost_activeProposals[daoSpace].push(proposalId);
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function handler_daoSpace_vote(uint256 _daoSpaceSeed, uint256 _proposalSeed, uint256 _voteOptionSeed) external {
    if (daoSpaceActors.length == 0) {
      lastTxSucceeded = false;
      return;
    }

    address daoSpace = daoSpaceActors[bound(_daoSpaceSeed, 0, daoSpaceActors.length - 1)];
    if (ghost_activeProposals[daoSpace].length == 0) {
      lastTxSucceeded = false;
      return;
    }

    bytes16 daoSpaceId = spaceRegistry.addressToSpaceId(daoSpace);
    bytes16 senderSpaceId = spaceRegistry.addressToSpaceId(msg.sender);
    bytes16 proposalId =
      ghost_activeProposals[daoSpace][bound(_proposalSeed, 0, ghost_activeProposals[daoSpace].length - 1)];
    IDAOSpace.VoteOption voteOption = IDAOSpace.VoteOption(bound(_voteOptionSeed, 1, 3));
    IDAOSpace.VoteOption previousVote = DAOSpace(daoSpace).getLatestProposalVote(proposalId, senderSpaceId);

    vm.prank(msg.sender);
    try spaceRegistry.enter(
      senderSpaceId,
      daoSpaceId,
      ActionsConstants.PROPOSAL_VOTED,
      bytes32(proposalId),
      abi.encode(proposalId, voteOption),
      ''
    ) {
      _updateVoteTally(proposalId, previousVote, voteOption);
      ghost_hasVoted[proposalId][msg.sender] = true;
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function handler_daoSpace_execute(uint256 _daoSpaceSeed, uint256 _proposalSeed) external {
    if (daoSpaceActors.length == 0) {
      lastTxSucceeded = false;
      return;
    }

    address daoSpace = daoSpaceActors[bound(_daoSpaceSeed, 0, daoSpaceActors.length - 1)];
    if (ghost_activeProposals[daoSpace].length == 0) {
      lastTxSucceeded = false;
      return;
    }

    bytes16 daoSpaceId = spaceRegistry.addressToSpaceId(daoSpace);
    bytes16 senderSpaceId = spaceRegistry.addressToSpaceId(msg.sender);
    bytes16 proposalId =
      ghost_activeProposals[daoSpace][bound(_proposalSeed, 0, ghost_activeProposals[daoSpace].length - 1)];

    vm.prank(msg.sender);
    try spaceRegistry.enter(
      senderSpaceId, daoSpaceId, ActionsConstants.PROPOSAL_EXECUTED, bytes32(proposalId), abi.encode(proposalId), ''
    ) {
      ghost_proposalExecuted[proposalId] = true;
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function _hasActors() internal returns (bool _actorExists) {
    if (daoSpaceActors.length == 0 || eoaActors.length == 0) {
      lastTxSucceeded = false;
      return false;
    }
    return true;
  }

  function _updateVoteTally(
    bytes16 _proposalId,
    IDAOSpace.VoteOption _previousVote,
    IDAOSpace.VoteOption _newVote
  ) internal {
    if (_previousVote == IDAOSpace.VoteOption.Yes) {
      ghost_yesVotes[_proposalId]--;
    } else if (_previousVote == IDAOSpace.VoteOption.No) {
      ghost_noVotes[_proposalId]--;
    } else if (_previousVote == IDAOSpace.VoteOption.Abstain) {
      ghost_abstainVotes[_proposalId]--;
    }

    if (_newVote == IDAOSpace.VoteOption.Yes) ghost_yesVotes[_proposalId]++;
    else if (_newVote == IDAOSpace.VoteOption.No) ghost_noVotes[_proposalId]++;
    else if (_newVote == IDAOSpace.VoteOption.Abstain) ghost_abstainVotes[_proposalId]++;
  }
}
