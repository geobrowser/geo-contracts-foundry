// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {BaseHandler} from './BaseHandler.t.sol';

import {DAOSpace} from 'contracts/DAOSpace.sol';
import {SpaceRegistry} from 'contracts/SpaceRegistry.sol';
import {IDAOSpace} from 'interfaces/IDAOSpace.sol';
import 'src/ActionsConstants.sol' as ActionsConstants;

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
    if (daoSpaceActors.length == 0 || eoaActors.length == 0) {
      lastTxSucceeded = false;
      return;
    }

    address daoSpace = daoSpaceActors[bound(_daoSpaceSeed, 0, daoSpaceActors.length - 1)];
    address newEditor = eoaActors[bound(_editorSeed, 0, eoaActors.length - 1)];
    DAOSpace dao = DAOSpace(daoSpace);

    vm.prank(daoSpace);
    try dao.addEditor(newEditor) {
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
    if (daoSpaceActors.length == 0 || eoaActors.length == 0) {
      lastTxSucceeded = false;
      return;
    }

    address daoSpace = daoSpaceActors[bound(_daoSpaceSeed, 0, daoSpaceActors.length - 1)];
    address editorToRemove = eoaActors[bound(_editorSeed, 0, eoaActors.length - 1)];
    DAOSpace dao = DAOSpace(daoSpace);
    bool wasEditor = dao.hasRole(dao.EDITOR(), editorToRemove);

    vm.prank(daoSpace);
    try dao.removeEditor(editorToRemove) {
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
    if (daoSpaceActors.length == 0 || eoaActors.length == 0) {
      lastTxSucceeded = false;
      return;
    }

    address daoSpace = daoSpaceActors[bound(_daoSpaceSeed, 0, daoSpaceActors.length - 1)];
    address newMember = eoaActors[bound(_memberSeed, 0, eoaActors.length - 1)];
    DAOSpace dao = DAOSpace(daoSpace);

    vm.prank(daoSpace);
    try dao.addMember(newMember) {
      ghost_membersAdded[daoSpace]++;
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function handler_daoSpace_removeMember(uint256 _daoSpaceSeed, uint256 _memberSeed) external {
    if (daoSpaceActors.length == 0 || eoaActors.length == 0) {
      lastTxSucceeded = false;
      return;
    }

    address daoSpace = daoSpaceActors[bound(_daoSpaceSeed, 0, daoSpaceActors.length - 1)];
    address memberToRemove = eoaActors[bound(_memberSeed, 0, eoaActors.length - 1)];
    DAOSpace dao = DAOSpace(daoSpace);
    bool wasMember = dao.hasRole(dao.MEMBER(), memberToRemove);

    vm.prank(daoSpace);
    try dao.removeMember(memberToRemove) {
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
    DAOSpace dao = DAOSpace(daoSpace);

    IDAOSpace.VotingSettings memory newSettings = IDAOSpace.VotingSettings({
      slowPathPercentageThreshold: bound(_thresholdSeed, 0, 2e6),
      fastPathFlatThreshold: bound(_flatThresholdSeed, 0, 100),
      quorum: bound(_quorumSeed, 0, 100),
      duration: bound(_quorumSeed, 0, 30 days)
    });

    vm.prank(daoSpace);
    try dao.updateVotingSettings(newSettings) {
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
    address creator = msg.sender;

    IDAOSpace.VotingMode votingMode = (_votingModeSeed % 2 == 0) ? IDAOSpace.VotingMode.Slow : IDAOSpace.VotingMode.Fast;
    bytes16 proposalId = bytes16(keccak256(abi.encodePacked(daoSpace, ghost_proposalCounter++)));
    IDAOSpace.Action[] memory actions = new IDAOSpace.Action[](1);
    actions[0] =
      IDAOSpace.Action({to: daoSpace, value: 0, data: abi.encodeCall(IDAOSpace.addMember, (address(0x1234)))});
    bytes memory data = abi.encode(proposalId, votingMode, actions);

    vm.prank(creator);
    try spaceRegistry.enter(creator, daoSpace, ActionsConstants.PROPOSAL_CREATED, bytes32(0), data, '') {
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
    address voter = msg.sender;
    if (ghost_activeProposals[daoSpace].length == 0) {
      lastTxSucceeded = false;
      return;
    }

    bytes16 proposalId =
      ghost_activeProposals[daoSpace][bound(_proposalSeed, 0, ghost_activeProposals[daoSpace].length - 1)];
    DAOSpace dao = DAOSpace(daoSpace);
    IDAOSpace.VoteOption voteOption = IDAOSpace.VoteOption(bound(_voteOptionSeed, 1, 3));
    IDAOSpace.VoteOption previousVote = dao.getLatestProposalVote(proposalId, voter);
    bytes memory data = abi.encode(proposalId, voteOption);

    vm.prank(voter);
    try spaceRegistry.enter(voter, daoSpace, ActionsConstants.PROPOSAL_VOTED, bytes32(proposalId), data, '') {
      // Vote changed?
      if (previousVote == IDAOSpace.VoteOption.Yes) ghost_yesVotes[proposalId]--;
      else if (previousVote == IDAOSpace.VoteOption.No) ghost_noVotes[proposalId]--;
      else if (previousVote == IDAOSpace.VoteOption.Abstain) ghost_abstainVotes[proposalId]--;

      if (voteOption == IDAOSpace.VoteOption.Yes) ghost_yesVotes[proposalId]++;
      else if (voteOption == IDAOSpace.VoteOption.No) ghost_noVotes[proposalId]++;
      else if (voteOption == IDAOSpace.VoteOption.Abstain) ghost_abstainVotes[proposalId]++;

      ghost_hasVoted[proposalId][voter] = true;
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
    address executor = msg.sender;
    if (ghost_activeProposals[daoSpace].length == 0) {
      lastTxSucceeded = false;
      return;
    }

    bytes16 proposalId =
      ghost_activeProposals[daoSpace][bound(_proposalSeed, 0, ghost_activeProposals[daoSpace].length - 1)];
    bytes memory data = abi.encode(proposalId);

    vm.prank(executor);
    try spaceRegistry.enter(executor, daoSpace, ActionsConstants.PROPOSAL_EXECUTED, bytes32(proposalId), data, '') {
      ghost_proposalExecuted[proposalId] = true;
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function getActiveProposalsCount(address _daoSpace) external view returns (uint256) {
    return ghost_activeProposals[_daoSpace].length;
  }

  function getActiveProposal(address _daoSpace, uint256 _index) external view returns (bytes16) {
    return ghost_activeProposals[_daoSpace][_index];
  }
}
