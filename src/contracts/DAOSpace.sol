// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {AccessControlUpgradeable} from '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';

import {IDAOSpace} from 'interfaces/IDAOSpace.sol';
import {ISemver} from 'interfaces/ISemver.sol';
import {ISpace} from 'interfaces/ISpace.sol';
import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';

import 'src/ActionsConstants.sol' as ActionsConstants;

/**
 * @title DAOSpace
 * @notice Manages governance proposals and voting for a DAO Space
 * @dev This contract allows members and editors to create proposals, vote, and execute them.
 *      This contract also implements a dual-path governance: fast path (threshold-based, immediate execution)
 *      and slow path (majority voting with voting window). Fast path escalates to slow path on "No" vote.
 */
contract DAOSpace is AccessControlUpgradeable, IDAOSpace {
  /// @inheritdoc IDAOSpace
  uint256 public constant MINIMUM_VOTING_DURATION = 2 days;

  /// @inheritdoc IDAOSpace
  uint256 public constant RATIO_BASE = 10e6;

  /// @inheritdoc IDAOSpace
  bytes32 public constant SPACE_REGISTRY = keccak256('SPACE_REGISTRY');

  /// @inheritdoc IDAOSpace
  bytes32 public constant EDITOR = keccak256('EDITOR');

  /// @inheritdoc IDAOSpace
  bytes32 public constant MEMBER = keccak256('MEMBER');

  /// @inheritdoc IDAOSpace
  bytes32 public constant DAO = keccak256('DAO');

  /// @inheritdoc IDAOSpace
  ISpaceRegistry public spaceRegistry;

  /// @inheritdoc IDAOSpace
  VotingSettings public votingSettings;

  /// @inheritdoc IDAOSpace
  uint256 public proposalCounter;

  /// @inheritdoc IDAOSpace
  uint256 public totalEditors;

  /// @inheritdoc IDAOSpace
  mapping(bytes4 _selector => bool _isValid) public actionIsFastPathValid;

  /// @inheritdoc IDAOSpace
  mapping(address _editor => bool _isFlagged) public isEditorFlagged;

  /// @notice Stores information about a proposal by its ID
  mapping(uint256 _proposalId => Proposal _proposal) internal _proposals;

  /// @notice Constructor
  constructor() {
    _disableInitializers();
  }

  /// @inheritdoc IDAOSpace
  function initialize(
    ISpaceRegistry _spaceRegistry,
    VotingSettings calldata _votingSettings,
    address[] calldata _initialEditors,
    address[] calldata _initialMembers
  ) external initializer {
    // Set Space Registry and register new DAO Space
    spaceRegistry = _spaceRegistry;
    _spaceRegistry.registerSpaceId();
    // Add initial editors
    uint256 length = _initialEditors.length;
    for (uint256 i; i < length; i++) {
      _addEditor(_initialEditors[i]);
    }
    // Add initial members
    length = _initialMembers.length;
    for (uint256 j; j < length; j++) {
      _addMember(_initialMembers[j]);
    }
    // Set voting settings
    _updateVotingSettings(_votingSettings);
    // Grant further roles for access control
    _grantRole(SPACE_REGISTRY, address(spaceRegistry));
    _grantRole(DAO, address(this));
    // Set the initial fast path actions
    actionIsFastPathValid[IDAOSpace.addMember.selector] = true;
    actionIsFastPathValid[IDAOSpace.removeMember.selector] = true;
  }

  /// @inheritdoc ISpace
  function write(address _fromSpace, bytes32 _action, bytes32, bytes calldata _data) external {
    // Only Space Registry can call
    if (!hasRole(SPACE_REGISTRY, msg.sender)) revert InvalidCaller();
    // Governance Actions
    if (_action == ActionsConstants.PROPOSAL_CREATED) {
      _createProposal(_fromSpace, _data);
    } else if (_action == ActionsConstants.PROPOSAL_VOTED) {
      _vote(_fromSpace, _data);
    } else if (_action == ActionsConstants.PROPOSAL_EXECUTED) {
      _executeProposal(_data);
    } else if (_action == ActionsConstants.SPACE_LEFT) {
      _leave(_fromSpace, _data);
    } else if (_action == ActionsConstants.EDITOR_FLAGGED) {
      _flagEditor(_fromSpace, _data);
    } else {
      // Must attempt to write in some way
      revert InvalidAction();
    }
  }

  /// @inheritdoc ISpace
  function verify(address, bytes32, bytes32, bytes calldata, bytes calldata) external pure {
    revert VerifyDisabled();
  }

  /// @inheritdoc IDAOSpace
  function addEditor(address _newEditor) public {
    if (!hasRole(DAO, msg.sender)) revert InvalidCaller();
    _addEditor(_newEditor);
  }

  /// @inheritdoc IDAOSpace
  function removeEditor(address _oldEditor) public {
    if (!hasRole(DAO, msg.sender)) revert InvalidCaller();
    _removeEditor(_oldEditor);
  }

  /// @inheritdoc IDAOSpace
  function addMember(address _newMember) public {
    if (!hasRole(DAO, msg.sender)) revert InvalidCaller();
    _addMember(_newMember);
  }

  /// @inheritdoc IDAOSpace
  function removeMember(address _oldMember) public {
    if (!hasRole(DAO, msg.sender)) revert InvalidCaller();
    _removeMember(_oldMember);
  }

  /// @inheritdoc IDAOSpace
  function unflagEditor(address _unflaggedEditor) public {
    if (!hasRole(DAO, msg.sender)) revert InvalidCaller();
    _unflagEditor(_unflaggedEditor);
  }

  /// @inheritdoc IDAOSpace
  function ping(bytes32 _action, bytes32 _topic, bytes calldata _data) public {
    if (!hasRole(DAO, msg.sender)) revert InvalidCaller();
    _ping(_action, _topic, _data);
  }

  /// @inheritdoc IDAOSpace
  function updateVotingSettings(VotingSettings calldata _votingSettings) public {
    if (!hasRole(DAO, msg.sender)) revert InvalidCaller();
    _updateVotingSettings(_votingSettings);
  }

  /// @inheritdoc ISpace
  function fetch(bytes32 _action, bytes32 _topicInput) public view returns (bytes32) {
    if (_action == ActionsConstants.PROPOSAL_CREATED) return bytes32(proposalCounter);
    else return _topicInput;
  }

  /// @inheritdoc IDAOSpace
  function isSupportThresholdReached(uint256 _proposalId) public view returns (bool _isSupportReached) {
    Proposal storage proposal_ = _proposals[_proposalId];
    uint256 supportThreshold =
      (proposal_.parameters.supportThreshold == 0) ? 0 : proposal_.parameters.supportThreshold - 1;
    if (proposal_.parameters.votingMode == VotingMode.Slow) {
      // Slow path
      if (block.timestamp <= proposal_.parameters.lastDate) return false;
      // Quorum check
      if (proposal_.tally.abstain + proposal_.tally.yes + proposal_.tally.no < proposal_.parameters.quorum) {
        return false;
      }
      // Threshold percentage calculation
      if ((RATIO_BASE - supportThreshold) * proposal_.tally.yes > supportThreshold * proposal_.tally.no) return true;
    } else {
      // Fast path
      // Threshold flat calculation
      if (proposal_.tally.yes > supportThreshold) return true;
    }
  }

  /// @inheritdoc IDAOSpace
  function getProposalInformation(uint256 _proposalId)
    external
    view
    returns (bool _executed, ProposalParameters memory _parameters, Tally memory _tally, Action[] memory _actions)
  {
    _executed = _proposals[_proposalId].executed;
    _parameters = _proposals[_proposalId].parameters;
    _tally = _proposals[_proposalId].tally;
    _actions = _proposals[_proposalId].actions;
  }

  /// @inheritdoc IDAOSpace
  function getProposalVote(uint256 _proposalId, address _account) external view returns (VoteOption _voteOption) {
    return _proposals[_proposalId].voters[_account];
  }

  /// @inheritdoc ISemver
  function version() public pure returns (string memory _version) {
    _version = '1.0.0';
  }

  /**
   * @notice Sets the voting settings for the DAO
   * @param _votingSettings The new voting settings
   * @dev Several checks are performed to ensure the new settings do not prevent future proposals from
   * being executed.
   */
  function _updateVotingSettings(VotingSettings calldata _votingSettings) internal {
    if (_votingSettings.slowPathPercentageThreshold > RATIO_BASE) revert InvalidSetting();
    if (_votingSettings.fastPathFlatThreshold > totalEditors) revert InvalidSetting();
    if (_votingSettings.quorum > totalEditors) revert InvalidSetting();
    if (_votingSettings.duration < MINIMUM_VOTING_DURATION) revert InvalidSetting();
    votingSettings = _votingSettings;
  }

  /**
   * @notice Creates a new governance proposal
   * @param _fromSpace The address of the space creating the proposal
   * @param _data The encoded proposal data containing the voting mode and actions
   * @dev Fast path: only editors can create, creator must not be flagged, single action required,
   * action selector must be valid. Slow path: members or editors can create, multiple actions allowed.
   */
  function _createProposal(address _fromSpace, bytes calldata _data) internal {
    // Decode data to construct proposal
    (VotingMode votingMode, Action[] memory actions) = abi.decode(_data, (VotingMode, Action[]));
    // Update proposal storage
    Proposal storage proposal_ = _proposals[proposalCounter++];
    proposal_.parameters.startDate = block.timestamp;
    proposal_.parameters.lastDate = block.timestamp + votingSettings.duration;
    proposal_.parameters.votingMode = votingMode;
    proposal_.parameters.quorum = votingSettings.quorum;
    if (votingMode == VotingMode.Slow) {
      // Slow path
      // Only members or editors can create slow path proposals
      if (!(hasRole(MEMBER, _fromSpace) || hasRole(EDITOR, _fromSpace))) revert InvalidFromSpace();
      proposal_.parameters.supportThreshold = votingSettings.slowPathPercentageThreshold;
    } else {
      // Fast path
      // Only editors can create fast path proposals
      if (!hasRole(EDITOR, _fromSpace)) revert InvalidFromSpace();
      // Checks from space is allowed to use fast path
      if (isEditorFlagged[_fromSpace]) revert EditorFlagged();
      // limit the actions to one call
      if (actions.length != 1) revert OneActionForFastPath();
      bytes4 actionSelector = bytes4(actions[0].data);
      if (!actionIsFastPathValid[actionSelector]) revert InvalidAction();
      proposal_.parameters.supportThreshold = votingSettings.fastPathFlatThreshold;
    }
    for (uint256 i; i < actions.length; i++) {
      proposal_.actions.push(actions[i]);
    }
  }

  /**
   * @notice Votes on a proposal
   * @param _fromSpace The address of the space casting the vote
   * @param _data The encoded vote data containing proposal ID and vote option
   * @dev Only editors can vote. Vote replacement allowed. "No" vote on fast path escalates to slow path.
   * Fast path can execute immediately if threshold met; slow path requires voting period to end.
   */
  function _vote(address _fromSpace, bytes calldata _data) internal {
    // Decode data to construct vote
    (uint256 _proposalId, VoteOption _voteOption) = abi.decode(_data, (uint256, VoteOption));
    // Ensure _fromSpace can vote
    if (!_canVote(_fromSpace, _proposalId, _voteOption)) revert CanNotVote();
    Proposal storage proposal_ = _proposals[_proposalId];
    // Remove the previous vote.
    VoteOption state = proposal_.voters[_fromSpace];
    if (state == VoteOption.Yes) {
      proposal_.tally.yes = proposal_.tally.yes - 1;
    } else if (state == VoteOption.No) {
      proposal_.tally.no = proposal_.tally.no - 1;
    } else if (state == VoteOption.Abstain) {
      proposal_.tally.abstain = proposal_.tally.abstain - 1;
    }
    // Store the updated/new vote for the voter.
    if (_voteOption == VoteOption.Yes) {
      proposal_.tally.yes = proposal_.tally.yes + 1;
    } else if (_voteOption == VoteOption.No) {
      proposal_.tally.no = proposal_.tally.no + 1;
    } else if (_voteOption == VoteOption.Abstain) {
      proposal_.tally.abstain = proposal_.tally.abstain + 1;
    }
    proposal_.voters[_fromSpace] = _voteOption;
    // extra fast path logic
    if (proposal_.parameters.votingMode == VotingMode.Fast) {
      // fast path to slow path if rejection occurs
      if (_voteOption == VoteOption.No) {
        // Update voting mode
        proposal_.parameters.votingMode = VotingMode.Slow;
        // Update threshold
        proposal_.parameters.supportThreshold = votingSettings.slowPathPercentageThreshold;
        // Reset duration and block times
        proposal_.parameters.startDate = block.timestamp;
        proposal_.parameters.lastDate = block.timestamp + votingSettings.duration;
      } else if (_voteOption == VoteOption.Yes) {
        // immediate execution if possible
        if (_canExecuteProposal(_proposalId)) _executeProposal(_proposalId);
      }
    }
  }

  /**
   * @notice Decodes input data and then executes a proposal after it has passed
   * @param _data The encoded execution data containing the proposal ID
   */
  function _executeProposal(bytes calldata _data) internal {
    // Anyone can call
    // Check if proposal can be settled
    uint256 _proposalId = abi.decode(_data, (uint256));
    if (!_canExecuteProposal(_proposalId)) revert CanNotExecute();
    _executeProposal(_proposalId);
  }

  /**
   * @notice Executes a proposal after it has passed
   * @param _proposalId The proposal ID of the proposal to be executed
   * @dev Anyone can call once execution criteria met. Actions executed sequentially. Reverts if any action fails.
   */
  function _executeProposal(uint256 _proposalId) internal {
    // Set proposal as executed
    _proposals[_proposalId].executed = true;
    /// loop over actions
    Action[] memory actions = _proposals[_proposalId].actions;
    uint256 actionsLength = actions.length;
    Action memory action;
    for (uint256 i; i < actionsLength; i++) {
      action = actions[i];
      (bool success,) = (action.to).call{value: action.value}(action.data);
      if (!success) revert ActionReverted();
    }
  }

  /**
   * @notice Allows a member or editor to leave the space
   * @param _fromSpace The address of the space leaving
   * @param _data The encoded role data used to determine which role a user wants to leave
   */
  function _leave(address _fromSpace, bytes calldata _data) internal {
    bytes32 role = abi.decode(_data, (bytes32));
    if (role == MEMBER && hasRole(MEMBER, _fromSpace)) {
      _removeMember(_fromSpace);
    } else if (role == EDITOR && hasRole(EDITOR, _fromSpace)) {
      _removeEditor(_fromSpace);
    } else {
      revert InvalidFromSpace();
    }
  }

  /**
   * @notice Flags an editor, restricting them from creating fast path proposals
   * @param _fromSpace The address of the editor performing the flagging
   * @param _data The encoded data containing the address of the editor to flag
   * @dev Only editors can flag other editors.
   */
  function _flagEditor(address _fromSpace, bytes calldata _data) internal {
    if (!hasRole(EDITOR, _fromSpace)) revert InvalidFromSpace();
    address _flaggedEditor = abi.decode(_data, (address));
    if (!hasRole(EDITOR, _flaggedEditor)) revert NotEditor();
    isEditorFlagged[_flaggedEditor] = true;
  }

  /**
   * @notice Unflags an editor, allowing them to create fast path proposals
   * @param _unflaggedEditor The address of the editor to be unflaged
   */
  function _unflagEditor(address _unflaggedEditor) internal {
    if (!hasRole(EDITOR, _unflaggedEditor)) revert NotEditor();
    isEditorFlagged[_unflaggedEditor] = false;
    _ping(ActionsConstants.EDITOR_UNFLAGGED, bytes32(bytes20(_unflaggedEditor)), '');
  }

  /**
   * @notice Internal function to add an editor
   * @param _newEditor The address of the new editor
   */
  function _addEditor(address _newEditor) internal {
    if (hasRole(EDITOR, _newEditor)) revert InvalidAddressForRole();
    // Grant the role for access control
    _grantRole(EDITOR, _newEditor);
    // Update counter
    totalEditors++;
    // Ping the registry
    _ping(ActionsConstants.EDITOR_ADDED, bytes32(bytes20(_newEditor)), '');
  }

  /**
   * @notice Internal function to remove an editor
   * @param _oldEditor The address of the editor to remove
   */
  function _removeEditor(address _oldEditor) internal {
    if (!hasRole(EDITOR, _oldEditor)) revert InvalidAddressForRole();
    // May not remove editor if doing so would prevent slow path proposals from being executed
    if (votingSettings.quorum == totalEditors) revert InvalidSetting();
    // Revoke the role for access control
    _revokeRole(EDITOR, _oldEditor);
    // Update counter
    totalEditors--;
    // Reset flagged status
    isEditorFlagged[_oldEditor] = false;
    // Ping the registry
    _ping(ActionsConstants.EDITOR_REMOVED, bytes32(bytes20(_oldEditor)), '');
  }

  /**
   * @notice Internal function to add a member
   * @param _newMember The address of the new member
   */
  function _addMember(address _newMember) internal {
    if (hasRole(MEMBER, _newMember)) revert InvalidAddressForRole();
    _grantRole(MEMBER, _newMember);
    _ping(ActionsConstants.MEMBER_ADDED, bytes32(bytes20(_newMember)), '');
  }

  /**
   * @notice Internal function to remove a member
   * @param _oldMember The address of the member to remove
   */
  function _removeMember(address _oldMember) internal {
    if (!hasRole(MEMBER, _oldMember)) revert InvalidAddressForRole();
    _revokeRole(MEMBER, _oldMember);
    _ping(ActionsConstants.MEMBER_REMOVED, bytes32(bytes20(_oldMember)), '');
  }

  /**
   * @notice Internal function to re-enter the Space Registry and emit another Action event
   * @param _action An action identifier
   * @param _topic A topic identifier
   * @param _data Some extra arbitrary data that may hold additional information
   * @dev _from and _to are always the DAO's address
   */
  function _ping(bytes32 _action, bytes32 _topic, bytes memory _data) internal {
    spaceRegistry.enter(address(this), address(this), _action, _topic, _data, '');
  }

  /**
   * @notice Checks if an account can vote on a proposal
   * @param _account The address of the account to check
   * @param _proposalId The ID of the proposal
   * @param _voteOption The vote option being cast
   * @return True if the account can vote, false otherwise
   * @dev Returns false if proposal doesn't exist, voting ended, vote option is None, or account
   * wasn't an editor at snapshot block. Vote replacement allowed.
   */
  function _canVote(address _account, uint256 _proposalId, VoteOption _voteOption) internal view returns (bool) {
    Proposal storage proposal_ = _proposals[_proposalId];
    // Proposal does not exist
    if (proposal_.parameters.startDate == 0) return false;
    // The proposal voting period has already ended.
    if (block.timestamp > proposal_.parameters.lastDate) return false;
    // The proposal has already been executed.
    if (proposal_.executed) return false;
    // The voter votes `None` which is not allowed.
    if (_voteOption == VoteOption.None) return false;
    // The voter has no voting power.
    if (!hasRole(EDITOR, _account)) return false;
    return true;
  }

  /**
   * @notice Checks if a proposal can be executed
   * @param _proposalId The ID of the proposal to check
   * @return True if the proposal can be executed, false otherwise
   * @dev Returns false if proposal doesn't exist, already executed, or threshold not met.
   * Slow path requires voting period to end; fast path can execute immediately.
   */
  function _canExecuteProposal(uint256 _proposalId) internal view returns (bool) {
    Proposal storage proposal_ = _proposals[_proposalId];
    // Verify that the proposal has not been executed already.
    if (proposal_.executed) return false;
    // Proposal does not exist
    if (proposal_.parameters.startDate == 0) return false;
    // Support threshold not reached
    if (!isSupportThresholdReached(_proposalId)) return false;
    return true;
  }
}
