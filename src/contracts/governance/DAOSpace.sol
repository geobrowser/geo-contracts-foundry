// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

import {AccessControlUpgradeable} from '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import {
  ERC1967UpgradeUpgradeable
} from '@openzeppelin/contracts-upgradeable/proxy/ERC1967/ERC1967UpgradeUpgradeable.sol';
import {CheckpointsUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/CheckpointsUpgradeable.sol';

import {DAOSpaceConstants} from 'contracts/governance/DAOSpaceConstants.sol';

import {IDAOSpace, ISpace} from 'interfaces/governance/IDAOSpace.sol';
import {ISpaceRegistry} from 'interfaces/registry/ISpaceRegistry.sol';

/**
 * @title DAOSpace
 * @notice Manages governance proposals and voting for a DAO Space
 * @dev This contract allows members and editors to create proposals, vote, and execute them.
 * It implements a majority voting system with configurable voting modes and threshold settings.
 * The contract uses checkpointing to track editor membership over time for snapshot-based voting.
 */
contract DAOSpace is ERC1967UpgradeUpgradeable, AccessControlUpgradeable, DAOSpaceConstants, IDAOSpace {
  using CheckpointsUpgradeable for CheckpointsUpgradeable.History;

  /// @inheritdoc IDAOSpace
  ISpaceRegistry public spaceRegistry;

  /// @inheritdoc IDAOSpace
  uint256 public proposalCounter;

  /// @inheritdoc IDAOSpace
  VotingSettings public votingSettings;

  /// @notice Stores information about a proposal by its ID
  mapping(uint256 => Proposal) private _proposals;

  /// @notice Checkpoints tracking editor membership at different block numbers
  mapping(address => CheckpointsUpgradeable.History) private _editorsCheckpoints;

  /// @notice Checkpoints tracking the total number of editors at different block numbers
  CheckpointsUpgradeable.History private _editorsLengthCheckpoints;

  /// @inheritdoc IDAOSpace
  function initialize(
    ISpaceRegistry _spaceRegistry,
    VotingSettings calldata _votingSettings,
    address[] calldata _initialEditors,
    address[] calldata _initialMembers
  ) external initializer {
    spaceRegistry = _spaceRegistry;
    votingSettings = _votingSettings;
    uint256 editorsLength = _initialEditors.length;
    for (uint256 i; i < editorsLength; i++) {
      _addEditor(_initialEditors[i]);
    }
    uint256 membersLength = _initialMembers.length;
    for (uint256 j; j < membersLength; j++) {
      _addMember(_initialMembers[j]);
    }
    _grantRole(DAO, address(this));
  }

  /// @inheritdoc ISpace
  function write(address _fromSpace, bytes32 _action, bytes32 _topic, bytes calldata _data) external {
    // Only Space Registry can call
    if (msg.sender != address(spaceRegistry)) revert InvalidCaller();
    // Actions
    if (_action == CREATE_PROPOSAL) {
      _createProposal(_fromSpace, _data);
    } else if (_action == VOTE) {
      _vote(_fromSpace, _data);
    } else if (_action == EXECUTE_PROPOSAL) {
      _executeProposal(_data);
    } else if (_action == LEAVE) {
      _leave(_fromSpace);
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

  /// @inheritdoc ISpace
  function fetch(bytes32 _action) public view returns (bytes32 _topicOutput) {
    if (_action == CREATE_PROPOSAL) return bytes32(proposalCounter);
  }

  /// @inheritdoc IDAOSpace
  function isEditorAtBlock(address _account, uint256 _blockNumber) public view returns (bool) {
    return _editorsCheckpoints[_account].getAtBlock(_blockNumber) == 1;
  }

  /// @inheritdoc IDAOSpace
  function editorsLengthAtBlock(uint256 _blockNumber) public view returns (uint256) {
    return _editorsLengthCheckpoints.getAtBlock(_blockNumber);
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

  /// @inheritdoc IDAOSpace
  function getSupportThresholdPercentage(uint256 _proposalId) public view returns (uint256) {
    Proposal storage proposal_ = _proposals[_proposalId];
    // If the threshold value is zero, return zero
    if (proposal_.parameters.supportThreshold == 0) return 0;
    // Require the support threshold value to be in the interval [0, 10^6-1], because `>` comparison is used in the support criterion and >100% could never be reached.
    if (proposal_.parameters.thresholdMode == ThresholdMode.Percentage) {
      return proposal_.parameters.supportThreshold - 1;
    } else {
      // Fetch total voters to convert flat threshold to a percentage
      uint256 totalVoters = editorsLengthAtBlock(proposal_.parameters.snapshotBlock);
      // If no voters exist, return zero
      if (totalVoters == 0) return 0;
      // If the flat threshold exceeds the total number of voters, everyone must vote
      if (uint256(proposal_.parameters.supportThreshold) >= totalVoters) return RATIO_BASE - 1;
      // Else dynamically determine the threshold percentage
      return ((proposal_.parameters.supportThreshold * RATIO_BASE) / totalVoters) - 1;
    }
  }

  /// @inheritdoc IDAOSpace
  function isSupportThresholdReached(uint256 _proposalId) public view returns (bool) {
    Proposal storage proposal_ = _proposals[_proposalId];
    uint256 supportThresholdPercentage = getSupportThresholdPercentage(_proposalId);
    // Calculates outcome
    return
      (RATIO_BASE - supportThresholdPercentage) * proposal_.tally.yes > supportThresholdPercentage * proposal_.tally.no;
  }

  /// @inheritdoc IDAOSpace
  function isSupportThresholdReachedEarly(uint256 _proposalId) public view returns (bool) {
    Proposal storage proposal_ = _proposals[_proposalId];
    // Return false if early execution not enabled.
    if (proposal_.parameters.votingMode != VotingMode.EarlyExecution) return false;
    uint256 supportThresholdPercentage = getSupportThresholdPercentage(_proposalId);
    uint256 noVotesWorstCase =
      editorsLengthAtBlock(proposal_.parameters.snapshotBlock) - proposal_.tally.yes - proposal_.tally.abstain;
    // Calculates outcome
    return
      (RATIO_BASE - supportThresholdPercentage) * proposal_.tally.yes > supportThresholdPercentage * noVotesWorstCase;
  }

  /**
   * @notice Creates a new governance proposal
   * @param _fromSpace The address of the space creating the proposal
   * @param _data The encoded proposal data containing URI and actions
   * @dev This function can only be called by members or editors. The proposal parameters are
   * set based on the voting settings, and the snapshot block is set to block.number - 1 to
   * protect against backrunning transactions causing census changes.
   */
  function _createProposal(address _fromSpace, bytes calldata _data) internal {
    // Only members or editors can create a proposal
    if (!(hasRole(MEMBER, _fromSpace) || hasRole(EDITOR, _fromSpace))) revert InvalidCaller();
    // Decode data to construct proposal
    (, Action[] memory actions) = abi.decode(_data, (bytes, Action[]));
    // Update proposal storage
    Proposal storage proposal_ = _proposals[proposalCounter++];
    proposal_.parameters.startDate = block.timestamp;
    proposal_.parameters.endDate = block.timestamp + votingSettings.duration;
    // The snapshot block must be mined already to protect the transaction against backrunning transactions causing census changes.
    proposal_.parameters.snapshotBlock = block.number - 1;
    proposal_.parameters.votingMode = votingSettings.votingMode;
    proposal_.parameters.thresholdMode = votingSettings.thresholdMode;
    proposal_.parameters.supportThreshold = votingSettings.supportThreshold;
    for (uint256 i; i < actions.length; i++) {
      proposal_.actions.push(actions[i]);
    }
  }

  /**
   * @notice Votes on a proposal
   * @param _fromSpace The address of the space casting the vote
   * @param _data The encoded vote data containing proposal ID and vote option
   * @dev This function can only be called by editors. If vote replacement is enabled and the
   * editor has already voted, the previous vote is removed before adding the new vote.
   */
  function _vote(address _fromSpace, bytes calldata _data) internal {
    // Only editors can vote
    if (!hasRole(EDITOR, _fromSpace)) revert InvalidCaller();
    // Decode data to construct vote
    (uint256 _proposalId, VoteOption _voteOption) = abi.decode(_data, (uint256, VoteOption));
    // Ensure editor can vote
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
  }

  /**
   * @notice Executes a proposal after it has passed
   * @param _data The encoded execution data containing the proposal ID
   * @dev Anyone can call this function. All actions in the proposal are executed sequentially.
   * If any action reverts, the entire execution reverts.
   */
  function _executeProposal(bytes calldata _data) internal {
    // Anyone can call
    // Check if proposal can be settled
    uint256 _proposalId = abi.decode(_data, (uint256));
    if (!_canExecuteProposal(_proposalId)) revert CanNotSettle();
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
   * @dev If the address is a member, removes them as a member. If they are an editor, removes
   * them as an editor.
   */
  function _leave(address _fromSpace) internal {
    if (hasRole(MEMBER, _fromSpace)) {
      _removeMember(_fromSpace);
    } else if (hasRole(EDITOR, _fromSpace)) {
      _removeEditor(_fromSpace);
    } else {
      revert InvalidCaller();
    }
  }

  /**
   * @notice Internal function to add an editor
   * @param _newEditor The address of the new editor
   * @dev Grants the EDITOR role and updates checkpoints for snapshot-based voting.
   * Also notifies the space registry of the editor addition.
   */
  function _addEditor(address _newEditor) internal {
    if (isEditorAtBlock(_newEditor, block.number)) revert InvalidAddress();
    // Grant the role for access control
    _grantRole(EDITOR, _newEditor);
    // Mark the address as an editor for votes
    _editorsCheckpoints[_newEditor].push(1);
    _editorsLengthCheckpoints.push(1);
    // Ping the registry
    spaceRegistry.enter(address(this), address(this), keccak256('ADD_EDITOR'), bytes32(bytes20(_newEditor)), '', '');
  }

  /**
   * @notice Internal function to remove an editor
   * @param _oldEditor The address of the editor to remove
   * @dev Revokes the EDITOR role and updates checkpoints for snapshot-based voting.
   * Also notifies the space registry of the editor removal.
   */
  function _removeEditor(address _oldEditor) internal {
    if (!isEditorAtBlock(_oldEditor, block.number)) revert InvalidAddress();
    // Revoke the role for access control
    _revokeRole(EDITOR, _oldEditor);
    // Mark the address as no longer an editor for votes
    _editorsCheckpoints[_oldEditor].push(0);
    _editorsLengthCheckpoints.push(1);
    // Ping the registry
    spaceRegistry.enter(address(this), address(this), keccak256('REMOVE_EDITOR'), bytes32(bytes20(_oldEditor)), '', '');
  }

  /**
   * @notice Internal function to add a member
   * @param _newMember The address of the new member
   * @dev Grants the MEMBER role and notifies the space registry.
   */
  function _addMember(address _newMember) internal {
    if (hasRole(MEMBER, _newMember)) revert InvalidAddress();
    _grantRole(MEMBER, _newMember);
    spaceRegistry.enter(address(this), address(this), keccak256('ADD_MEMBER'), bytes32(bytes20(_newMember)), '', '');
  }

  /**
   * @notice Internal function to remove a member
   * @param _oldMember The address of the member to remove
   * @dev Revokes the MEMBER role and notifies the space registry.
   */
  function _removeMember(address _oldMember) internal {
    if (!hasRole(MEMBER, _oldMember)) revert InvalidAddress();
    _revokeRole(MEMBER, _oldMember);
    spaceRegistry.enter(address(this), address(this), keccak256('REMOVE_MEMBER'), bytes32(bytes20(_oldMember)), '', '');
  }

  /**
   * @notice Checks if an account can vote on a proposal
   * @param _account The address of the account to check
   * @param _proposalId The ID of the proposal
   * @param _voteOption The vote option being cast
   * @return True if the account can vote, false otherwise
   * @dev Returns false if the proposal doesn't exist, has ended, the account has no voting power,
   * vote replacement is not allowed and the account has already voted, or the vote option is None.
   */
  function _canVote(address _account, uint256 _proposalId, VoteOption _voteOption) internal view returns (bool) {
    Proposal storage proposal_ = _proposals[_proposalId];
    // Proposal does not exist
    if (proposal_.parameters.startDate == 0) return false;
    // The proposal vote has already ended.
    if ((block.timestamp > proposal_.parameters.endDate || proposal_.executed)) return false;
    // The voter votes `None` which is not allowed.
    if (_voteOption == VoteOption.None) return false;
    // The voter has no voting power.
    if (!isEditorAtBlock(_account, proposal_.parameters.snapshotBlock)) return false;
    // The voter has already voted but vote replacement is not allowed.
    if (proposal_.voters[_account] != VoteOption.None && proposal_.parameters.votingMode != VotingMode.VoteReplacement) return false;
    return true;
  }

  /**
   * @notice Checks if a proposal can be executed
   * @param _proposalId The ID of the proposal to check
   * @return True if the proposal can be executed, false otherwise
   * @dev Returns false if the proposal doesn't exist, has already been executed, or doesn't
   * meet the execution threshold criteria. For early execution mode, uses worst-case scenario
   * calculations.
   */
  function _canExecuteProposal(uint256 _proposalId) internal view returns (bool) {
    Proposal storage proposal_ = _proposals[_proposalId];
    // Verify that the proposal has not been executed already.
    if (proposal_.executed) return false;
    // Proposal does not exist
    if (proposal_.parameters.startDate == 0) return false;
    if (block.timestamp < proposal_.parameters.endDate) {
      // Early execution
      if (!isSupportThresholdReachedEarly(_proposalId)) return false;
    } else {
      // Normal execution
      if (!isSupportThresholdReached(_proposalId)) return false;
    }
    return true;
  }
}
