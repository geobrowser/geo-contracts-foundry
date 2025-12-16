// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {ISemver} from 'interfaces/ISemver.sol';
import {ISpace} from 'interfaces/ISpace.sol';
import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';

/**
 * @title IDAOSpace
 * @notice Manages governance proposals and voting for a DAO Space
 */
interface IDAOSpace is ISpace, ISemver {
  /**
   * @notice Vote options that a voter can choose from
   * @param None Default state, cannot be cast
   * @param Abstain Counts towards participation but doesn't influence support
   * @param Yes Increases support; fast path executes immediately when threshold met
   * @param No Decreases support; escalates fast path to slow path
   */
  enum VoteOption {
    None,
    Abstain,
    Yes,
    No
  }

  /**
   * @notice Voting modes for proposals
   * @param Slow Majority voting with voting window (percentage threshold)
   * @param Fast Threshold-based voting with immediate execution (flat count)
   */
  enum VotingMode {
    Slow,
    Fast
  }

  /**
   * @notice Voting settings configuration for proposals
   * @param slowPathPercentageThreshold Percentage threshold for slow path (0-10^6, where 10^6 = 100%)
   * @param fastPathFlatThreshold Flat count threshold for fast path (number of yes votes)
   * @param quorum The minimum number of votes (participation) required for a slow path proposal
   * @param duration Voting window duration in seconds (slow path)
   */
  struct VotingSettings {
    uint256 slowPathPercentageThreshold;
    uint256 fastPathFlatThreshold;
    uint256 quorum;
    uint256 duration;
  }

  /**
   * @notice Proposal parameters at creation time
   * @param votingMode Voting mode (Slow or Fast)
   * @param supportThreshold Slow path: percentage (0-10^6). Fast path: flat count. Updated if escalates.
   * @param quorum The minimum number of votes (participation) required for a slow path proposal
   * @param startDate Timestamp when voting starts
   * @param lastDate Last voting timestamp (slow path execution requires this)
   */
  struct ProposalParameters {
    VotingMode votingMode;
    uint256 supportThreshold;
    uint256 quorum;
    uint256 startDate;
    uint256 lastDate;
  }

  /**
   * @notice Proposal information
   * @param executed Whether proposal has been executed
   * @param parameters Proposal parameters (may change if fast path escalates)
   * @param tally Vote tally (yes, no, abstain counts)
   * @param voters Mapping of editor addresses to vote options
   * @param actions Actions to execute when proposal passes (fast path: 1 action max)
   */
  struct Proposal {
    bool executed;
    ProposalParameters parameters;
    Tally tally;
    mapping(address => VoteOption) voters;
    Action[] actions;
  }

  /**
   * @notice Proposal vote tally
   * @param abstain Number of abstain votes
   * @param yes Number of yes votes
   * @param no Number of no votes
   */
  struct Tally {
    uint256 abstain;
    uint256 yes;
    uint256 no;
  }

  /**
   * @notice Action to execute when proposal passes
   * @param to Target address
   * @param value Native currency amount to send
   * @param data Calldata
   */
  struct Action {
    address to;
    uint256 value;
    bytes data;
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
   * @notice Thrown when the from space attempts to execute a restricted operation
   */
  error InvalidFromSpace();

  /**
   * @notice Thrown when attempting to assign/unassign a role to an inappropriate address
   */
  error InvalidAddressForRole();

  /**
   * @notice Thrown when attempting to update the voting settings with invalid parameters
   */
  error InvalidSetting();

  /**
   * @notice Thrown when a voter cannot vote on a proposal
   * @dev Voter lacks permission, proposal doesn't exist, voting ended, or not editor at snapshot.
   * Vote replacement allowed.
   */
  error CanNotVote();

  /**
   * @notice Thrown when a proposal cannot be executed/settled
   * @dev Proposal doesn't meet execution criteria, already executed, or conditions not met.
   */
  error CanNotExecute();

  /**
   * @notice Thrown when an action within a proposal reverts during execution
   */
  error ActionReverted();

  /**
   * @notice Thrown when a fast path proposal contains more than one action
   * @dev Fast path limited to single action
   */
  error OneActionForFastPath();

  /**
   * @notice Thrown when an editor has been flagged and thus is prevented from using the fast path
   */
  error EditorFlagged();

  /**
   * @notice Thrown when the from space is not an editor
   */
  error NotEditor();

  /**
   * @notice Initializes the contract
   * @param _initializerData The encoded initializer data:
   *        _spaceRegistry The address of the space registry contract
   *        _votingSettings The voting settings to use for proposals
   *        _initialEditors The initial list of editor addresses
   *        _initialMembers The initial list of member addresses
   */
  function initialize(bytes calldata _initializerData) external;

  /**
   * @notice Adds a new editor to the space
   * @param _newEditor The address of the new editor
   */
  function addEditor(address _newEditor) external;

  /**
   * @notice Removes an editor from the space
   * @param _oldEditor The address of the editor to remove
   */
  function removeEditor(address _oldEditor) external;

