// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

import {ISpace} from 'interfaces/ISpace.sol';
import {ISpaceRegistry} from 'interfaces/registry/ISpaceRegistry.sol';

/**
 * @title DAO Space Interface
 * @notice Manages governance proposals and voting for a DAO Space
 */
interface IDAOSpace is ISpace {
  /**
   * @notice Vote options that a voter can choose from
   * @param None The default option state of a voter indicating the absence from the vote.
   * This option neither influences support nor participation.
   * @param Abstain This option does not influence the support but counts towards participation.
   * @param Yes This option increases the support and counts towards participation.
   * @param No This option decreases the support and counts towards participation.
   */
  enum VoteOption {
    None,
    Abstain,
    Yes,
    No
  }

  /**
   * @notice The different voting modes available
   * @param Standard In standard mode, early execution and vote replacement are disabled.
   * @param EarlyExecution In early execution mode, a proposal can be executed early before
   * the end date if the vote outcome cannot mathematically change by more voters voting.
   * @param VoteReplacement In vote replacement mode, voters can change their vote multiple
   * times and only the latest vote option is tallied.
   */
  enum VotingMode {
    Standard,
    EarlyExecution,
    VoteReplacement
  }

  /**
   * @notice The different threshold modes available
   * @param Percentage The percentage-based threshold system (e.g., 60% = 6e5).
   * @param Flat The flat threshold system (e.g., 2 votes = 2).
   */
  enum ThresholdMode {
    Percentage,
    Flat
  }

  /**
   * @notice A container for the majority voting settings that will be applied as parameters on proposal creation
   * @param votingMode A parameter to select the vote mode. In standard mode (0), early execution
   * and vote replacement are disabled. In early execution mode (1), a proposal can be executed
   * early before the end date if the vote outcome cannot mathematically change by more voters
   * voting. In vote replacement mode (2), voters can change their vote multiple times and only
   * the latest vote option is tallied.
   * @param thresholdMode A parameter to select the threshold mode. In percentage mode (0), the
   * percentage-based threshold system (e.g., 60% = 6e5) is enabled. In flat mode (1), the flat
   * threshold system (e.g., 2 votes = 2) is enabled.
   * @param supportThreshold The support threshold value. Its percentage value has to be in the
   * interval [0, 10^6] defined by `RATIO_BASE = 10e6`.
   * @param duration The duration of proposals in seconds.
   */
  struct VotingSettings {
    VotingMode votingMode;
    ThresholdMode thresholdMode;
    uint256 supportThreshold;
    uint256 duration;
  }

  /**
   * @notice Represents an action to be executed when a proposal passes
   * @param to The target address for the action
   * @param value The amount of native currency to send with the action
   * @param data The call data for the action
   */
  struct Action {
    address to;
    uint256 value;
    bytes data;
  }

  /**
   * @notice A container for the proposal parameters at the time of proposal creation
   * @param votingMode A parameter to select the vote mode.
   * @param thresholdMode A parameter to select the threshold mode.
   * @param supportThreshold The support threshold value. The percentage value has to be in the
   * interval [0, 10^6] defined by `RATIO_BASE = 10e6`.
   * @param startDate The start date of the proposal vote.
   * @param endDate The end date of the proposal vote.
   * @param snapshotBlock The number of the block prior to the proposal creation.
   */
  struct ProposalParameters {
    VotingMode votingMode;
    ThresholdMode thresholdMode;
    uint256 supportThreshold;
    uint256 startDate;
    uint256 endDate;
    uint256 snapshotBlock;
  }

  /**
   * @notice A container for the proposal vote tally
   * @param abstain The number of abstain votes casted.
   * @param yes The number of yes votes casted.
   * @param no The number of no votes casted.
   */
  struct Tally {
    uint256 abstain;
    uint256 yes;
    uint256 no;
  }

  /**
   * @notice A container for proposal-related information
   * @param executed Whether the proposal is executed or not.
   * @param parameters The proposal parameters at the time of the proposal creation.
   * @param tally The vote tally of the proposal.
   * @param voters The votes casted by the voters.
   * @param actions The actions to be executed when the proposal passes.
   */
  struct Proposal {
    bool executed;
    ProposalParameters parameters;
    Tally tally;
    mapping(address => VoteOption) voters;
    Action[] actions;
  }

  /**
   * @notice Thrown when the caller is not authorized to perform the action
   */
  error InvalidCaller();

  /**
   * @notice Thrown when the verify function is called (verify is disabled)
   */
  error VerifyDisabled();

  /**
   * @notice Thrown when an invalid action is provided
   */
  error InvalidAction();

  /**
   * @notice Thrown when the provided address is invalid
   */
  error InvalidAddress();

