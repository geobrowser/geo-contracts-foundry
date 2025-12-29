// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {DAOSpace} from 'contracts/DAOSpace.sol';

/**
 * @title MockDAOSpace
 * @notice Mock contract for testing DAOSpace with additional test helper functions
 */
contract MockDAOSpace is DAOSpace {
  function workaround_createProposal(
    bytes16 _proposalId,
    bool _executed,
    uint8 _version,
    address _creator,
    uint256 _startDate,
    uint256 _lastDate,
    VotingMode _votingMode,
    uint256 _supportThreshold,
    uint256 _quorum,
    Action[] memory _actions
  ) external {
    DAOSpaceStorage storage $ = _getDAOSpaceStorage();
    $.latestProposalVersion[_proposalId] = _version;
    Proposal storage proposal_ = _getLatestProposalStorage(_proposalId);
    proposal_.executed = _executed;
    proposal_.creator = _creator;
    proposal_.parameters.startDate = _startDate;
    proposal_.parameters.lastDate = _lastDate;
    proposal_.parameters.votingMode = _votingMode;
    proposal_.parameters.supportThreshold = _supportThreshold;
    proposal_.parameters.quorum = _quorum;
    for (uint256 i; i < _actions.length; i++) {
      proposal_.actions.push(_actions[i]);
    }
  }

  function workaround_setFormerVote(bytes16 _proposalId, address _account, VoteOption _voteOption) external {
    Proposal storage proposal_ = _getLatestProposalStorage(_proposalId);
    if (_voteOption == VoteOption.Yes) {
      proposal_.tally.yes = proposal_.tally.yes + 1;
    } else if (_voteOption == VoteOption.No) {
      proposal_.tally.no = proposal_.tally.no + 1;
    } else if (_voteOption == VoteOption.Abstain) {
      proposal_.tally.abstain = proposal_.tally.abstain + 1;
    }
    proposal_.voters[_account] = _voteOption;
  }

  function workaround_setTally(bytes16 _proposalId, uint256 _yes, uint256 _no, uint256 _abstain) external {
    Proposal storage proposal_ = _getLatestProposalStorage(_proposalId);
    proposal_.tally.yes = _yes;
    proposal_.tally.no = _no;
    proposal_.tally.abstain = _abstain;
  }

  function workaround_setVotingSettings(VotingSettings calldata _votingSettings) external {
    DAOSpaceStorage storage $ = _getDAOSpaceStorage();
    $.votingSettings = _votingSettings;
  }

  function workaround_grantRole(bytes32 _role, address _account) external returns (bytes16 _spaceId) {
    return _grantRole(_role, _account);
  }

  function workaround_revokeRole(bytes32 _role, address _account) external returns (bytes16 _spaceId) {
    return _revokeRole(_role, _account);
  }

  function exposed__DAO_SPACE_STORAGE_LOCATION() external pure returns (bytes32 _daoSpaceStorageLocation) {
    _daoSpaceStorageLocation = _DAO_SPACE_STORAGE_LOCATION;
  }
}
