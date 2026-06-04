// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

import {ISpace} from 'interfaces/ISpace.sol';
import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';

/**
 * @title IDAOSpace
 * @notice Manages governance proposals and voting for a DAO Space
 */
interface IDAOSpace is ISpace {
  /**
   * @notice Vote options that a voter can choose from
   * @param None Default state; cannot be cast
   * @param Yes Increases support; executes immediately when threshold met
   * @param No Decreases support; escalates fast path to slow path
   * @param Abstain Counts towards participation but doesn't influence support
   */
  enum VoteOption {
    None,
    Yes,
    No,
    Abstain
  }

  /**
   * @notice Voting modes for proposals
   * @param Slow Percentage-based voting with relative thresholds
   * @param Fast Flat-based voting with absolute thresholds
   */
  enum VotingMode {
    Slow,
    Fast
  }

  /**
   * @notice Voting settings configuration for proposals
   * @param partialPercentageSupportThreshold Partial percentage (relative) support threshold for slow path late execution (0-10e6, where 10e6 = 100% of yes/no votes)
   * @param universalPercentageSupportThreshold Universal percentage (relative) support threshold for slow path early execution (0-10e6, where 10e6 = 100% of total editors)
   * @param flatSupportThreshold Flat count (absolute) support threshold for fast path early execution (number of yes votes)
   * @param quorum The minimum number of votes (participation) required for a slow path proposal
   * @param duration Voting window duration in seconds (slow path)
   * @param disableFastPathAccessForNewMembers If true, newly added members are restricted from the fast path; if false, they have fast path access by default
   * @param executionGracePeriod Seconds after `lastDate` during which a passed proposal may still be executed; snapshotted per proposal version as `executeBy`
   */
  struct VotingSettings {
    uint256 partialPercentageSupportThreshold;
    uint256 universalPercentageSupportThreshold;
    uint256 flatSupportThreshold;
    uint256 quorum;
    uint256 duration;
    bool disableFastPathAccessForNewMembers;
    uint256 executionGracePeriod;
  }

  /**
   * @notice Proposal parameters at creation time
   * @param votingMode Voting mode (Slow or Fast)
   * @param partialPercentageSupportThreshold Partial percentage (relative) support threshold for slow path late execution (0-10e6, where 10e6 = 100% of yes/no votes)
   * @param universalPercentageSupportThreshold Universal percentage (relative) support threshold for slow path early execution (0-10e6, where 10e6 = 100% of total editors)
   * @param flatSupportThreshold Flat count (absolute) support threshold for fast path early execution (number of yes votes)
   * @param quorum The minimum number of votes (participation) required for a slow path proposal
   * @param startDate Timestamp when voting starts; zero until the first cast vote
   * @param lastDate Last voting timestamp; zero until the first cast vote
   * @param executeBy Inclusive upper bound timestamp for execution; zero until the first cast vote. After this time the proposal cannot be executed even if support threshold is met
   */
  struct ProposalParameters {
    VotingMode votingMode;
    uint256 partialPercentageSupportThreshold;
    uint256 universalPercentageSupportThreshold;
    uint256 flatSupportThreshold;
    uint256 quorum;
    uint256 startDate;
    uint256 lastDate;
    uint256 executeBy;
  }

  /**
   * @notice Proposal information
   * @param executed Whether proposal has been executed
   * @param creator The creator space ID of the proposal
   * @param parameters Proposal parameters (may change if fast path escalates)
   * @param tally Vote tally (yes, no, abstain counts)
   * @param voters Mapping of editor space IDs to vote options
   * @param actions Actions to execute when proposal passes (fast path: 1 action max)
   */
  struct Proposal {
    bool executed;
    bytes16 creator;
    ProposalParameters parameters;
    Tally tally;
    mapping(bytes16 _voterSpaceId => VoteOption _vote) voters;
    Action[] actions;
  }

  /**
   * @notice Proposal vote tally
   * @param yes Number of yes votes
   * @param no Number of no votes
   * @param abstain Number of abstain votes
   */
  struct Tally {
    uint256 yes;
    uint256 no;
    uint256 abstain;
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
   * @notice The storage struct of the DAO space contract
   * @param spaceRegistry The space registry contract
   * @param votingSettings Voting settings for proposals
   * @param totalEditors Total editors
   * @param actionIsFastPathValid Maps action selectors to whether they are valid for fast path proposals
   * @param latestProposalVersion The latest version for a proposal
   * @param proposals Stores information about a proposal by its ID and version
   * @custom:storage-location erc7201:geo.storage.DAOSpace
   */
  struct DAOSpaceStorage {
    ISpaceRegistry spaceRegistry;
    VotingSettings votingSettings;
    uint256 totalEditors;
    mapping(bytes4 _selector => bool _isValid) actionIsFastPathValid;
    mapping(bytes16 _proposalId => uint8 _proposalVersion) latestProposalVersion;
    mapping(bytes16 _proposalId => mapping(uint8 _proposalVersion => Proposal _proposal)) proposals;
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
   * @notice Thrown when attempting to assign/unassign a role to an inappropriate space id
   */
  error InvalidSpaceIdForRole();

