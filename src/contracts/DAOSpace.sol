// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {SpaceAccessControl} from 'contracts/utils/SpaceAccessControl.sol';

import {IDAOSpace} from 'interfaces/IDAOSpace.sol';
import {ISpace} from 'interfaces/ISpace.sol';
import {ISpaceRegistry} from 'interfaces/ISpaceRegistry.sol';
import {ISemver} from 'interfaces/utils/ISemver.sol';

import 'src/ActionsConstants.sol' as ActionsConstants;

/**
 * @title DAOSpace
 * @notice Manages governance proposals and voting for a DAO Space
 * @dev This contract allows members and editors to create proposals, vote, and execute them.
 *      This contract also implements a dual-path governance: fast path (threshold-based, immediate execution)
 *      and slow path (majority voting with voting window). Fast path escalates to slow path on "No" vote.
 */
contract DAOSpace is SpaceAccessControl, IDAOSpace {
  /// @inheritdoc IDAOSpace
  uint256 public constant MINIMUM_VOTING_DURATION = 1 minutes;

  /// @inheritdoc IDAOSpace
  uint256 public constant RATIO_BASE = 10e6;

  /// @inheritdoc IDAOSpace
  bytes32 public constant FAST_PATH_RESTRICTED = keccak256('FAST_PATH_RESTRICTED');

  /// @inheritdoc IDAOSpace
  bytes32 public constant SPACE_REGISTRY = keccak256('SPACE_REGISTRY');

  /// @inheritdoc IDAOSpace
  bytes32 public constant EDITOR = keccak256('EDITOR');

  /// @inheritdoc IDAOSpace
  bytes32 public constant MEMBER = keccak256('MEMBER');

  /// @inheritdoc IDAOSpace
  bytes32 public constant DAO = keccak256('DAO');

  /**
   * @notice The storage location of the DAO space contract
   * @custom:storage-location erc7201:geo.storage.DAOSpace
   * @dev Computed with: keccak256(abi.encode(uint256(keccak256("geo.storage.DAOSpace")) - 1)) & ~bytes32(uint256(0xff))
   */
  bytes32 internal constant _DAO_SPACE_STORAGE_LOCATION =
    0xca9a28eed6337bb89b7996aa1033645556bf4017a5207860882394677302bc00;

  /**
   * @notice Restricts the caller to only those with the given role
   * @param _role The role governing access control
   */
  modifier onlyRole(bytes32 _role) {
    DAOSpaceStorage storage $ = _getDAOSpaceStorage();
    if (!hasRole(_role, $.spaceRegistry.addressToSpaceId(msg.sender))) revert InvalidCaller();
    _;
  }

  /// @notice Constructor
  constructor() {
    _disableInitializers();
  }

  /// @inheritdoc IDAOSpace
  function initialize(bytes calldata _initializerData) external virtual initializer {
    // Decode initializer data
    (
      ISpaceRegistry _spaceRegistry,
      VotingSettings memory _votingSettings,
      bytes16[] memory _initialEditors,
      bytes16[] memory _initialMembers,
      bytes memory _publishEditsData
    ) = abi.decode(_initializerData, (ISpaceRegistry, VotingSettings, bytes16[], bytes16[], bytes));

    // Set Space Registry and register new DAO Space
    DAOSpaceStorage storage $ = _getDAOSpaceStorage();
    $.spaceRegistry = _spaceRegistry;
    bytes16 _daoSpaceId = $.spaceRegistry.registerSpaceId(typeId(), abi.encode(version()));

    // Ping the registry with initial edit if it exists
    if (_publishEditsData.length != 0) _ping(ActionsConstants.EDITS_PUBLISHED, '', _publishEditsData);

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
    _grantRole(SPACE_REGISTRY, _spaceRegistry.addressToSpaceId(address(_spaceRegistry)));
    _grantRole(DAO, _daoSpaceId);

    // Set the initial fast path actions
    $.actionIsFastPathValid[IDAOSpace.addMember.selector] = true;
    $.actionIsFastPathValid[IDAOSpace.removeMember.selector] = true;
    $.actionIsFastPathValid[IDAOSpace.publish.selector] = true;
    $.actionIsFastPathValid[IDAOSpace.flag.selector] = true;
    $.actionIsFastPathValid[IDAOSpace.unflag.selector] = true;
  }

  /// @inheritdoc ISpace
  function write(
    bytes16 _fromSpaceId,
    bytes32 _action,
    bytes32,
    bytes calldata _data
  ) external virtual onlyRole(SPACE_REGISTRY) {
    // Governance Actions
    if (_action == ActionsConstants.PROPOSAL_CREATED) {
      _createProposal(_fromSpaceId, _data);
    } else if (_action == ActionsConstants.PROPOSAL_VOTED) {
      _vote(_fromSpaceId, _data);
    } else if (_action == ActionsConstants.PROPOSAL_UPDATED) {
      _updateProposal(_fromSpaceId, _data);
    } else if (_action == ActionsConstants.PROPOSAL_EXECUTED) {
      _executeProposal(_data);
    } else if (_action == ActionsConstants.SPACE_LEFT) {
      _leave(_fromSpaceId, _data);
    } else if (_action == ActionsConstants.SPACE_FAST_PATH_RESTRICTED) {
      _restrictSpace(_fromSpaceId, _data);
    } else {
      // Must attempt to write in some way
      revert InvalidAction();
    }
  }

  /// @inheritdoc ISpace
  function verify(address, bytes16, bytes32, bytes32, bytes calldata, bytes calldata) external pure virtual {
    revert VerifyDisabled();
  }

  /// @inheritdoc IDAOSpace
  function addEditor(bytes16 _newEditorSpaceId) public virtual onlyRole(DAO) {
    _addEditor(_newEditorSpaceId);
  }

  /// @inheritdoc IDAOSpace
  function removeEditor(bytes16 _oldEditorSpaceId) public virtual onlyRole(DAO) {
    _removeEditor(_oldEditorSpaceId);
  }

  /// @inheritdoc IDAOSpace
  function addMember(bytes16 _newMemberSpaceId) public virtual onlyRole(DAO) {
    _addMember(_newMemberSpaceId);
  }

  /// @inheritdoc IDAOSpace
  function removeMember(bytes16 _oldMemberSpaceId) public virtual onlyRole(DAO) {
    _removeMember(_oldMemberSpaceId);
  }

  /// @inheritdoc IDAOSpace
  function unrestrictSpace(bytes16 _spaceId) public virtual onlyRole(DAO) {
    _unrestrictSpace(_spaceId);
  }

  /// @inheritdoc IDAOSpace
  function ping(bytes32 _action, bytes32 _topic, bytes calldata _data) public virtual onlyRole(DAO) {
    _ping(_action, _topic, _data);
  }

  /// @inheritdoc IDAOSpace
  function publish(
    bytes32 _topic,
    bytes memory _editsContentUri,
    bytes memory _editsMetadata
  ) public virtual onlyRole(DAO) {
    _ping(ActionsConstants.EDITS_PUBLISHED, _topic, abi.encode(_editsContentUri, _editsMetadata));
  }

  /// @inheritdoc IDAOSpace
  function flag(bytes32 _topic, bytes calldata _flaggedId) public virtual onlyRole(DAO) {
    _ping(ActionsConstants.FLAGGED, _topic, _flaggedId);
  }

  /// @inheritdoc IDAOSpace
  function unflag(bytes32 _topic, bytes calldata _unflaggedId) public virtual onlyRole(DAO) {
    _ping(ActionsConstants.UNFLAGGED, _topic, _unflaggedId);
  }

  /// @inheritdoc IDAOSpace
  function updateVotingSettings(VotingSettings calldata _votingSettings) public virtual onlyRole(DAO) {
    _updateVotingSettings(_votingSettings);
  }

  /// @inheritdoc ISpace
  function fetch(
    bytes32 _action,
    bytes32 _topicInput,
    bytes calldata _data
  ) public view virtual returns (bytes32 _topicOutput) {
    if (_action == ActionsConstants.PROPOSAL_CREATED) {
      (bytes16 _proposalId,,) = abi.decode(_data, (bytes16, VotingMode, Action[]));
      return bytes32(_proposalId);
    } else if (_action == ActionsConstants.PROPOSAL_VOTED) {
      (bytes16 _proposalId,) = abi.decode(_data, (bytes16, VoteOption));
      return bytes32(_proposalId);
    } else if (_action == ActionsConstants.PROPOSAL_UPDATED) {
      (bytes16 _proposalId,,) = abi.decode(_data, (bytes16, VotingMode, Action[]));
      return bytes32(_proposalId);
    } else if (_action == ActionsConstants.PROPOSAL_EXECUTED) {
      bytes16 _proposalId = abi.decode(_data, (bytes16));
      return bytes32(_proposalId);
    } else if (_action == ActionsConstants.SPACE_LEFT) {
      bytes32 _role = abi.decode(_data, (bytes32));
      return _role;
    } else if (_action == ActionsConstants.SPACE_FAST_PATH_RESTRICTED) {
      bytes16 _spaceId = abi.decode(_data, (bytes16));
      return bytes32(_spaceId);
    } else {
      return _topicInput;
    }
  }

  /// @inheritdoc IDAOSpace
  function isSupportThresholdReached(bytes16 _proposalId)
    public
    view
    virtual
    returns (bool _isSupportThresholdReached)
  {
    Proposal storage proposal_ = _getLatestProposalStorage(_proposalId);
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
  function votingSettings() public view returns (VotingSettings memory _votingSettings) {
    DAOSpaceStorage storage $ = _getDAOSpaceStorage();
    _votingSettings = $.votingSettings;
  }

  /// @inheritdoc IDAOSpace
  function totalEditors() public view returns (uint256 _totalEditors) {
    DAOSpaceStorage storage $ = _getDAOSpaceStorage();
    _totalEditors = $.totalEditors;
  }

  /// @inheritdoc IDAOSpace
  function actionIsFastPathValid(bytes4 _selector) public view returns (bool _isValid) {
    DAOSpaceStorage storage $ = _getDAOSpaceStorage();
    _isValid = $.actionIsFastPathValid[_selector];
  }

  /// @inheritdoc IDAOSpace
  function latestProposalVersion(bytes16 _proposalId) public view returns (uint8 _version) {
    DAOSpaceStorage storage $ = _getDAOSpaceStorage();
    _version = $.latestProposalVersion[_proposalId];
  }

  /// @inheritdoc IDAOSpace
  function getProposalInformation(
    bytes16 _proposalId,
    uint8 _version
  )
    public
    view
    returns (
      bool _executed,
      bytes16 _creator,
      ProposalParameters memory _parameters,
      Tally memory _tally,
      Action[] memory _actions
    )
  {
    DAOSpaceStorage storage $ = _getDAOSpaceStorage();
    _executed = $.proposals[_proposalId][_version].executed;
    _creator = $.proposals[_proposalId][_version].creator;
    _parameters = $.proposals[_proposalId][_version].parameters;
    _tally = $.proposals[_proposalId][_version].tally;
    _actions = $.proposals[_proposalId][_version].actions;
  }

  /// @inheritdoc IDAOSpace
  function getLatestProposalInformation(bytes16 _proposalId)
    public
    view
    returns (
      bool _executed,
      bytes16 _creator,
      ProposalParameters memory _parameters,
      Tally memory _tally,
      Action[] memory _actions
    )
  {
    Proposal storage proposal_ = _getLatestProposalStorage(_proposalId);
    _executed = proposal_.executed;
    _creator = proposal_.creator;
    _parameters = proposal_.parameters;
    _tally = proposal_.tally;
    _actions = proposal_.actions;
  }

  /// @inheritdoc IDAOSpace
  function getProposalVote(
    bytes16 _proposalId,
    uint8 _version,
    bytes16 _voterSpaceId
  ) public view returns (VoteOption _voteOption) {
    DAOSpaceStorage storage $ = _getDAOSpaceStorage();
    _voteOption = $.proposals[_proposalId][_version].voters[_voterSpaceId];
  }

  /// @inheritdoc IDAOSpace
  function getLatestProposalVote(
    bytes16 _proposalId,
    bytes16 _voterSpaceId
  ) public view returns (VoteOption _voteOption) {
    Proposal storage proposal_ = _getLatestProposalStorage(_proposalId);
    _voteOption = proposal_.voters[_voterSpaceId];
  }

  /// @inheritdoc IDAOSpace
  function spaceRegistry() public view returns (ISpaceRegistry _spaceRegistry) {
    DAOSpaceStorage storage $ = _getDAOSpaceStorage();
    _spaceRegistry = $.spaceRegistry;
  }

  /// @inheritdoc ISemver
  function typeId() public pure virtual returns (bytes32 _type) {
    _type = keccak256(bytes('DAO_SPACE'));
  }

  /// @inheritdoc ISemver
  function name() public pure virtual returns (string memory _name) {
    _name = 'DAO_SPACE';
  }

  /// @inheritdoc ISemver
  function version() public pure virtual returns (string memory _version) {
    _version = '1.0.0';
  }

  /**
   * @notice Sets the voting settings for the DAO
   * @param _votingSettings The new voting settings
   * @dev Several checks are performed to ensure the new settings do not prevent future proposals from
   * being executed.
   */
  function _updateVotingSettings(VotingSettings memory _votingSettings) internal virtual {
    DAOSpaceStorage storage $ = _getDAOSpaceStorage();
    if (_votingSettings.slowPathPercentageThreshold > RATIO_BASE) revert InvalidSetting();
    if (_votingSettings.fastPathFlatThreshold > $.totalEditors) revert InvalidSetting();
    if (_votingSettings.quorum > $.totalEditors) revert InvalidSetting();
    if (_votingSettings.duration < MINIMUM_VOTING_DURATION) revert InvalidSetting();
    $.votingSettings = _votingSettings;
  }

  /**
   * @notice Decodes input data and then creates a new proposal
   * @param _fromSpaceId The space ID creating the proposal
   * @param _data The encoded proposal data containing the voting mode and actions
   */
  function _createProposal(bytes16 _fromSpaceId, bytes calldata _data) internal virtual {
    // Decode data to construct proposal
    (bytes16 _proposalId, VotingMode _votingMode, Action[] memory _actions) =
      abi.decode(_data, (bytes16, VotingMode, Action[]));
    Proposal storage proposal_ = _getLatestProposalStorage(_proposalId);
    if (proposal_.parameters.startDate != 0) revert InvalidProposalId();
    // Update proposal storage
    _createProposal(_fromSpaceId, _proposalId, _votingMode, _actions);
  }

  /**
   * @notice Creates a new governance proposal
   * @param _fromSpaceId The space ID creating the proposal
   * @param _proposalId The proposal identifier
   * @param _votingMode The voting mode (slow or fast) of the proposal
   * @param _actions The actions to be undertaken if the proposal is successful
   * @dev Fast path: only editors can create, creator must not be restricted, single action required,
   * action selector must be valid. Slow path: members or editors can create, multiple actions allowed.
   */
  function _createProposal(
    bytes16 _fromSpaceId,
    bytes16 _proposalId,
    VotingMode _votingMode,
    Action[] memory _actions
  ) internal virtual {
    DAOSpaceStorage storage $ = _getDAOSpaceStorage();
    $.latestProposalVersion[_proposalId]++;
    // Update proposal storage
    Proposal storage proposal_ = _getLatestProposalStorage(_proposalId);
    proposal_.creator = _fromSpaceId;
    proposal_.parameters.startDate = block.timestamp;
    proposal_.parameters.lastDate = block.timestamp + $.votingSettings.duration;
    proposal_.parameters.votingMode = _votingMode;
    proposal_.parameters.quorum = $.votingSettings.quorum;
    if (_votingMode == VotingMode.Slow) {
      // Slow path
      // Only members or editors can create slow path proposals
      if (!(hasRole(MEMBER, _fromSpaceId) || hasRole(EDITOR, _fromSpaceId))) revert InvalidFromSpace();
      proposal_.parameters.supportThreshold = $.votingSettings.slowPathPercentageThreshold;
    } else {
      // Fast path
      // Only editors can create fast path proposals
      if (!hasRole(EDITOR, _fromSpaceId)) revert InvalidFromSpace();
      // Checks from space is allowed to use fast path
      if (hasRole(FAST_PATH_RESTRICTED, _fromSpaceId)) revert FastPathRestricted();
      // limit the actions to one call
      if (_actions.length != 1) revert OneActionForFastPath();
      // limit to only valid fast path actions
      if (!$.actionIsFastPathValid[bytes4(_actions[0].data)]) revert InvalidAction();
      // limit the target to only this address
      if (_actions[0].to != address(this)) revert InvalidTarget();
      // limit the transfer of funds
      if (_actions[0].value != 0) revert InvalidFundsTransfer();
      proposal_.parameters.supportThreshold = $.votingSettings.fastPathFlatThreshold;
    }
    for (uint256 i; i < _actions.length; i++) {
      proposal_.actions.push(_actions[i]);
    }
    // Ping the registry to emit the proposal settings
    _ping(
      ActionsConstants.PROPOSAL_SETTINGS_SELECTED,
      bytes32(_proposalId),
      abi.encode(
        proposal_.parameters.startDate,
        proposal_.parameters.lastDate,
        proposal_.parameters.votingMode,
        proposal_.parameters.quorum,
        proposal_.parameters.supportThreshold
      )
    );
  }

  /**
   * @notice Votes on a proposal
   * @param _fromSpaceId The space ID casting the vote
   * @param _data The encoded vote data containing proposal ID and vote option
   * @dev Only editors can vote. Vote replacement allowed. "No" vote on fast path escalates to slow path.
   * Fast path can execute immediately if threshold met; slow path requires voting period to end.
   */
  function _vote(bytes16 _fromSpaceId, bytes calldata _data) internal virtual {
    // Decode data to construct vote
    (bytes16 _proposalId, VoteOption _voteOption) = abi.decode(_data, (bytes16, VoteOption));
    // Ensure _fromSpaceId can vote
    if (!_canVote(_fromSpaceId, _proposalId, _voteOption)) revert CanNotVote();
    DAOSpaceStorage storage $ = _getDAOSpaceStorage();
    Proposal storage proposal_ = _getLatestProposalStorage(_proposalId);
    // Remove the previous vote.
    VoteOption state = proposal_.voters[_fromSpaceId];
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
    proposal_.voters[_fromSpaceId] = _voteOption;
    // extra fast path logic
    if (proposal_.parameters.votingMode == VotingMode.Fast) {
      // fast path to slow path if rejection occurs
      if (_voteOption == VoteOption.No) {
        // Update voting mode
        proposal_.parameters.votingMode = VotingMode.Slow;
        // Update threshold
        proposal_.parameters.supportThreshold = $.votingSettings.slowPathPercentageThreshold;
        // Reset duration and block times
        proposal_.parameters.startDate = block.timestamp;
        proposal_.parameters.lastDate = block.timestamp + $.votingSettings.duration;
        // Ping the registry to emit the updated proposal settings
        _ping(
          ActionsConstants.PROPOSAL_SETTINGS_SELECTED,
          bytes32(_proposalId),
          abi.encode(
            proposal_.parameters.startDate,
            proposal_.parameters.lastDate,
            proposal_.parameters.votingMode,
            proposal_.parameters.quorum,
            proposal_.parameters.supportThreshold
          )
        );
      } else if (_voteOption == VoteOption.Yes) {
        // immediate execution if possible
        if (_canExecuteProposal(_proposalId)) _executeProposal(_proposalId);
      }
    }
  }

  /**
   * @notice Allows a proposal creator to update and reset a proposal if it has not been executed
   * @param _fromSpaceId The space ID updating the proposal
   * @param _data The encoded proposal data used to update the proposal with a new version
   * @dev Only the creator of the proposal can update it.
   */
  function _updateProposal(bytes16 _fromSpaceId, bytes calldata _data) internal virtual {
    // Decode data to construct new proposal
    (bytes16 _proposalId, VotingMode _votingMode, Action[] memory _actions) =
      abi.decode(_data, (bytes16, VotingMode, Action[]));
    Proposal storage proposal_ = _getLatestProposalStorage(_proposalId);
    // Check proposal exists and that only the creator can update it
    if (proposal_.creator != _fromSpaceId) revert InvalidCaller();
    // May not update an already executed proposal
    if (proposal_.executed) revert InvalidProposalId();
    // Update proposal storage
    _createProposal(_fromSpaceId, _proposalId, _votingMode, _actions);
  }

  /**
   * @notice Decodes input data and then executes a proposal after it has passed
   * @param _data The encoded execution data containing the proposal ID
   */
  function _executeProposal(bytes calldata _data) internal virtual {
    // Anyone can call
    // Check if proposal can be settled
    bytes16 _proposalId = abi.decode(_data, (bytes16));
    if (!_canExecuteProposal(_proposalId)) revert CanNotExecute();
    _executeProposal(_proposalId);
  }

  /**
   * @notice Executes a proposal after it has passed
   * @param _proposalId The proposal ID of the proposal to be executed
   * @dev Anyone can call once execution criteria met. Actions executed sequentially. Reverts if any action fails.
   */
  function _executeProposal(bytes16 _proposalId) internal virtual {
    Proposal storage proposal_ = _getLatestProposalStorage(_proposalId);
    // Set proposal as executed
    proposal_.executed = true;
    // Loop over actions
    Action[] memory actions = proposal_.actions;
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
   * @param _fromSpaceId The space ID leaving
   * @param _data The encoded role data used to determine which role a user wants to leave
   */
  function _leave(bytes16 _fromSpaceId, bytes calldata _data) internal virtual {
    bytes32 role = abi.decode(_data, (bytes32));
    if (role == MEMBER && hasRole(MEMBER, _fromSpaceId)) {
      _removeMember(_fromSpaceId);
    } else if (role == EDITOR && hasRole(EDITOR, _fromSpaceId)) {
      _removeEditor(_fromSpaceId);
    } else {
      revert InvalidFromSpace();
    }
  }

  /**
   * @notice Restricts a space from creating fast path proposals
   * @param _fromSpaceId The space ID of the editor performing the restriction
   * @param _data The encoded data containing the space ID to flag
   * @dev Only editors can restrict others.
   */
  function _restrictSpace(bytes16 _fromSpaceId, bytes calldata _data) internal virtual {
    if (!hasRole(EDITOR, _fromSpaceId)) revert InvalidFromSpace();
    bytes16 _spaceId = abi.decode(_data, (bytes16));
    _grantRole(FAST_PATH_RESTRICTED, _spaceId);
  }

  /**
   * @notice Unrestricts a space allowing them to create fast path proposals
   * @param _spaceId The space ID to be unrestricted
   */
  function _unrestrictSpace(bytes16 _spaceId) internal virtual {
    _revokeRole(FAST_PATH_RESTRICTED, _spaceId);
    _ping(ActionsConstants.SPACE_FAST_PATH_UNRESTRICTED, bytes32(_spaceId), '');
  }

  /**
   * @notice Internal function to add an editor
   * @param _newEditorSpaceId The space ID of the new editor
   */
  function _addEditor(bytes16 _newEditorSpaceId) internal virtual {
    if (hasRole(EDITOR, _newEditorSpaceId)) revert InvalidSpaceIdForRole();
    _grantRole(EDITOR, _newEditorSpaceId);
    DAOSpaceStorage storage $ = _getDAOSpaceStorage();
    $.totalEditors++;
    _ping(ActionsConstants.EDITOR_ADDED, bytes32(_newEditorSpaceId), '');
  }

  /**
   * @notice Internal function to remove an editor
   * @param _oldEditorSpaceId The space ID of the editor to remove
   * @dev If removal fails due to invalid settings, first update the settings to lower the quorum and/or the
   * fastPathFlatThreshold. Both the settings update and editor removal operations may be bundled into one proposal
   * for convenience.
   */
  function _removeEditor(bytes16 _oldEditorSpaceId) internal virtual {
    if (!hasRole(EDITOR, _oldEditorSpaceId)) revert InvalidSpaceIdForRole();
    // May not remove editor if doing so would prevent proposals from being executed
    DAOSpaceStorage storage $ = _getDAOSpaceStorage();
    if ($.votingSettings.quorum == $.totalEditors) revert InvalidSetting();
    if ($.votingSettings.fastPathFlatThreshold == $.totalEditors) revert InvalidSetting();
    _revokeRole(EDITOR, _oldEditorSpaceId);
    $.totalEditors--;
    _ping(ActionsConstants.EDITOR_REMOVED, bytes32(_oldEditorSpaceId), '');
  }

  /**
   * @notice Internal function to add a member
   * @param _newMemberSpaceId The space ID of the new member
   */
  function _addMember(bytes16 _newMemberSpaceId) internal virtual {
    if (hasRole(MEMBER, _newMemberSpaceId)) revert InvalidSpaceIdForRole();
    _grantRole(MEMBER, _newMemberSpaceId);
    _ping(ActionsConstants.MEMBER_ADDED, bytes32(_newMemberSpaceId), '');
  }

  /**
   * @notice Internal function to remove a member
   * @param _oldMemberSpaceId The space ID of the member to remove
   */
  function _removeMember(bytes16 _oldMemberSpaceId) internal virtual {
    if (!hasRole(MEMBER, _oldMemberSpaceId)) revert InvalidSpaceIdForRole();
    _revokeRole(MEMBER, _oldMemberSpaceId);
    _ping(ActionsConstants.MEMBER_REMOVED, bytes32(_oldMemberSpaceId), '');
  }

  /**
   * @notice Internal function to re-enter the Space Registry and emit another Action event
   * @param _action An action identifier
   * @param _topic A topic identifier
   * @param _data Some extra arbitrary data that may hold additional information
   * @dev _from and _to are always the DAO's space ID
   */
  function _ping(bytes32 _action, bytes32 _topic, bytes memory _data) internal virtual {
    DAOSpaceStorage storage $ = _getDAOSpaceStorage();
    bytes16 daoSpaceId = $.spaceRegistry.addressToSpaceId(address(this));
    $.spaceRegistry.enter(daoSpaceId, daoSpaceId, _action, _topic, _data, '');
  }

  /**
   * @notice Checks if a space can vote on a proposal
   * @param _spaceId The space ID to check
   * @param _proposalId The ID of the proposal
   * @param _voteOption The vote option being cast
   * @return True if the space can vote, false otherwise
   * @dev Returns false if proposal doesn't exist, voting ended, vote option is None, or space
   * wasn't an editor at snapshot block. Vote replacement allowed.
   */
  function _canVote(
    bytes16 _spaceId,
    bytes16 _proposalId,
    VoteOption _voteOption
  ) internal view virtual returns (bool) {
    Proposal storage proposal_ = _getLatestProposalStorage(_proposalId);
    // Proposal does not exist
    if (proposal_.parameters.startDate == 0) return false;
    // The proposal voting period has already ended.
    if (block.timestamp > proposal_.parameters.lastDate) return false;
    // The proposal has already been executed.
    if (proposal_.executed) return false;
    // The voter votes `None` which is not allowed.
    if (_voteOption == VoteOption.None) return false;
    // The voter has no voting power.
    if (!hasRole(EDITOR, _spaceId)) return false;
    return true;
  }

  /**
   * @notice Checks if a proposal can be executed
   * @param _proposalId The ID of the proposal to check
   * @return True if the proposal can be executed, false otherwise
   * @dev Returns false if proposal doesn't exist, already executed, or threshold not met.
   * Slow path requires voting period to end; fast path can execute immediately.
   */
  function _canExecuteProposal(bytes16 _proposalId) internal view virtual returns (bool) {
    Proposal storage proposal_ = _getLatestProposalStorage(_proposalId);
    // Verify that the proposal has not been executed already.
    if (proposal_.executed) return false;
    // Proposal does not exist
    if (proposal_.parameters.startDate == 0) return false;
    // Support threshold not reached
    if (!isSupportThresholdReached(_proposalId)) return false;
    return true;
  }

  /**
   * @notice Returns the latest storage of a proposal
   * @param _proposalId The proposal id
   * @return _proposal The storage of a proposal
   */
  function _getLatestProposalStorage(bytes16 _proposalId) internal view returns (Proposal storage _proposal) {
    DAOSpaceStorage storage $ = _getDAOSpaceStorage();
    uint8 _version = $.latestProposalVersion[_proposalId];
    _proposal = $.proposals[_proposalId][_version];
  }

  /**
   * @notice Returns the DAO space contract storage
   * @return $ The storage of the DAO space contract
   * @custom:storage-location erc7201:geo.storage.DAOSpace
   */
  function _getDAOSpaceStorage() internal pure returns (DAOSpaceStorage storage $) {
    assembly {
      $.slot := _DAO_SPACE_STORAGE_LOCATION
    }
  }
}
