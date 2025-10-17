// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

import {IDAO} from '@aragon/osx/core/dao/IDAO.sol';
import {PluginUUPSUpgradeable} from '@aragon/osx/core/plugin/PluginUUPSUpgradeable.sol';
import {ProposalUpgradeable} from '@aragon/osx/core/plugin/proposal/ProposalUpgradeable.sol';
import {RATIO_BASE, RatioOutOfBounds} from '@aragon/osx/plugins/utils/Ratio.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {ERC165Upgradeable} from '@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol';
import {SafeCastUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol';

import {IMajorityVoting} from 'interfaces/governance/base/IMajorityVoting.sol';

/// @title MajorityVotingBase
/// @notice The abstract implementation of majority voting plugins.
/// @notice Adapted to only make use of the required parameters and methods.
///
/// ### Parameterization
///
/// We define two parameters
/// $$\texttt{support} = \frac{N_\text{yes}}{N_\text{yes} + N_\text{no}} \in [0,1]$$
/// and
/// $$\texttt{participation} = \frac{N_\text{yes} + N_\text{no} + N_\text{abstain}}{N_\text{total}} \in [0,1],$$
/// where $N_\text{yes}$, $N_\text{no}$, and $N_\text{abstain}$ are the yes, no, and abstain votes that have been cast and $N_\text{total}$ is the total voting power available at proposal creation time.
///
/// #### Limit Values: Support Threshold & Minimum Participation
///
/// Two limit values are associated with these parameters and decide if a proposal execution should be possible: $\texttt{supportThreshold} \in [0,1]$ and $\texttt{minParticipation} \in [0,1]$.
///
/// For threshold values, $>$ comparison is used. This **does not** include the threshold value. E.g., for $\texttt{supportThreshold} = 50\%$, the criterion is fulfilled if there is at least one more yes than no votes ($N_\text{yes} = N_\text{no} + 1$).
/// For minimum values, $\ge{}$ comparison is used. This **does** include the minimum participation value. E.g., for $\texttt{minParticipation} = 40\%$ and $N_\text{total} = 10$, the criterion is fulfilled if 4 out of 10 votes were casted.
///
/// Majority voting implies that the support threshold is set with
/// $$\texttt{supportThreshold} \ge 50\% .$$
/// However, this is not enforced by the contract code and developers can make unsafe parameters and only the frontend will warn about bad parameter settings.
///
/// ### Execution Criteria
///
/// After the vote is closed, two criteria decide if the proposal passes.
///
/// #### The Support Criterion
///
/// For a proposal to pass, the required ratio of yes and no votes must be met:
/// $$(1- \texttt{supportThreshold}) \cdot N_\text{yes} > \texttt{supportThreshold} \cdot N_\text{no}.$$
/// Note, that the inequality yields the simple majority voting condition for $\texttt{supportThreshold}=\frac{1}{2}$.
///
/// #### The Participation Criterion
///
/// For a proposal to pass, the minimum voting power must have been cast:
/// $$N_\text{yes} + N_\text{no} + N_\text{abstain} \ge \texttt{minVotingPower},$$
/// where $\texttt{minVotingPower} = \texttt{minParticipation} \cdot N_\text{total}$.
///
/// ### Vote Replacement Execution
///
/// The contract allows votes to be replaced. Voters can vote multiple times and only the latest voteOption is tallied.
///
/// ### Early Execution
///
/// This contract allows a proposal to be executed early, iff the vote outcome cannot change anymore by more people voting. Accordingly, vote replacement and early execution are /// mutually exclusive options.
/// The outcome cannot change anymore iff the support threshold is met even if all remaining votes are no votes. We call this number the worst-case number of no votes and define it as
///
/// $$N_\text{no, worst-case} = N_\text{no, worst-case} + \texttt{remainingVotes}$$
///
/// where
///
/// $$\texttt{remainingVotes} = N_\text{total}-\underbrace{(N_\text{yes}+N_\text{no}+N_\text{abstain})}_{\text{turnout}}.$$
///
/// We can use this quantity to calculate the worst-case support that would be obtained if all remaining votes are casted with no:
///
/// $$
/// \begin{align*}
///   \texttt{worstCaseSupport}
///   &= \frac{N_\text{yes}}{N_\text{yes} + (N_\text{no, worst-case})} \\[3mm]
///   &= \frac{N_\text{yes}}{N_\text{yes} + (N_\text{no} + \texttt{remainingVotes})} \\[3mm]
///   &= \frac{N_\text{yes}}{N_\text{yes} +  N_\text{no} + N_\text{total} - (N_\text{yes} + N_\text{no} + N_\text{abstain})} \\[3mm]
///   &= \frac{N_\text{yes}}{N_\text{total} - N_\text{abstain}}
/// \end{align*}
/// $$
///
/// In analogy, we can modify [the support criterion](#the-support-criterion) from above to allow for early execution:
///
/// $$
/// \begin{align*}
///   (1 - \texttt{supportThreshold}) \cdot N_\text{yes}
///   &> \texttt{supportThreshold} \cdot  N_\text{no, worst-case} \\[3mm]
///   &> \texttt{supportThreshold} \cdot (N_\text{no} + \texttt{remainingVotes}) \\[3mm]
///   &> \texttt{supportThreshold} \cdot (N_\text{no} + N_\text{total}-(N_\text{yes}+N_\text{no}+N_\text{abstain})) \\[3mm]
///   &> \texttt{supportThreshold} \cdot (N_\text{total} - N_\text{yes} - N_\text{abstain})
/// \end{align*}
/// $$
///
/// Accordingly, early execution is possible when the vote is open, the modified support criterion, and the particicpation criterion are met.
/// @dev This contract implements the `IMajorityVoting` interface.
abstract contract MajorityVotingBase is
  Initializable,
  ERC165Upgradeable,
  PluginUUPSUpgradeable,
  ProposalUpgradeable,
  IMajorityVoting
{
  using SafeCastUpgradeable for uint256;

  /// @inheritdoc IMajorityVoting
  bytes32 public constant UPDATE_VOTING_SETTINGS_PERMISSION_ID = keccak256('UPDATE_VOTING_SETTINGS_PERMISSION');

  /// @notice A mapping between proposal IDs and proposal information.
  mapping(uint256 => Proposal) internal proposals;

  /// @notice The struct storing the voting settings.
  VotingSettings private votingSettings;

  /// @notice Initializes the component to be used by inheriting contracts.
  /// @dev This method is required to support [ERC-1822](https://eips.ethereum.org/EIPS/eip-1822).
  /// @param _dao The IDAO interface of the associated DAO.
  /// @param _votingSettings The voting settings.
  function __MajorityVotingBase_init(IDAO _dao, VotingSettings calldata _votingSettings) internal onlyInitializing {
    __PluginUUPSUpgradeable_init(_dao);
    _updateVotingSettings(_votingSettings);
  }

  /// @notice Checks if this or the parent contract supports an interface by its ID.
  /// @param _interfaceId The ID of the interface.
  /// @return Returns `true` if the interface is supported.
  function supportsInterface(bytes4 _interfaceId)
    public
    view
    virtual
    override(ERC165Upgradeable, PluginUUPSUpgradeable, ProposalUpgradeable)
    returns (bool)
  {
    return _interfaceId == type(IMajorityVoting).interfaceId || _interfaceId == type(IMajorityVoting).interfaceId
      || super.supportsInterface(_interfaceId);
  }

  /// @inheritdoc IMajorityVoting
  function vote(uint256 _proposalId, VoteOption _voteOption, bool _tryEarlyExecution) public virtual {
    if (!_canVote(_proposalId, msg.sender, _voteOption)) {
      revert VoteCastForbidden({proposalId: _proposalId, account: msg.sender, voteOption: _voteOption});
    }
    _vote(_proposalId, _voteOption, msg.sender, _tryEarlyExecution);
  }

  /// @inheritdoc IMajorityVoting
  function execute(uint256 _proposalId) public virtual {
    if (!_canExecute(_proposalId)) {
      revert ProposalExecutionForbidden(_proposalId);
    }
    _execute(_proposalId);
  }

  /// @inheritdoc IMajorityVoting
  function getVoteOption(uint256 _proposalId, address _voter) public view virtual returns (VoteOption) {
    return proposals[_proposalId].voters[_voter];
  }

  /// @inheritdoc IMajorityVoting
  function canVote(uint256 _proposalId, address _voter, VoteOption _voteOption) public view virtual returns (bool) {
    return _canVote(_proposalId, _voter, _voteOption);
  }

  /// @inheritdoc IMajorityVoting
  function canExecute(uint256 _proposalId) public view virtual returns (bool) {
    return _canExecute(_proposalId);
  }

  /// @inheritdoc IMajorityVoting
  function isSupportThresholdReached(uint256 _proposalId) public view virtual returns (bool) {
    Proposal storage proposal_ = proposals[_proposalId];

    uint32 supportThresholdPercentage = getSupportThresholdPercentage(_proposalId);

    // The code below implements the formula of the support criterion explained in the top of this file.
    // `(1 - supportThresholdPercentage) * N_yes > supportThresholdPercentage *  N_no`
    return
      (RATIO_BASE - supportThresholdPercentage) * proposal_.tally.yes > supportThresholdPercentage * proposal_.tally.no;
  }

  /// @inheritdoc IMajorityVoting
  function isSupportThresholdReachedEarly(uint256 _proposalId) public view virtual returns (bool) {
    Proposal storage proposal_ = proposals[_proposalId];

    uint32 supportThresholdPercentage = getSupportThresholdPercentage(_proposalId);
    uint256 noVotesWorstCase =
      totalVotingPower(proposal_.parameters.snapshotBlock) - proposal_.tally.yes - proposal_.tally.abstain;

    // The code below implements the formula of the early execution support criterion explained in the top of this file.
    // `(1 - supportThresholdPercentage) * N_yes > supportThresholdPercentage *  N_no,worst-case`
    return
      (RATIO_BASE - supportThresholdPercentage) * proposal_.tally.yes > supportThresholdPercentage * noVotesWorstCase;
  }

  /// @inheritdoc IMajorityVoting
  function isMinParticipationReached(uint256 _proposalId) public view virtual returns (bool);

  /// @inheritdoc IMajorityVoting
  function supportThreshold() public view virtual returns (uint32) {
    return votingSettings.supportThreshold;
  }

  /// @inheritdoc IMajorityVoting
  function duration() public view virtual returns (uint64) {
    return votingSettings.duration;
  }

  /// @inheritdoc IMajorityVoting
  function votingMode() public view virtual returns (VotingMode) {
    return votingSettings.votingMode;
  }

  /// @inheritdoc IMajorityVoting
  function thresholdMode() public view virtual returns (ThresholdMode) {
    return votingSettings.thresholdMode;
  }

  /// @inheritdoc IMajorityVoting
  function getSupportThresholdPercentage(uint256 _proposalId) public view virtual returns (uint32) {
    Proposal storage proposal_ = proposals[_proposalId];

    // If the threshold value is zero, return zero
    if (proposal_.parameters.supportThreshold == 0) return 0;

    // Require the support threshold value to be in the interval [0, 10^6-1], because `>` comparison is used in the support criterion and >100% could never be reached.
    if (proposal_.parameters.thresholdMode == ThresholdMode.Percentage) {
      return proposal_.parameters.supportThreshold - 1;
    } else {
      // Fetch total voters to convert flat threshold to a percentage
      uint256 totalVoters = totalVotingPower(proposal_.parameters.snapshotBlock);
      // If no voters exist, return zero
      if (totalVoters == 0) return 0;
      // If the flat threshold exceeds the total number of voters, everyone must vote
      if (uint256(proposal_.parameters.supportThreshold) >= totalVoters) {
        return uint32(RATIO_BASE) - 1;
      }
      // Else dynamically determine the threshold percentage
      return uint32((uint256(proposal_.parameters.supportThreshold) * RATIO_BASE) / totalVoters) - 1;
    }
  }

  /// @inheritdoc IMajorityVoting
  function totalVotingPower(uint256 _blockNumber) public view virtual returns (uint256);

  /// @inheritdoc IMajorityVoting
  function getProposal(uint256 _proposalId)
    public
    view
    virtual
    returns (
      bool open,
      bool executed,
      ProposalParameters memory parameters,
      Tally memory tally,
      IDAO.Action[] memory actions,
      uint256 allowFailureMap
    )
  {
    Proposal storage proposal_ = proposals[_proposalId];

    open = _isProposalOpen(proposal_);
    executed = proposal_.executed;
    parameters = proposal_.parameters;
    tally = proposal_.tally;
    actions = proposal_.actions;
    allowFailureMap = proposal_.allowFailureMap;
  }

  /// @inheritdoc IMajorityVoting
  function updateVotingSettings(VotingSettings calldata _votingSettings)
    external
    virtual
    auth(UPDATE_VOTING_SETTINGS_PERMISSION_ID)
  {
    _updateVotingSettings(_votingSettings);
  }

  /// @notice Internal function to cast a vote. It assumes the queried vote exists.
  /// @param _proposalId The ID of the proposal.
  /// @param _voteOption The chosen vote option to be casted on the proposal vote.
  /// @param _tryEarlyExecution If `true`,  early execution is tried after the vote cast. The call does not revert if early execution is not possible.
  function _vote(uint256 _proposalId, VoteOption _voteOption, address _voter, bool _tryEarlyExecution) internal virtual;

  /// @notice Internal function to execute a vote. It assumes the queried proposal exists.
  /// @param _proposalId The ID of the proposal.
  function _execute(uint256 _proposalId) internal virtual {
    proposals[_proposalId].executed = true;

    _executeProposal(dao(), _proposalId, proposals[_proposalId].actions, proposals[_proposalId].allowFailureMap);
  }

  /// @notice Internal function to check if a voter can vote. It assumes the queried proposal exists.
  /// @param _proposalId The ID of the proposal.
  /// @param _voter The address of the voter to check.
  /// @param  _voteOption Whether the voter abstains, supports or opposes the proposal.
  /// @return Returns `true` if the given voter can vote on a certain proposal and `false` otherwise.
  function _canVote(uint256 _proposalId, address _voter, VoteOption _voteOption) internal view virtual returns (bool);

  /// @notice Internal function to check if a proposal can be executed. It assumes the queried proposal exists.
  /// @param _proposalId The ID of the proposal.
  /// @return True if the proposal can be executed, false otherwise.
  /// @dev Threshold and minimal values are compared with `>` and `>=` comparators, respectively.
  function _canExecute(uint256 _proposalId) internal view virtual returns (bool) {
    Proposal storage proposal_ = proposals[_proposalId];

    // Verify that the vote has not been executed already.
    if (proposal_.executed) {
      return false;
    }

    if (_isProposalOpen(proposal_)) {
      // Early execution
      if (proposal_.parameters.votingMode != VotingMode.EarlyExecution) {
        return false;
      }
      if (!isSupportThresholdReachedEarly(_proposalId)) {
        return false;
      }
    } else {
      // Normal execution
      if (!isSupportThresholdReached(_proposalId)) {
        return false;
      }
    }
    if (!isMinParticipationReached(_proposalId)) {
      return false;
    }

    return true;
  }

  /// @notice Internal function to check if a proposal vote is still open.
  /// @param proposal_ The proposal struct.
  /// @return True if the proposal vote is open, false otherwise.
  function _isProposalOpen(Proposal storage proposal_) internal view virtual returns (bool) {
    uint64 currentTime = block.timestamp.toUint64();

    return
      proposal_.parameters.startDate <= currentTime && currentTime < proposal_.parameters.endDate && !proposal_.executed;
  }

  /// @notice Internal function to update the plugin-wide proposal vote settings.
  /// @param _votingSettings The voting settings to be validated and updated.
  function _updateVotingSettings(VotingSettings calldata _votingSettings) internal virtual {
    if (_votingSettings.thresholdMode == ThresholdMode.Percentage) {
      if (_votingSettings.supportThreshold > RATIO_BASE) {
        revert RatioOutOfBounds({limit: RATIO_BASE, actual: _votingSettings.supportThreshold});
      }
    }

    if (_votingSettings.duration < 60 minutes) {
      revert DurationOutOfBounds({limit: 60 minutes, actual: _votingSettings.duration});
    } else if (_votingSettings.duration > 365 days) {
      revert DurationOutOfBounds({limit: 365 days, actual: _votingSettings.duration});
    }

    votingSettings = _votingSettings;

    emit VotingSettingsUpdated({
      votingMode: _votingSettings.votingMode,
      thresholdMode: _votingSettings.thresholdMode,
      supportThreshold: _votingSettings.supportThreshold,
      duration: _votingSettings.duration
    });
  }

  /// @notice Validates and returns the proposal vote dates.
  /// @param _start The start date of the proposal vote. If 0, the current timestamp is used and the vote starts immediately.
  /// @param _end The end date of the proposal vote. If 0, `_start + duration` is used.
  /// @return startDate The validated start date of the proposal vote.
  /// @return endDate The validated end date of the proposal vote.
  function _validateProposalDates(
    uint64 _start,
    uint64 _end
  ) internal view virtual returns (uint64 startDate, uint64 endDate) {
    uint64 currentTimestamp = block.timestamp.toUint64();

    if (_start == 0) {
      startDate = currentTimestamp;
    } else {
      startDate = _start;

      if (startDate < currentTimestamp) {
        revert DateOutOfBounds({limit: currentTimestamp, actual: startDate});
      }
    }

    uint64 earliestEndDate = startDate + votingSettings.duration; // Since `duration` is limited to 1 year, `startDate + duration` can only overflow if the `startDate` is after `type(uint64).max - duration`. In this case, the proposal creation will revert and another date can be picked.

    if (_end == 0) {
      endDate = earliestEndDate;
    } else {
      endDate = _end;

      if (endDate < earliestEndDate) {
        revert DateOutOfBounds({limit: earliestEndDate, actual: endDate});
      }
    }
  }

  /// @notice This empty reserved space is put in place to allow future versions to add new variables without shifting down storage in the inheritance chain (see [OpenZeppelin's guide about storage gaps](https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps)).
  uint256[48] private __gap;
}