  /**
   * @notice Thrown when attempting to update the voting settings with invalid parameters
   */
  error InvalidSetting();

  /**
   * @notice Thrown when attempting to create a proposal with an id that has already been used
   */
  error InvalidProposalId();

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
   * @notice Thrown when a fast path proposal contains more than one action
   * @dev Fast path limited to single action
   */
  error OneActionForFastPath();

  /**
   * @notice Thrown when a fast path proposal attempts to call a contract other than the DAO itself
   */
  error InvalidTarget();

  /**
   * @notice Thrown when a fast path proposal attempts to transfer funds
   */
  error InvalidFundsTransfer();

  /**
   * @notice Thrown when attempting to create a proposal using the fast path when the creator
   * is restricted from doing so.
   */
  error FastPathRestricted();

  /**
   * @notice Initializes the contract
   * @param _initializerData The encoded initializer data:
   *        _spaceRegistry The address of the space registry contract
   *        _votingSettings The voting settings to use for proposals
   *        _initialEditors The initial list of editor space IDs
   *        _initialMembers The initial list of member space IDs
   *        _publishEditsData The optional encoded initial edit publish data (content uri and metadata)
   *        _initialTopicId The optional initial topic ID to declare
   *        _daoSpaceId The optional pre-determined space ID for a transplant; pass bytes16(0) for standard creation
   */
  function initialize(bytes calldata _initializerData) external;

  /**
   * @notice Adds a new editor to the space
   * @param _newEditorSpaceId The space ID of the new editor
   */
  function addEditor(bytes16 _newEditorSpaceId) external;

  /**
   * @notice Removes an editor from the space
   * @param _oldEditorSpaceId The space ID of the editor to remove
   */
  function removeEditor(bytes16 _oldEditorSpaceId) external;

  /**
   * @notice Adds a new member to the space
   * @param _newMemberSpaceId The space ID of the new member
   */
  function addMember(bytes16 _newMemberSpaceId) external;

  /**
   * @notice Removes a member from the space
   * @param _oldMemberSpaceId The space ID of the member to remove
   */
  function removeMember(bytes16 _oldMemberSpaceId) external;

  /**
   * @notice Unrestricts a space, restoring their ability to create fast path proposals
   * @param _oldRestrictedSpaceId The space ID to unrestrict
   */
  function unrestrictSpace(bytes16 _oldRestrictedSpaceId) external;

  /**
   * @notice Re-enters the Space Registry to emit an Action event
   * @param _action An action identifier
   * @param _subject A subject identifier
   * @param _data Some extra arbitrary data that may hold additional information
   * @dev _from and _to are always the DAO's space id
   */
  function ping(bytes32 _action, bytes32 _subject, bytes calldata _data) external;

  /**
   * @notice Updates the voting settings for the DAO
   * @param _votingSettings The new voting settings
   */
  function updateVotingSettings(VotingSettings calldata _votingSettings) external;

  /**
   * @notice Total editors
   * @return _totalEditors The total number of editors
   */
  function totalEditors() external view returns (uint256 _totalEditors);

  /**
   * @notice Voting settings for proposals
   * @return _votingSettings The voting settings to use for proposals
   */
  function votingSettings() external view returns (VotingSettings memory _votingSettings);

  /**
   * @notice Maps action selectors to whether they are valid for fast path proposals
   * @param _selector Action selector to check
   * @return _isValid True if action selector is valid for fast path
   */
  function actionIsFastPathValid(bytes4 _selector) external view returns (bool _isValid);

  /**
   * @notice Maps a proposal ID to a version number
   * @param _proposalId ID of the proposal to fetch the latest version
   * @return _latestProposalVersion The latest version of the proposal
   */
  function latestProposalVersion(bytes16 _proposalId) external view returns (uint8 _latestProposalVersion);

  /**
   * @notice Checks if a proposal has reached its support threshold
   * @param _proposalId ID of the proposal to check
   * @return _isSupportThresholdReached True if support threshold is reached
   * @dev Threshold-only view: does not check whether voting timers are snapshotted (`parameters.lastDate` is zero),
   * whether the proposal was executed, or `parameters.executeBy`. On the slow path, the partial percentage threshold
   * applies only after `parameters.lastDate`; when `lastDate` is zero, only the universal threshold is evaluated. Prefer
   * `canExecuteProposal` for execution readiness.
   */
  function isSupportThresholdReached(bytes16 _proposalId) external view returns (bool _isSupportThresholdReached);

