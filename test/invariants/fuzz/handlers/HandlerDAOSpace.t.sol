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

    address _daoSpace = daoSpaceActors[bound(_daoSpaceSeed, 0, daoSpaceActors.length - 1)];
    address _newEditor = eoaActors[bound(_editorSeed, 0, eoaActors.length - 1)];
    bytes16 _newEditorSpaceId = spaceRegistry.addressToSpaceId(_newEditor);

    vm.prank(_daoSpace);
    try DAOSpace(_daoSpace).addEditor(_newEditorSpaceId) {
      ghost_editorsAdded[_daoSpace]++;
      if (!ghost_isEditor[_daoSpace][_newEditor]) {
        ghost_daoEditors[_daoSpace].push(_newEditor);
        ghost_isEditor[_daoSpace][_newEditor] = true;
      }
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function handler_daoSpace_removeEditor(uint256 _daoSpaceSeed, uint256 _editorSeed) external {
    if (!_hasActors()) return;

    address _daoSpace = daoSpaceActors[bound(_daoSpaceSeed, 0, daoSpaceActors.length - 1)];
    address _editorToRemove = eoaActors[bound(_editorSeed, 0, eoaActors.length - 1)];
    bytes16 _editorSpaceId = spaceRegistry.addressToSpaceId(_editorToRemove);
    DAOSpace _dao = DAOSpace(_daoSpace);
    bool _wasEditor = _dao.hasRole(_dao.EDITOR(), _editorSpaceId);

    vm.prank(_daoSpace);
    try _dao.removeEditor(_editorSpaceId) {
      if (_wasEditor) {
        ghost_editorsRemoved[_daoSpace]++;
        ghost_isEditor[_daoSpace][_editorToRemove] = false;
      }
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function handler_daoSpace_addMember(uint256 _daoSpaceSeed, uint256 _memberSeed) external {
    if (!_hasActors()) return;

    address _daoSpace = daoSpaceActors[bound(_daoSpaceSeed, 0, daoSpaceActors.length - 1)];
    address _newMember = eoaActors[bound(_memberSeed, 0, eoaActors.length - 1)];
    bytes16 _newMemberSpaceId = spaceRegistry.addressToSpaceId(_newMember);

    vm.prank(_daoSpace);
    try DAOSpace(_daoSpace).addMember(_newMemberSpaceId) {
      ghost_membersAdded[_daoSpace]++;
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function handler_daoSpace_removeMember(uint256 _daoSpaceSeed, uint256 _memberSeed) external {
    if (!_hasActors()) return;

    address _daoSpace = daoSpaceActors[bound(_daoSpaceSeed, 0, daoSpaceActors.length - 1)];
    address _memberToRemove = eoaActors[bound(_memberSeed, 0, eoaActors.length - 1)];
    bytes16 _memberSpaceId = spaceRegistry.addressToSpaceId(_memberToRemove);
    DAOSpace _dao = DAOSpace(_daoSpace);
    bool _wasMember = _dao.hasRole(_dao.MEMBER(), _memberSpaceId);

    vm.prank(_daoSpace);
    try _dao.removeMember(_memberSpaceId) {
      if (_wasMember) {
        ghost_membersRemoved[_daoSpace]++;
      }
      lastTxSucceeded = true;
    } catch {
      lastTxSucceeded = false;
    }
  }

  function handler_daoSpace_updateVotingSettings(
    uint256 _daoSpaceSeed,
    uint256 _partialPercentageThresholdSeed,
    uint256 _universalPercentageThresholdSeed,
    uint256 _flatThresholdSeed,
    uint256 _quorumSeed
  ) external {
    if (daoSpaceActors.length == 0) {
      lastTxSucceeded = false;
      return;
    }

    address _daoSpace = daoSpaceActors[bound(_daoSpaceSeed, 0, daoSpaceActors.length - 1)];
    IDAOSpace.VotingSettings memory _newSettings = IDAOSpace.VotingSettings({
      partialPercentageSupportThreshold: bound(_partialPercentageThresholdSeed, 0, 2e6),
      universalPercentageSupportThreshold: bound(_universalPercentageThresholdSeed, 0, 2e6),
      flatSupportThreshold: bound(_flatThresholdSeed, 0, 100),
      quorum: bound(_quorumSeed, 0, 100),
      duration: bound(_quorumSeed, 0, 30 days),
      defaultFastPathAccessForMembers: _thresholdSeed % 2 == 0
    });

    vm.prank(_daoSpace);
    try DAOSpace(_daoSpace).updateVotingSettings(_newSettings) {
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

    address _daoSpace = daoSpaceActors[bound(_daoSpaceSeed, 0, daoSpaceActors.length - 1)];
    bytes16 _daoSpaceId = spaceRegistry.addressToSpaceId(_daoSpace);
    bytes16 _senderSpaceId = spaceRegistry.addressToSpaceId(msg.sender);
    bytes16 _proposalId = bytes16(keccak256(abi.encodePacked(_daoSpace, ghost_proposalCounter++)));
    IDAOSpace.VotingMode _votingMode =
      (_votingModeSeed % 2 == 0) ? IDAOSpace.VotingMode.Slow : IDAOSpace.VotingMode.Fast;

    IDAOSpace.Action[] memory _actions = new IDAOSpace.Action[](1);
    _actions[0] = IDAOSpace.Action({
      to: _daoSpace, value: 0, data: abi.encodeCall(IDAOSpace.addMember, (bytes16(0x12340000000000000000000000000000)))
    });

    vm.prank(msg.sender);
    try spaceRegistry.enter(
      _senderSpaceId,
      _daoSpaceId,
      ActionsConstants.PROPOSAL_CREATED,
      bytes32(0),
      abi.encode(_proposalId, _votingMode, _actions),
      ''
    ) {
      ghost_activeProposals[_daoSpace].push(_proposalId);
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

    address _daoSpace = daoSpaceActors[bound(_daoSpaceSeed, 0, daoSpaceActors.length - 1)];
    if (ghost_activeProposals[_daoSpace].length == 0) {
      lastTxSucceeded = false;
      return;
    }

    bytes16 _daoSpaceId = spaceRegistry.addressToSpaceId(_daoSpace);
    bytes16 _senderSpaceId = spaceRegistry.addressToSpaceId(msg.sender);
    bytes16 _proposalId =
      ghost_activeProposals[_daoSpace][bound(_proposalSeed, 0, ghost_activeProposals[_daoSpace].length - 1)];
    IDAOSpace.VoteOption _voteOption = IDAOSpace.VoteOption(bound(_voteOptionSeed, 1, 3));
    IDAOSpace.VoteOption _previousVote = DAOSpace(_daoSpace).getLatestProposalVote(_proposalId, _senderSpaceId);

    vm.prank(msg.sender);
    try spaceRegistry.enter(
      _senderSpaceId,
      _daoSpaceId,
      ActionsConstants.PROPOSAL_VOTED,
      bytes32(_proposalId),
      abi.encode(_proposalId, _voteOption),
      ''
    ) {
      _updateVoteTally(_proposalId, _previousVote, _voteOption);
      ghost_hasVoted[_proposalId][msg.sender] = true;
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

    address _daoSpace = daoSpaceActors[bound(_daoSpaceSeed, 0, daoSpaceActors.length - 1)];
    if (ghost_activeProposals[_daoSpace].length == 0) {
      lastTxSucceeded = false;
      return;
    }

    bytes16 _daoSpaceId = spaceRegistry.addressToSpaceId(_daoSpace);
    bytes16 _senderSpaceId = spaceRegistry.addressToSpaceId(msg.sender);
    bytes16 _proposalId =
      ghost_activeProposals[_daoSpace][bound(_proposalSeed, 0, ghost_activeProposals[_daoSpace].length - 1)];

    vm.prank(msg.sender);
    try spaceRegistry.enter(
      _senderSpaceId, _daoSpaceId, ActionsConstants.PROPOSAL_EXECUTED, bytes32(_proposalId), abi.encode(_proposalId), ''
    ) {
      ghost_proposalExecuted[_proposalId] = true;
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
