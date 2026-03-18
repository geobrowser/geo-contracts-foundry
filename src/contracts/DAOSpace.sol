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
 *      This contract also implements a dual-path governance: fast path (flat-based, absolute threshold)
 *      and slow path (percentage-based, relative thresholds).
 *      Fast path escalates to slow path on "No" vote.
 *      Both paths execute immediately on "Yes" vote, if threshold is met.
 * @custom:security WARNING: This contract has not been audited, may contain bugs, and should not be used to hold funds.
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
    DAOSpaceStorage storage $_ = _getDAOSpaceStorage();
    if (!hasRole(_role, $_.spaceRegistry.addressToSpaceId(msg.sender))) revert InvalidCaller();
    _;
  }

  /// @notice Constructor
  /// @custom:oz-upgrades-unsafe-allow constructor
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
      bytes memory _publishEditsData,
      bytes16 _initialTopicId
    ) = abi.decode(_initializerData, (ISpaceRegistry, VotingSettings, bytes16[], bytes16[], bytes, bytes16));

    // Set Space Registry and register new DAO Space
    DAOSpaceStorage storage $_ = _getDAOSpaceStorage();
    $_.spaceRegistry = _spaceRegistry;
    bytes16 _daoSpaceId = $_.spaceRegistry.registerSpaceId(typeId(), abi.encode(version()));

    // Ping the registry with initial edit if it exists
    if (_publishEditsData.length != 0) _ping(ActionsConstants.EDITS_PUBLISHED, '', _publishEditsData);
    // Ping the registry again to set an initial topic
    if (_initialTopicId != bytes16(0)) _ping(ActionsConstants.TOPIC_SET, bytes32(_initialTopicId), '');

    // Add initial editors
    uint256 _length = _initialEditors.length;
    for (uint256 _i; _i < _length; _i++) {
      _addEditor(_initialEditors[_i]);
    }

    // Set voting settings
    // Must be added after editors but before members so that the default fast path member behaviour occurs
    _updateVotingSettings(_votingSettings);

    // Add initial members
    _length = _initialMembers.length;
    for (uint256 _j; _j < _length; _j++) {
      _addMember(_initialMembers[_j]);
    }
    // Grant further roles for access control
    _grantRole(SPACE_REGISTRY, _spaceRegistry.addressToSpaceId(address(_spaceRegistry)));
    _grantRole(DAO, _daoSpaceId);

    // Set the initial fast path actions
    $_.actionIsFastPathValid[IDAOSpace.addMember.selector] = true;
    $_.actionIsFastPathValid[IDAOSpace.removeMember.selector] = true;
    $_.actionIsFastPathValid[IDAOSpace.ping.selector] = true;
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
      _voteProposal(_fromSpaceId, _data);
    } else if (_action == ActionsConstants.PROPOSAL_UPDATED) {
      _updateProposal(_fromSpaceId, _data);
    } else if (_action == ActionsConstants.PROPOSAL_EXECUTED) {
      _executeProposal(_data);
    } else if (_action == ActionsConstants.SPACE_LEFT) {
      _leaveSpace(_fromSpaceId, _data);
    } else if (_action == ActionsConstants.MEMBERSHIP_REQUESTED) {
      _requestMembership(_fromSpaceId, _data);
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
  function unrestrictSpace(bytes16 _oldRestrictedSpaceId) public virtual onlyRole(DAO) {
    _unrestrictSpace(_oldRestrictedSpaceId);
  }

  /// @inheritdoc IDAOSpace
  function ping(bytes32 _action, bytes32 _subject, bytes calldata _data) public virtual onlyRole(DAO) {
    _ping(_action, _subject, _data);
  }

  /// @inheritdoc IDAOSpace
  function updateVotingSettings(VotingSettings calldata _votingSettings) public virtual onlyRole(DAO) {
    _updateVotingSettings(_votingSettings);
  }

  /// @inheritdoc ISpace
  function fetch(
    bytes32 _action,
    bytes32 _subjectInput,
    bytes calldata _data
  ) public view virtual returns (bytes32 _subjectOutput) {
    if (_action == ActionsConstants.PROPOSAL_CREATED) {
      (bytes16 _proposalId,,) = abi.decode(_data, (bytes16, VotingMode, Action[]));
      return bytes32(_proposalId);
    } else if (_action == ActionsConstants.PROPOSAL_VOTED) {
      (bytes16 _proposalId,,) = abi.decode(_data, (bytes16, uint8, VoteOption));
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
    } else if (_action == ActionsConstants.MEMBERSHIP_REQUESTED) {
      (bytes16 _proposalId,) = abi.decode(_data, (bytes16, bytes16));
      return bytes32(_proposalId);
    } else if (_action == ActionsConstants.SPACE_FAST_PATH_RESTRICTED) {
      bytes16 _spaceId = abi.decode(_data, (bytes16));
      return bytes32(_spaceId);
    } else {
      return _subjectInput;
    }
  }

  /// @inheritdoc IDAOSpace
  function canExecuteProposal(bytes16 _proposalId) public view virtual returns (bool _canExecuteProposal) {
    Proposal storage proposal_ = _getLatestProposalStorage(_proposalId);

    // Proposal does not exist
    if (proposal_.creator == bytes16(0)) return false;
    // The proposal has not been executed already
    if (proposal_.executed) return false;
    // Support threshold not reached
    if (!isSupportThresholdReached(_proposalId)) return false;
    return true;
  }

  /// @inheritdoc IDAOSpace
  function isSupportThresholdReached(bytes16 _proposalId)
    public
    view
    virtual
    returns (bool _isSupportThresholdReached)
  {
    Proposal storage proposal_ = _getLatestProposalStorage(_proposalId);
    uint256 _effectiveSupportThreshold;

    if (proposal_.parameters.votingMode == VotingMode.Slow) {
      // Slow path

      // Quorum check
      if (proposal_.tally.yes + proposal_.tally.no + proposal_.tally.abstain < proposal_.parameters.quorum) {
        return false;
      }

      _effectiveSupportThreshold =
        _computeEffectiveSupportThreshold(proposal_.parameters.universalPercentageSupportThreshold);
      DAOSpaceStorage storage $_ = _getDAOSpaceStorage();
      // Threshold percentage check to allow for early execution
      // % = influencing + non-influencing votes (yes/no/abstain/none) = total votes = total editors
      // % of yes votes > % of no + abstain + none votes
      if (proposal_.tally.yes * RATIO_BASE > _effectiveSupportThreshold * $_.totalEditors) {
        return true;
      }

      // Duration check
      if (block.timestamp <= proposal_.parameters.lastDate) return false;

      _effectiveSupportThreshold =
        _computeEffectiveSupportThreshold(proposal_.parameters.partialPercentageSupportThreshold);
      // Threshold percentage calculation
      // % = influencing votes (yes/no)
      // % of yes votes > % of no votes
      if (
        (RATIO_BASE - _effectiveSupportThreshold) * proposal_.tally.yes
          > _effectiveSupportThreshold * proposal_.tally.no
      ) return true;
    } else {
      // Fast path

      _effectiveSupportThreshold = _computeEffectiveSupportThreshold(proposal_.parameters.flatSupportThreshold);
      // Threshold flat calculation
      // # of yes votes > flat count
      if (proposal_.tally.yes > _effectiveSupportThreshold) return true;
    }
  }

  /// @inheritdoc IDAOSpace
  function votingSettings() public view returns (VotingSettings memory _votingSettings) {
    DAOSpaceStorage storage $_ = _getDAOSpaceStorage();
    _votingSettings = $_.votingSettings;
  }

  /// @inheritdoc IDAOSpace
  function totalEditors() public view returns (uint256 _totalEditors) {
    DAOSpaceStorage storage $_ = _getDAOSpaceStorage();
    _totalEditors = $_.totalEditors;
  }

  /// @inheritdoc IDAOSpace
  function actionIsFastPathValid(bytes4 _selector) public view returns (bool _isValid) {
    DAOSpaceStorage storage $_ = _getDAOSpaceStorage();
    _isValid = $_.actionIsFastPathValid[_selector];
  }

  /// @inheritdoc IDAOSpace
  function latestProposalVersion(bytes16 _proposalId) public view returns (uint8 _latestProposalVersion) {
    DAOSpaceStorage storage $_ = _getDAOSpaceStorage();
    _latestProposalVersion = $_.latestProposalVersion[_proposalId];
  }

  /// @inheritdoc IDAOSpace
  function getProposalInformation(
    bytes16 _proposalId,
    uint8 _proposalVersion
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
    DAOSpaceStorage storage $_ = _getDAOSpaceStorage();
    _executed = $_.proposals[_proposalId][_proposalVersion].executed;
    _creator = $_.proposals[_proposalId][_proposalVersion].creator;
    _parameters = $_.proposals[_proposalId][_proposalVersion].parameters;
    _tally = $_.proposals[_proposalId][_proposalVersion].tally;
    _actions = $_.proposals[_proposalId][_proposalVersion].actions;
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
    uint8 _proposalVersion,
    bytes16 _voterSpaceId
  ) public view returns (VoteOption _voteOption) {
    DAOSpaceStorage storage $_ = _getDAOSpaceStorage();
    _voteOption = $_.proposals[_proposalId][_proposalVersion].voters[_voterSpaceId];
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
    DAOSpaceStorage storage $_ = _getDAOSpaceStorage();
    _spaceRegistry = $_.spaceRegistry;
  }

  /// @inheritdoc ISemver
  function typeId() public pure virtual returns (bytes32 _type) {
    _type = keccak256(bytes(name()));
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
    DAOSpaceStorage storage $_ = _getDAOSpaceStorage();
    if (_votingSettings.partialPercentageSupportThreshold > RATIO_BASE) revert InvalidSetting();
    if (_votingSettings.universalPercentageSupportThreshold > RATIO_BASE) revert InvalidSetting();
    if (_votingSettings.flatSupportThreshold > $_.totalEditors) revert InvalidSetting();
    if (_votingSettings.quorum > $_.totalEditors) revert InvalidSetting();
    if (_votingSettings.duration < MINIMUM_VOTING_DURATION) revert InvalidSetting();

    $_.votingSettings = _votingSettings;

    // Ping the registry to emit the updated voting settings
    _ping(ActionsConstants.VOTING_SETTINGS_UPDATED, bytes32(0), abi.encode(_votingSettings));
  }

  /**
   * @notice Creates a new governance proposal
   * @param _fromSpaceId The space ID creating the proposal
   * @param _data The encoded proposal data containing the voting mode and actions
   */
  function _createProposal(bytes16 _fromSpaceId, bytes calldata _data) internal virtual {
    // Decode data to construct proposal
    (bytes16 _proposalId, VotingMode _votingMode, Action[] memory _actions) =
      abi.decode(_data, (bytes16, VotingMode, Action[]));

    DAOSpaceStorage storage $_ = _getDAOSpaceStorage();
    uint8 _latestProposalVersion = $_.latestProposalVersion[_proposalId];
    if (_latestProposalVersion != 0) revert InvalidProposalId();

    // Update proposal storage
    _checkProposalPath(_fromSpaceId, _votingMode, _actions);
    _setProposal(_fromSpaceId, _proposalId, _votingMode, _actions);
  }

  /**
   * @notice Checks the path of a new governance proposal
   * @param _fromSpaceId The space ID creating the proposal
   * @param _votingMode The voting mode (slow or fast) of the proposal
   * @param _actions The actions to be undertaken if the proposal is successful
   * @dev Fast path: members or editors can create, creator must not be restricted, single action required,
   * action selector must be valid. Slow path: members or editors can create, multiple actions allowed.
   */
  function _checkProposalPath(bytes16 _fromSpaceId, VotingMode _votingMode, Action[] memory _actions) internal virtual {
    DAOSpaceStorage storage $_ = _getDAOSpaceStorage();

    // Only members or editors can create proposals
    if (!(hasRole(MEMBER, _fromSpaceId) || hasRole(EDITOR, _fromSpaceId))) revert InvalidFromSpace();

    // Slow path has no additional checks here
    if (_votingMode == VotingMode.Fast) {
      // Fast path
      // Checks from space is allowed to use fast path
      if (hasRole(FAST_PATH_RESTRICTED, _fromSpaceId)) revert FastPathRestricted();
      // limit the actions to one call
      if (_actions.length != 1) revert OneActionForFastPath();
      // limit to only valid fast path actions
      if (!$_.actionIsFastPathValid[bytes4(_actions[0].data)]) revert InvalidAction();
      // limit the target to only this address
      if (_actions[0].to != address(this)) revert InvalidTarget();
      // limit the transfer of funds
      if (_actions[0].value != 0) revert InvalidFundsTransfer();
    }
  }

  /**
   * @notice Creates or updates a governance proposal
   * @param _fromSpaceId The space ID setting the proposal
   * @param _proposalId The proposal identifier
   * @param _votingMode The voting mode (slow or fast) of the proposal
   * @param _actions The actions to be undertaken if the proposal is successful
   */
  function _setProposal(
    bytes16 _fromSpaceId,
    bytes16 _proposalId,
    VotingMode _votingMode,
    Action[] memory _actions
  ) internal virtual {
    // Update proposal storage
    DAOSpaceStorage storage $_ = _getDAOSpaceStorage();
    uint8 _latestProposalVersion = ++$_.latestProposalVersion[_proposalId];
    Proposal storage proposal_ = _getProposalStorage(_proposalId, _latestProposalVersion);
    proposal_.creator = _fromSpaceId;
    proposal_.parameters.startDate = block.timestamp;
    proposal_.parameters.lastDate = block.timestamp + $_.votingSettings.duration;
    proposal_.parameters.votingMode = _votingMode;
    proposal_.parameters.quorum = $_.votingSettings.quorum;
    proposal_.parameters.partialPercentageSupportThreshold = $_.votingSettings.partialPercentageSupportThreshold;
    proposal_.parameters.universalPercentageSupportThreshold = $_.votingSettings.universalPercentageSupportThreshold;
    proposal_.parameters.flatSupportThreshold = $_.votingSettings.flatSupportThreshold;
    for (uint256 _i; _i < _actions.length; _i++) {
      proposal_.actions.push(_actions[_i]);
    }

    // Ping the registry to emit the proposal settings
    _ping(ActionsConstants.PROPOSAL_SETTINGS_SELECTED, bytes32(_proposalId), abi.encode(proposal_.parameters));
  }

  /**
   * @notice Votes on a proposal
   * @param _fromSpaceId The space ID casting the vote
   * @param _data The encoded vote data containing proposal ID, proposal version and vote option
   * @dev Only editors can vote. Vote replacement allowed. "No" vote on fast path escalates to slow path.
   * Fast path can execute immediately if threshold met; slow path requires voting period to end.
   */
  function _voteProposal(bytes16 _fromSpaceId, bytes calldata _data) internal virtual {
    // Decode data to construct vote
    (bytes16 _proposalId, uint8 _proposalVersion, VoteOption _voteOption) =
      abi.decode(_data, (bytes16, uint8, VoteOption));

    // Ensure _fromSpaceId can vote
    if (!_canVote(_fromSpaceId, _proposalId, _proposalVersion, _voteOption)) revert CanNotVote();

    Proposal storage proposal_ = _getProposalStorage(_proposalId, _proposalVersion);
    // Remove the previous vote
    VoteOption _state = proposal_.voters[_fromSpaceId];
    if (_state == VoteOption.Yes) {
      proposal_.tally.yes = proposal_.tally.yes - 1;
    } else if (_state == VoteOption.No) {
      proposal_.tally.no = proposal_.tally.no - 1;
    } else if (_state == VoteOption.Abstain) {
      proposal_.tally.abstain = proposal_.tally.abstain - 1;
    }

    // Store the updated/new vote for the voter
    proposal_.voters[_fromSpaceId] = _voteOption;

    // Add the new vote
    if (_voteOption == VoteOption.Yes) {
      proposal_.tally.yes = proposal_.tally.yes + 1;

      // Immediate execution if possible
      if (canExecuteProposal(_proposalId)) _executeProposal(_proposalId);
    } else if (_voteOption == VoteOption.No) {
      proposal_.tally.no = proposal_.tally.no + 1;

      // Fast path to slow path if rejection occurs
      if (proposal_.parameters.votingMode == VotingMode.Fast) {
        DAOSpaceStorage storage $_ = _getDAOSpaceStorage();
        // Update voting mode
        proposal_.parameters.votingMode = VotingMode.Slow;
        // Update quorum
        proposal_.parameters.quorum = $_.votingSettings.quorum;
        // Update thresholds
        proposal_.parameters.partialPercentageSupportThreshold = $_.votingSettings.partialPercentageSupportThreshold;
        proposal_.parameters.universalPercentageSupportThreshold = $_.votingSettings.universalPercentageSupportThreshold;
        proposal_.parameters.flatSupportThreshold = $_.votingSettings.flatSupportThreshold;
        // Reset duration and block times
        proposal_.parameters.startDate = block.timestamp;
        proposal_.parameters.lastDate = block.timestamp + $_.votingSettings.duration;

        // Ping the registry to emit the updated proposal settings
        _ping(ActionsConstants.PROPOSAL_SETTINGS_SELECTED, bytes32(_proposalId), abi.encode(proposal_.parameters));
      }
    } else {
      proposal_.tally.abstain = proposal_.tally.abstain + 1;
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
    _checkProposalPath(_fromSpaceId, _votingMode, _actions);
    _setProposal(_fromSpaceId, _proposalId, _votingMode, _actions);
  }

  /**
   * @notice Decodes input data and then executes a proposal after it has passed
   * @param _data The encoded execution data containing the proposal ID
   */
  function _executeProposal(bytes calldata _data) internal virtual {
    // Decode data to execute proposal
    bytes16 _proposalId = abi.decode(_data, (bytes16));

    // Anyone can call
    // Check if proposal can be settled
    if (!canExecuteProposal(_proposalId)) revert CanNotExecute();

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
    Action[] memory _actions = proposal_.actions;
    uint256 _actionsLength = _actions.length;
    Action memory _action;
    for (uint256 _i; _i < _actionsLength; _i++) {
      _action = _actions[_i];
      (bool _success,) = (_action.to).call{value: _action.value}(_action.data);
      if (!_success) revert ActionReverted();
    }
  }

  /**
   * @notice Allows a member or editor to leave the space
   * @param _fromSpaceId The space ID leaving
   * @param _data The encoded role data used to determine which role a user wants to leave
   */
  function _leaveSpace(bytes16 _fromSpaceId, bytes calldata _data) internal virtual {
    // Decode data to leave space
    bytes32 _role = abi.decode(_data, (bytes32));

    if (_role == MEMBER && hasRole(MEMBER, _fromSpaceId)) {
      _removeMember(_fromSpaceId);
    } else if (_role == EDITOR && hasRole(EDITOR, _fromSpaceId)) {
      _removeEditor(_fromSpaceId);
    } else {
      revert InvalidFromSpace();
    }
  }

  /**
   * @notice Creates a new fast path proposal for a space to become a member
   * @param _fromSpaceId The space ID creating the proposal
   * @param _data The encoded proposal data containing the space ID requesting to become a member
   */
  function _requestMembership(bytes16 _fromSpaceId, bytes calldata _data) internal virtual {
    // Decode data to construct proposal
    (bytes16 _proposalId, bytes16 _newMemberSpaceId) = abi.decode(_data, (bytes16, bytes16));

    DAOSpaceStorage storage $_ = _getDAOSpaceStorage();
    // Ensure proposal ID is valid
    uint8 _latestProposalVersion = $_.latestProposalVersion[_proposalId];
    if (_latestProposalVersion != 0) revert InvalidProposalId();
    // Checks from space is allowed to use fast path
    if (hasRole(FAST_PATH_RESTRICTED, _fromSpaceId)) revert FastPathRestricted();
    // Check to handle the already-member case
    if (hasRole(MEMBER, _newMemberSpaceId)) revert InvalidSpaceIdForRole();

    VotingMode _votingMode = VotingMode.Fast;
    Action[] memory _actions = new Action[](1);
    _actions[0] = Action({to: address(this), value: 0, data: abi.encodeCall(IDAOSpace.addMember, (_newMemberSpaceId))});

    // Ping the registry to emit the proposal creation
    _ping(ActionsConstants.PROPOSAL_CREATED, bytes32(_proposalId), abi.encode(_proposalId, _votingMode, _actions));

    // Update proposal storage
    _setProposal(_fromSpaceId, _proposalId, _votingMode, _actions);
  }

  /**
   * @notice Restricts a space from creating fast path proposals
   * @param _fromSpaceId The space ID of the editor performing the restriction
   * @param _data The encoded data containing the space ID to flag
   * @dev Only editors can restrict others.
   */
  function _restrictSpace(bytes16 _fromSpaceId, bytes calldata _data) internal virtual {
    // Decode data to restrict space
    bytes16 _newRestrictedSpaceId = abi.decode(_data, (bytes16));

    if (!hasRole(EDITOR, _fromSpaceId)) revert InvalidFromSpace();
    if (hasRole(FAST_PATH_RESTRICTED, _newRestrictedSpaceId)) revert InvalidSpaceIdForRole();

    _grantRole(FAST_PATH_RESTRICTED, _newRestrictedSpaceId);
  }

  /**
   * @notice Unrestricts a space allowing them to create fast path proposals
   * @param _oldRestrictedSpaceId The space ID to be unrestricted
   */
  function _unrestrictSpace(bytes16 _oldRestrictedSpaceId) internal virtual {
    if (!hasRole(FAST_PATH_RESTRICTED, _oldRestrictedSpaceId)) revert InvalidSpaceIdForRole();

    _revokeRole(FAST_PATH_RESTRICTED, _oldRestrictedSpaceId);

    _ping(ActionsConstants.SPACE_FAST_PATH_UNRESTRICTED, bytes32(_oldRestrictedSpaceId), '');
  }

  /**
   * @notice Internal function to add an editor
   * @param _newEditorSpaceId The space ID of the new editor
   */
  function _addEditor(bytes16 _newEditorSpaceId) internal virtual {
    if (hasRole(EDITOR, _newEditorSpaceId)) revert InvalidSpaceIdForRole();

    _grantRole(EDITOR, _newEditorSpaceId);
    DAOSpaceStorage storage $_ = _getDAOSpaceStorage();
    $_.totalEditors++;

    _ping(ActionsConstants.EDITOR_ADDED, bytes32(_newEditorSpaceId), '');
  }

  /**
   * @notice Internal function to remove an editor
   * @param _oldEditorSpaceId The space ID of the editor to remove
   * @dev If removal fails due to invalid settings, first update the settings to lower the quorum and/or the
   * flatSupportThreshold. Both the settings update and editor removal operations may be bundled into one proposal
   * for convenience.
   */
  function _removeEditor(bytes16 _oldEditorSpaceId) internal virtual {
    if (!hasRole(EDITOR, _oldEditorSpaceId)) revert InvalidSpaceIdForRole();
    // May not remove editor if doing so would prevent proposals from being executed
    DAOSpaceStorage storage $_ = _getDAOSpaceStorage();
    if ($_.votingSettings.quorum == $_.totalEditors) revert InvalidSetting();
    if ($_.votingSettings.flatSupportThreshold == $_.totalEditors) revert InvalidSetting();

    _revokeRole(EDITOR, _oldEditorSpaceId);
    $_.totalEditors--;

    _ping(ActionsConstants.EDITOR_REMOVED, bytes32(_oldEditorSpaceId), '');
  }

  /**
   * @notice Internal function to add a member
   * @param _newMemberSpaceId The space ID of the new member
   * @dev When disableFastPathAccessForNewMembers is true, the new member is restricted from the fast path.
   */
  function _addMember(bytes16 _newMemberSpaceId) internal virtual {
    if (hasRole(MEMBER, _newMemberSpaceId)) revert InvalidSpaceIdForRole();

    DAOSpaceStorage storage $_ = _getDAOSpaceStorage();
    if ($_.votingSettings.disableFastPathAccessForNewMembers && !hasRole(EDITOR, _newMemberSpaceId)) {
      _grantRole(FAST_PATH_RESTRICTED, _newMemberSpaceId);
    }
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
   * @param _subject A subject identifier
   * @param _data Some extra arbitrary data that may hold additional information
   * @dev _from and _to are always the DAO's space ID
   */
  function _ping(bytes32 _action, bytes32 _subject, bytes memory _data) internal virtual {
    DAOSpaceStorage storage $_ = _getDAOSpaceStorage();
    bytes16 _daoSpaceId = $_.spaceRegistry.addressToSpaceId(address(this));

    $_.spaceRegistry.enter(_daoSpaceId, _daoSpaceId, _action, _subject, _data, '');
  }

  /**
   * @notice Checks if a space can vote on a proposal
   * @param _fromSpaceId The space ID to check
   * @param _proposalId The ID of the proposal
   * @param _proposalVersion The version of the proposal
   * @param _voteOption The vote option being cast
   * @return __canVote True if the space can vote, false otherwise
   * @dev Returns false if proposal doesn't exist, voting ended, vote option is None, or space
   * wasn't an editor at snapshot block. Vote replacement allowed.
   */
  function _canVote(
    bytes16 _fromSpaceId,
    bytes16 _proposalId,
    uint8 _proposalVersion,
    VoteOption _voteOption
  ) internal view virtual returns (bool __canVote) {
    DAOSpaceStorage storage $_ = _getDAOSpaceStorage();
    uint8 _latestProposalVersion = $_.latestProposalVersion[_proposalId];
    Proposal storage proposal_ = _getProposalStorage(_proposalId, _latestProposalVersion);

    // Proposal does not exist
    if (_latestProposalVersion == 0) return false;
    // Vote is not for the current proposal version
    if (_proposalVersion != _latestProposalVersion) return false;
    // The proposal voting period has already ended
    if (block.timestamp > proposal_.parameters.lastDate) return false;
    // The proposal has already been executed
    if (proposal_.executed) return false;
    // The voter votes `None` which is not allowed
    if (_voteOption == VoteOption.None) return false;
    // The voter has no voting power
    if (!hasRole(EDITOR, _fromSpaceId)) return false;
    return true;
  }

  /**
   * @notice Returns the storage of a proposal
   * @param _proposalId The proposal ID
   * @param _proposalVersion The proposal version
   * @return _proposal The storage of a proposal
   */
  function _getProposalStorage(
    bytes16 _proposalId,
    uint8 _proposalVersion
  ) internal view returns (Proposal storage _proposal) {
    DAOSpaceStorage storage $_ = _getDAOSpaceStorage();
    _proposal = $_.proposals[_proposalId][_proposalVersion];
  }

  /**
   * @notice Returns the latest storage of a proposal
   * @param _proposalId The proposal ID
   * @return _proposal The storage of a proposal
   */
  function _getLatestProposalStorage(bytes16 _proposalId) internal view returns (Proposal storage _proposal) {
    DAOSpaceStorage storage $_ = _getDAOSpaceStorage();
    uint8 _latestProposalVersion = $_.latestProposalVersion[_proposalId];
    _proposal = $_.proposals[_proposalId][_latestProposalVersion];
  }

  /**
   * @notice Returns the effective support threshold to be used in threshold calculation
   * @param _supportThreshold The support threshold
   * @return _effectiveSupportThreshold The effective support threshold
   */
  function _computeEffectiveSupportThreshold(uint256 _supportThreshold)
    internal
    pure
    virtual
    returns (uint256 _effectiveSupportThreshold)
  {
    _effectiveSupportThreshold = (_supportThreshold == 0) ? 0 : _supportThreshold - 1;
  }

  /**
   * @notice Returns the DAO space contract storage
   * @return $_ The storage of the DAO space contract
   * @custom:storage-location erc7201:geo.storage.DAOSpace
   */
  function _getDAOSpaceStorage() internal pure returns (DAOSpaceStorage storage $_) {
    assembly {
      $_.slot := _DAO_SPACE_STORAGE_LOCATION
    }
  }
}