  /**
   * @notice Adds a new member to the space
   * @param _newMember The address of the new member
   */
  function addMember(address _newMember) external;

  /**
   * @notice Removes a member from the space
   * @param _oldMember The address of the member to remove
   */
  function removeMember(address _oldMember) external;

  /**
   * @notice Unflags an editor, restoring their ability to create fast path proposals
   * @param _unflaggedEditor The address of the editor to unflag
   */
  function unflagEditor(address _unflaggedEditor) external;

  /**
   * @notice Re-enters the Space Registry to emit an Action event
   * @param _action An action identifier
   * @param _topic A topic identifier
   * @param _data Some extra arbitrary data that may hold additional information
   * @dev _from and _to are always the DAO's address
   */
  function ping(bytes32 _action, bytes32 _topic, bytes calldata _data) external;

  /**
   * @notice Publishes content edits via an Action event emission
   * @param _topic An optional topic identifier
   * @param _editsContentUri The uri for the content
   * @param _editsMetadata The uri for the metadata
   * @dev _from and _to are always the DAO's address
   */
  function publish(bytes32 _topic, bytes memory _editsContentUri, bytes memory _editsMetadata) external;

  /**
   * @notice Flags something for additional consideration via an Action event emission
   * @param _topic An optional topic identifier
   * @param _flaggedId The id or uri of the thing being flagged (e.g. content, topic, proposal)
   * @dev _from and _to are always the DAO's address
   */
  function flag(bytes32 _topic, bytes calldata _flaggedId) external;

  /**
   * @notice Unflags something via an Action event emission
   * @param _topic An optional topic identifier
   * @param _unflaggedId The id or uri of the thing being unflagged (e.g. content, topic, proposal)
   * @dev _from and _to are always the DAO's address
   */
  function unflag(bytes32 _topic, bytes calldata _unflaggedId) external;

  /**
   * @notice Updates the voting settings for the DAO
   * @param _votingSettings The new voting settings
   */
  function updateVotingSettings(VotingSettings calldata _votingSettings) external;

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
   * @notice Total editors
   * @return The total number of editors
   */
  function totalEditors() external view returns (uint256);

  /**
   * @notice Voting settings for proposals
   * @return slowPathPercentageThreshold Percentage threshold for slow path
   * @return fastPathFlatThreshold Flat count threshold for fast path
   * @return quorum The minimum number of votes (participation) required for a slow path proposal
   * @return duration Voting window duration in seconds
   */
  function votingSettings()
    external
    view
    returns (uint256 slowPathPercentageThreshold, uint256 fastPathFlatThreshold, uint256 quorum, uint256 duration);

  /**
   * @notice Maps action selectors to whether they are valid for fast path proposals
   * @param _selector Action selector to check
   * @return True if action selector is valid for fast path
   */
  function actionIsFastPathValid(bytes4 _selector) external view returns (bool);

  /**
   * @notice Maps editor addresses to whether they are flagged (restricted from fast path)
   * @param _space Editor address to check
   * @return True if editor is flagged
   */
  function isEditorFlagged(address _space) external view returns (bool);

  /**
   * @notice Checks if a proposal has reached its support threshold
   * @param _proposalId ID of the proposal to check
   * @return True if support threshold is reached
   */
  function isSupportThresholdReached(uint256 _proposalId) external view returns (bool);

  /**
   * @notice Gets the information for a proposal
   * @param _proposalId The ID of the proposal
   * @return _executed Whether the proposal has been executed
   * @return _parameters The proposal parameters at the time of creation
   * @return _tally The current vote tally for the proposal
   * @return _actions The actions to be executed when the proposal passes
   */
  function getProposalInformation(uint256 _proposalId)
    external
    view
    returns (bool _executed, ProposalParameters memory _parameters, Tally memory _tally, Action[] memory _actions);

  /**
   * @notice Gets the vote option cast by a given account on a proposal
   * @param _proposalId The ID of the proposal
   * @param _account The address of the account to check
   * @return _voteOption The vote option cast by the account (None if not voted)
   */
  function getProposalVote(uint256 _proposalId, address _account) external view returns (VoteOption _voteOption);

  /**
   * @notice Returns the ratio base used for percentage calculations
   * @return The ratio base (10^6)
   */
  function RATIO_BASE() external view returns (uint256);

  /**
   * @notice Returns the SPACE_REGISTRY role identifier
   * @return The SPACE_REGISTRY role identifier
   */
  function SPACE_REGISTRY() external view returns (bytes32);

  /**
   * @notice Returns the editor role identifier
   * @return The editor role identifier
   */
  function EDITOR() external view returns (bytes32);

  /**
   * @notice Returns the member role identifier
   * @return The member role identifier
   */
  function MEMBER() external view returns (bytes32);

  /**
   * @notice Returns the DAO role identifier
   * @return The DAO role identifier
   */
  function DAO() external view returns (bytes32);
}