  /**
   * @notice Checks if a proposal can be executed
   * @param _proposalId The ID of the proposal to check
   * @return _canExecuteProposal True if the proposal can be executed, false otherwise
   * @dev Returns false if proposal doesn't exist, already executed, `parameters.lastDate` is zero (voting timers unset),
   * threshold not met, or `block.timestamp` is after `executeBy`.
   */
  function canExecuteProposal(bytes16 _proposalId) external view returns (bool _canExecuteProposal);

  /**
   * @notice Gets the information for a proposal and version pair
   * @param _proposalId The ID of the proposal
   * @param _proposalVersion The version of the proposal
   * @return _executed Whether the proposal has been executed
   * @return _creator The creator of the proposal
   * @return _parameters The proposal parameters at the time of creation
   * @return _tally The current vote tally for the proposal
   * @return _actions The actions to be executed when the proposal passes
   */
  function getProposalInformation(
    bytes16 _proposalId,
    uint8 _proposalVersion
  )
    external
    view
    returns (
      bool _executed,
      bytes16 _creator,
      ProposalParameters memory _parameters,
      Tally memory _tally,
      Action[] memory _actions
    );

  /**
   * @notice Gets the latest information for a proposal
   * @param _proposalId The ID of the proposal
   * @return _executed Whether the proposal has been executed
   * @return _creator The creator of the proposal
   * @return _parameters The proposal parameters at the time of creation
   * @return _tally The current vote tally for the proposal
   * @return _actions The actions to be executed when the proposal passes
   */
  function getLatestProposalInformation(bytes16 _proposalId)
    external
    view
    returns (
      bool _executed,
      bytes16 _creator,
      ProposalParameters memory _parameters,
      Tally memory _tally,
      Action[] memory _actions
    );

  /**
   * @notice Gets the vote option cast by a given space on a proposal and version pairing
   * @param _proposalId The ID of the proposal
   * @param _proposalVersion The version of the proposal to fetch
   * @param _voterSpaceId The space ID of the voter to check
   * @return _voteOption The vote option cast by the space (None if not voted)
   */
  function getProposalVote(
    bytes16 _proposalId,
    uint8 _proposalVersion,
    bytes16 _voterSpaceId
  ) external view returns (VoteOption _voteOption);

  /**
   * @notice Gets the vote option cast by a given space on the latest version of a proposal
   * @param _proposalId The ID of the proposal
   * @param _voterSpaceId The space ID of the voter to check
   * @return _voteOption The vote option cast by the space (None if not voted)
   */
  function getLatestProposalVote(
    bytes16 _proposalId,
    bytes16 _voterSpaceId
  ) external view returns (VoteOption _voteOption);

  /**
   * @notice Space Registry contract
   * @return _spaceRegistry The address of the space registry singleton
   */
  function spaceRegistry() external view returns (ISpaceRegistry _spaceRegistry);

  /**
   * @notice Returns the minimum voting duration for a slow path proposal
   * @return _minimumVotingDuration The minimum voting duration in seconds
   */
  function MINIMUM_VOTING_DURATION() external view returns (uint256 _minimumVotingDuration);

  /**
   * @notice Minimum allowed execution grace period (seconds after voting ends)
   * @return _minimumExecutionGracePeriod The minimum execution grace period in seconds
   */
  function MINIMUM_EXECUTION_GRACE_PERIOD() external view returns (uint256 _minimumExecutionGracePeriod);

  /**
   * @notice Returns the ratio base used for percentage calculations
   * @return _ratioBase The ratio base (10e6)
   */
  function RATIO_BASE() external view returns (uint256 _ratioBase);

  /**
   * @notice Returns the fast path restricted identifier
   * @return _fastPathRestricted The fast path restricted role identifier
   */
  function FAST_PATH_RESTRICTED() external view returns (bytes32 _fastPathRestricted);

  /**
   * @notice Returns the SPACE_REGISTRY role identifier
   * @return _spaceRegistry The SPACE_REGISTRY role identifier
   */
  function SPACE_REGISTRY() external view returns (bytes32 _spaceRegistry);

  /**
   * @notice Returns the editor role identifier
   * @return _editor The editor role identifier
   */
  function EDITOR() external view returns (bytes32 _editor);

  /**
   * @notice Returns the member role identifier
   * @return _member The member role identifier
   */
  function MEMBER() external view returns (bytes32 _member);

  /**
   * @notice Returns the DAO role identifier
   * @return _dao The DAO role identifier
   */
  function DAO() external view returns (bytes32 _dao);
}