  /**
   * @notice Thrown when a voter cannot vote on a proposal
   * @dev This error occurs when the voter does not have permission, the proposal doesn't exist,
   * the voting period has ended, or vote replacement is not allowed.
   */
  error CanNotVote();

  /**
   * @notice Thrown when a proposal cannot be executed/settled
   * @dev This error occurs when the proposal doesn't meet the execution criteria, has already
   * been executed, or the execution conditions are not met.
   */
  error CanNotSettle();

  /**
   * @notice Thrown when an action within a proposal reverts during execution
   */
  error ActionReverted();

  /**
   * @notice Initializes the contract
   * @param _spaceRegistry The address of the space registry contract
   * @param _votingSettings The voting settings to use for proposals
   * @param _initialEditors The initial list of editor addresses
   * @param _initialMembers The initial list of member addresses
   */
  function initialize(
    ISpaceRegistry _spaceRegistry,
    VotingSettings calldata _votingSettings,
    address[] calldata _initialEditors,
    address[] calldata _initialMembers
  ) external;

  /**
   * @notice Adds a new editor to the space
   * @param _newEditor The address of the new editor
   * @custom:throws InvalidCaller if called by non-DAO address
   * @custom:throws InvalidAddress if the editor is already an editor
   */
  function addEditor(address _newEditor) external;

  /**
   * @notice Removes an editor from the space
   * @param _oldEditor The address of the editor to remove
   * @custom:throws InvalidCaller if called by non-DAO address
   * @custom:throws InvalidAddress if the editor is not an editor
   */
  function removeEditor(address _oldEditor) external;

  /**
   * @notice Adds a new member to the space
   * @param _newMember The address of the new member
   * @custom:throws InvalidCaller if called by non-DAO address
   */
  function addMember(address _newMember) external;

  /**
   * @notice Removes a member from the space
   * @param _oldMember The address of the member to remove
   * @custom:throws InvalidCaller if called by non-DAO address
   */
  function removeMember(address _oldMember) external;

  /**
   * @notice Space Registry contract
   * @return The address of the space registry singleton
   */
  function spaceRegistry() external view returns (ISpaceRegistry);

  /**
   * @notice Proposal counter
   * @return The current proposal counter value
   */
  function proposalCounter() external view returns (uint256);

  /**
   * @notice Stores the voting settings used for proposals
   * @return votingMode The voting mode
   * @return thresholdMode The threshold mode
   * @return supportThreshold The support threshold value
   * @return duration The duration of proposals in seconds
   */
  function votingSettings()
    external
    view
    returns (VotingMode votingMode, ThresholdMode thresholdMode, uint256 supportThreshold, uint256 duration);

  /**
   * @notice Checks if an account was an editor at a specific block
   * @param _account The address of the account to check
   * @param _blockNumber The block number to check at
   * @return True if the account was an editor at the block, false otherwise
   */
  function isEditorAtBlock(address _account, uint256 _blockNumber) external view returns (bool);

  /**
   * @notice Returns the number of editors at a specific block
   * @param _blockNumber The block number to check at
   * @return The number of editors at the block
   */
  function editorsLengthAtBlock(uint256 _blockNumber) external view returns (uint256);

  /**
   * @notice Gets the support threshold percentage for a proposal
   * @param _proposalId The ID of the proposal
   * @return The support threshold percentage
   * @dev For percentage mode, returns supportThreshold - 1. For flat mode, converts the flat
   * threshold to a percentage based on the total number of editors at the snapshot block.
   * Returns 0 if threshold is 0 or no voters exist. Returns RATIO_BASE - 1 if flat threshold
   * exceeds total voters.
   */
  function getSupportThresholdPercentage(uint256 _proposalId) external view returns (uint256);

  /**
   * @notice Checks if the support threshold is reached for a proposal
   * @param _proposalId The ID of the proposal to check
   * @return True if the support threshold is reached, false otherwise
   * @dev The support threshold is reached when: (RATIO_BASE - supportThresholdPercentage) * yes votes >
   * supportThresholdPercentage * no votes. This uses `>` comparison, so >100% could never be reached.
   */
  function isSupportThresholdReached(uint256 _proposalId) external view returns (bool);

  /**
   * @notice Checks if the support threshold is reached for early execution
   * @param _proposalId The ID of the proposal to check
   * @return True if the support threshold is reached for early execution, false otherwise
   * @dev Returns false if early execution mode is not enabled. Uses worst-case scenario where
   * all remaining editors vote no. The support threshold is reached when: (RATIO_BASE - supportThresholdPercentage)
   * * yes votes > supportThresholdPercentage * worstCaseNoVotes.
   */
  function isSupportThresholdReachedEarly(uint256 _proposalId) external view returns (bool);
}
