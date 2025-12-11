// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {DAOSpace} from 'contracts/DAOSpace.sol';

/**
 * @title MockDAOSpace
 * @notice Mock contract for testing DAOSpace with additional test helper functions
 */
contract MockDAOSpace is DAOSpace {
  function workaround_setEditorToFlagged(address _account, bool _flagged) external {
    isEditorFlagged[_account] = _flagged;
  }

  function workaround_createProposal(
    uint256 _proposalId,
    uint256 _startDate,
    uint256 _lastDate,
    VotingMode _votingMode,
    uint256 _supportThreshold,
    uint256 _quorum,
    Action[] memory _actions,
    bool _executed
  ) external {
    Proposal storage proposal_ = _proposals[_proposalId];
    proposal_.parameters.startDate = _startDate;
    proposal_.parameters.lastDate = _lastDate;
    proposal_.parameters.votingMode = _votingMode;
    proposal_.parameters.supportThreshold = _supportThreshold;
    proposal_.parameters.quorum = _quorum;
    for (uint256 i; i < _actions.length; i++) {
      proposal_.actions.push(_actions[i]);
    }
    proposal_.executed = _executed;
  }

  function workaround_setFormerVote(uint256 _proposalId, address _account, VoteOption _voteOption) external {
    Proposal storage proposal_ = _proposals[_proposalId];
    if (_voteOption == VoteOption.Yes) {
      proposal_.tally.yes = proposal_.tally.yes + 1;
    } else if (_voteOption == VoteOption.No) {
      proposal_.tally.no = proposal_.tally.no + 1;
    } else if (_voteOption == VoteOption.Abstain) {
      proposal_.tally.abstain = proposal_.tally.abstain + 1;
    }
    proposal_.voters[_account] = _voteOption;
  }

  function workaround_setTally(uint256 _proposalId, uint256 _yes, uint256 _no, uint256 _abstain) external {
    Proposal storage proposal_ = _proposals[_proposalId];
    proposal_.tally.yes = _yes;
    proposal_.tally.no = _no;
    proposal_.tally.abstain = _abstain;
  }

  function workaround_setVotingSettings(VotingSettings calldata _votingSettings) external {
    votingSettings = _votingSettings;
  }
}
