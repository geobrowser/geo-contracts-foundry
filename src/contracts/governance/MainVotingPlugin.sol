// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

import {IDAO} from '@aragon/osx/core/plugin/PluginUUPSUpgradeable.sol';
import {SafeCastUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol';

import {IMemberAccessPlugin, MemberAccessPlugin} from 'contracts/governance/MemberAccessPlugin.sol';
import {Addresslist} from 'contracts/governance/base/Addresslist.sol';
import {MajorityVotingBase} from 'contracts/governance/base/MajorityVotingBase.sol';
import {SpacePlugin} from 'contracts/space/SpacePlugin.sol';
import {IEditors} from 'interfaces/base/IEditors.sol';
import {IMembers} from 'interfaces/base/IMembers.sol';
import {IMainVotingPlugin} from 'interfaces/governance/IMainVotingPlugin.sol';
import {IMajorityVoting} from 'interfaces/governance/base/IMajorityVoting.sol';

/// @title MainVotingPlugin (Address list)
/// @notice The majority voting implementation using a list of editor addresses.
/// @dev This contract inherits from `MajorityVotingBase` and implements the `IMajorityVoting` interface.
contract MainVotingPlugin is Addresslist, MajorityVotingBase, IMainVotingPlugin {
  using SafeCastUpgradeable for uint256;

  /// @inheritdoc IMainVotingPlugin
  bytes32 public constant UPDATE_ADDRESSES_PERMISSION_ID = keccak256('UPDATE_ADDRESSES_PERMISSION');

  /// @notice Who created each proposal
  mapping(uint256 => address) internal proposalCreators;

  /// @notice Whether an address is considered as a space member (not editor)
  mapping(address => bool) internal members;

  /// @inheritdoc IMainVotingPlugin
  MemberAccessPlugin public memberAccessPlugin;

  /// @notice Checks and reverts if the caller is not a member
  modifier onlyMembers() {
    if (!isMember(msg.sender)) {
      revert NotAMember(msg.sender);
    }
    _;
  }

  /// @inheritdoc IMainVotingPlugin
  function initialize(
    IDAO _dao,
    VotingSettings calldata _votingSettings,
    address[] calldata _initialEditors,
    address[] calldata _initialMembers,
    MemberAccessPlugin _memberAccessPlugin
  ) external initializer {
    __MajorityVotingBase_init(_dao, _votingSettings);

    _addAddresses(_initialEditors);
    emit EditorsAdded(address(_dao), _initialEditors);

    for (uint256 _i; _i < _initialMembers.length; ++_i) {
      members[_initialMembers[_i]] = true;
    }
    emit MembersAdded(address(_dao), _initialMembers);

    if (!_memberAccessPlugin.supportsInterface(type(IMemberAccessPlugin).interfaceId)) {
      revert InvalidInterface(address(_memberAccessPlugin));
    }
    memberAccessPlugin = _memberAccessPlugin;
  }

  /// @notice Checks if this or the parent contract supports an interface by its ID.
  /// @param _interfaceId The ID of the interface.
  /// @return Returns `true` if the interface is supported.
  function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
    return _interfaceId == type(IMainVotingPlugin).interfaceId || _interfaceId == type(Addresslist).interfaceId
      || _interfaceId == type(MajorityVotingBase).interfaceId || _interfaceId == type(IMembers).interfaceId
      || _interfaceId == type(IEditors).interfaceId || super.supportsInterface(_interfaceId);
  }

  /// @inheritdoc IEditors
  function isEditor(address _account) public view returns (bool) {
    return isListed(_account);
  }

  /// @inheritdoc IMembers
  function isMember(address _account) public view returns (bool) {
    return members[_account] || isEditor(_account);
  }

  /// @inheritdoc MajorityVotingBase
  function totalVotingPower(uint256 _blockNumber)
    public
    view
    override(IMajorityVoting, MajorityVotingBase)
    returns (uint256)
  {
    return addresslistLengthAtBlock(_blockNumber);
  }

  /// @notice Determines whether at least one editor besides the creator has approved.
  /// @param _proposalId The ID of the proposal to check.
  function isMinParticipationReached(uint256 _proposalId)
    public
    view
    override(IMajorityVoting, MajorityVotingBase)
    returns (bool)
  {
    Proposal storage proposal_ = proposals[_proposalId];

    // Zero votes?
    if (proposal_.tally.yes == 0 && proposal_.tally.no == 0 && proposal_.tally.abstain == 0) {
      return false;
    }
    // Do we have only one potential voter?
    else if (addresslistLengthAtBlock(proposal_.parameters.snapshotBlock) == 1) {
      // If so, we don't want to brick the DAO
      return true;
    }

    // Did other voters participate, other than the creator?
    return proposal_.didNonProposersVote;
  }

  /// @inheritdoc IMainVotingPlugin
  function addEditor(address _account) external auth(UPDATE_ADDRESSES_PERMISSION_ID) {
    if (isEditor(_account)) return;

    address[] memory _editors = new address[](1);
    _editors[0] = _account;

    _addAddresses(_editors);
    emit EditorAdded(address(dao()), _account);
  }

  /// @inheritdoc IMainVotingPlugin
  function removeEditor(address _account) external auth(UPDATE_ADDRESSES_PERMISSION_ID) {
    if (!isEditor(_account)) return;
    else if (addresslistLength() <= 1) revert NoEditorsLeft();

    address[] memory _editors = new address[](1);
    _editors[0] = _account;

    _removeAddresses(_editors);
    emit EditorRemoved(address(dao()), _account);
  }

  /// @inheritdoc IMainVotingPlugin
  function addMember(address _account) external auth(UPDATE_ADDRESSES_PERMISSION_ID) {
    if (members[_account]) return;

    members[_account] = true;
    emit MemberAdded(address(dao()), _account);
  }

  /// @inheritdoc IMainVotingPlugin
  function removeMember(address _account) external auth(UPDATE_ADDRESSES_PERMISSION_ID) {
    if (!members[_account]) return;

    members[_account] = false;
    emit MemberRemoved(address(dao()), _account);
  }

  /// @inheritdoc IMainVotingPlugin
  function leaveSpace() external {
    if (isEditor(msg.sender)) {
      // Not checking whether msg.sender is the last editor. It is acceptable
      // that a DAO/Space remains in read-only mode, as it can always be forked.

      address[] memory _editors = new address[](1);
      _editors[0] = msg.sender;

      _removeAddresses(_editors);
      emit EditorLeft(address(dao()), msg.sender);
    }

    if (members[msg.sender]) {
      members[msg.sender] = false;
      emit MemberLeft(address(dao()), msg.sender);
    }
  }

  /// @inheritdoc IMainVotingPlugin
  function leaveSpaceAsEditor() external {
    if (!isEditor(msg.sender)) {
      revert NotAnEditor();
    }

    // Not checking whether msg.sender is the last editor. It is acceptable
    // that a DAO/Space remains in read-only mode, as it can always be forked.

    address[] memory _editors = new address[](1);
    _editors[0] = msg.sender;

    _removeAddresses(_editors);
    emit EditorLeft(address(dao()), msg.sender);
  }

  /// @inheritdoc IMajorityVoting
  function createProposal(
    bytes calldata _metadataContentUri,
    IDAO.Action[] calldata _actions,
    uint256 _allowFailureMap,
    VoteOption _voteOption,
    bool _tryEarlyExecution
  ) external override onlyMembers returns (uint256 proposalId) {
    uint64 snapshotBlock;
    unchecked {
      snapshotBlock = block.number.toUint64() - 1; // The snapshot block must be mined already to protect the transaction against backrunning transactions causing census changes.
    }
    uint64 _startDate = block.timestamp.toUint64();

    proposalId = _createProposal({
      _creator: msg.sender,
      _metadata: _metadataContentUri,
      _startDate: _startDate,
      _endDate: _startDate + duration(),
      _actions: _actions,
      _allowFailureMap: _allowFailureMap
    });

    // Store proposal related information
    Proposal storage proposal_ = proposals[proposalId];

    proposal_.parameters.startDate = _startDate;
    proposal_.parameters.endDate = _startDate + duration();
    proposal_.parameters.snapshotBlock = snapshotBlock;
    proposal_.parameters.votingMode = votingMode();
    proposal_.parameters.thresholdMode = thresholdMode();
    proposal_.parameters.supportThreshold = supportThreshold();

    proposalCreators[proposalId] = msg.sender;

    // Reduce costs
    if (_allowFailureMap != 0) {
      proposal_.allowFailureMap = _allowFailureMap;
    }

    for (uint256 i; i < _actions.length;) {
      proposal_.actions.push(_actions[i]);
      unchecked {
        ++i;
      }
    }

    if (_voteOption != VoteOption.None) {
      vote(proposalId, _voteOption, _tryEarlyExecution);
    }
  }

  /// @inheritdoc IMainVotingPlugin
  function proposeEdits(
    bytes calldata _metadataContentUri,
    string memory _editsContentUri,
    bytes memory _editsMetadata,
    address _spacePlugin
  ) public onlyMembers returns (uint256 proposalId) {
    if (_spacePlugin == address(0)) {
      revert EmptyContent();
    }

    proposalId = _proposeWrappedAction(
      _metadataContentUri, _spacePlugin, abi.encodeCall(SpacePlugin.publishEdits, (_editsContentUri, _editsMetadata))
    );

    Proposal storage proposal_ = proposals[proposalId];

    emit PublishEditsProposalCreated(
      proposalId,
      proposalCreators[proposalId],
      proposal_.parameters.startDate,
      proposal_.parameters.endDate,
      _editsContentUri,
      address(dao())
    );
  }

  /// @inheritdoc IMainVotingPlugin
  function proposeFlagContent(
    bytes calldata _metadataContentUri,
    string memory _flagContentUri,
    address _spacePlugin
  ) public onlyMembers returns (uint256 proposalId) {
    if (_spacePlugin == address(0)) {
      revert EmptyContent();
    }

    proposalId = _proposeWrappedAction(
      _metadataContentUri, _spacePlugin, abi.encodeCall(SpacePlugin.flagContent, (_flagContentUri))
    );

    Proposal storage proposal_ = proposals[proposalId];

    emit FlagContentProposalCreated(
      proposalId,
      proposalCreators[proposalId],
      proposal_.parameters.startDate,
      proposal_.parameters.endDate,
      _flagContentUri,
      address(dao())
    );
  }

  /// @inheritdoc IMainVotingPlugin
  function proposeAcceptSubspace(
    bytes calldata _metadataContentUri,
    IDAO _subspaceDao,
    address _spacePlugin
  ) public onlyMembers returns (uint256 proposalId) {
    if (address(_subspaceDao) == address(0) || _spacePlugin == address(0)) {
      revert EmptyContent();
    }

    proposalId = _proposeWrappedAction(
      _metadataContentUri, _spacePlugin, abi.encodeCall(SpacePlugin.acceptSubspace, (address(_subspaceDao)))
    );

    Proposal storage proposal_ = proposals[proposalId];

    emit AcceptSubspaceProposalCreated(
      proposalId,
      proposalCreators[proposalId],
      proposal_.parameters.startDate,
      proposal_.parameters.endDate,
      _metadataContentUri,
      address(_subspaceDao),
      address(dao())
    );
  }

  /// @inheritdoc IMainVotingPlugin
  function proposeRemoveSubspace(
    bytes calldata _metadataContentUri,
    IDAO _subspaceDao,
    address _spacePlugin
  ) public onlyMembers returns (uint256 proposalId) {
    if (address(_subspaceDao) == address(0) || _spacePlugin == address(0)) {
      revert EmptyContent();
    }

    proposalId = _proposeWrappedAction(
      _metadataContentUri, _spacePlugin, abi.encodeCall(SpacePlugin.removeSubspace, (address(_subspaceDao)))
    );

    Proposal storage proposal_ = proposals[proposalId];

    emit RemoveSubspaceProposalCreated(
      proposalId,
      proposalCreators[proposalId],
      proposal_.parameters.startDate,
      proposal_.parameters.endDate,
      _metadataContentUri,
      address(_subspaceDao),
      address(dao())
    );
  }

  /// @inheritdoc IMainVotingPlugin
  function proposeAddMember(
    bytes calldata _metadataContentUri,
    address _proposedMember
  ) public returns (uint256 proposalId) {
    if (isMember(_proposedMember)) {
      revert AlreadyAMember(_proposedMember);
    }

    /// @dev Creating the actual proposal on a separate plugin because the approval rules differ.
    /// @dev Keeping all wrappers on the MainVoting plugin, even if one type of approvals are handled on the MemberAccess plugin.
    return memberAccessPlugin.proposeAddMember(_metadataContentUri, _proposedMember, msg.sender);
  }

  /// @inheritdoc IMainVotingPlugin
  function proposeRemoveMember(
    bytes calldata _metadataContentUri,
    address _member
  ) public returns (uint256 proposalId) {
    if (!isEditor(msg.sender)) {
      revert Unauthorized();
    } else if (!isMember(_member)) {
      revert AlreadyNotAMember(_member);
    }

    proposalId = _proposeWrappedAction(
      _metadataContentUri, address(this), abi.encodeCall(MainVotingPlugin.removeMember, (_member))
    );

    Proposal storage proposal_ = proposals[proposalId];

    emit RemoveMemberProposalCreated(
      proposalId,
      proposalCreators[proposalId],
      proposal_.parameters.startDate,
      proposal_.parameters.endDate,
      _metadataContentUri,
      _member,
      address(dao())
    );
  }

  /// @inheritdoc IMainVotingPlugin
  function proposeAddEditor(
    bytes calldata _metadataContentUri,
    address _proposedEditor
  ) public onlyMembers returns (uint256 proposalId) {
    if (isEditor(_proposedEditor)) {
      revert AlreadyAnEditor(_proposedEditor);
    }

    proposalId = _proposeWrappedAction(
      _metadataContentUri, address(this), abi.encodeCall(MainVotingPlugin.addEditor, (_proposedEditor))
    );

    Proposal storage proposal_ = proposals[proposalId];

    emit AddEditorProposalCreated(
      proposalId,
      proposalCreators[proposalId],
      proposal_.parameters.startDate,
      proposal_.parameters.endDate,
      _metadataContentUri,
      _proposedEditor,
      address(dao())
    );
  }

  /// @inheritdoc IMainVotingPlugin
  function proposeRemoveEditor(
    bytes calldata _metadataContentUri,
    address _editor
  ) public onlyMembers returns (uint256 proposalId) {
    if (!isEditor(_editor)) {
      revert AlreadyNotAnEditor(_editor);
    }

    proposalId = _proposeWrappedAction(
      _metadataContentUri, address(this), abi.encodeCall(MainVotingPlugin.removeEditor, (_editor))
    );

    Proposal storage proposal_ = proposals[proposalId];

    emit RemoveEditorProposalCreated(
      proposalId,
      proposalCreators[proposalId],
      proposal_.parameters.startDate,
      proposal_.parameters.endDate,
      _metadataContentUri,
      _editor,
      address(dao())
    );
  }

  /// @inheritdoc IMainVotingPlugin
  function cancelProposal(uint256 _proposalId) external {
    if (proposalCreators[_proposalId] != msg.sender) {
      revert OnlyCreatorCanCancel();
    }
    Proposal storage proposal_ = proposals[_proposalId];
    if (!_isProposalOpen(proposal_)) {
      revert ProposalIsNotOpen();
    }

    // Make it end now
    proposal_.parameters.endDate = block.timestamp.toUint64();
    emit ProposalCanceled(_proposalId);
  }

  /// @notice Creates a proposal with the given calldata as the only action.
  /// @param _metadataContentUri The IPFS URI of the metadata.
  /// @param _to The contract to call with the action.
  /// @param _data The calldata to eventually invoke.
  /// @return proposalId The ID of the created proposal.
  function _proposeWrappedAction(
    bytes memory _metadataContentUri,
    address _to,
    bytes memory _data
  ) internal returns (uint256 proposalId) {
    uint64 snapshotBlock;
    unchecked {
      snapshotBlock = block.number.toUint64() - 1; // The snapshot block must be mined already to protect the transaction against backrunning transactions causing census changes.
    }
    uint64 _startDate = block.timestamp.toUint64();

    proposalId = _createProposalId();

    // Store proposal related information
    Proposal storage proposal_ = proposals[proposalId];

    proposal_.parameters.startDate = _startDate;
    proposal_.parameters.endDate = _startDate + duration();
    proposal_.parameters.snapshotBlock = snapshotBlock;
    proposal_.parameters.votingMode = votingMode();
    proposal_.parameters.thresholdMode = thresholdMode();
    proposal_.parameters.supportThreshold = supportThreshold();
    proposal_.actions.push(IDAO.Action({to: _to, value: 0, data: _data}));

    proposalCreators[proposalId] = msg.sender;

    emit ProposalCreated({
      proposalId: proposalId,
      creator: msg.sender,
      metadata: _metadataContentUri,
      startDate: _startDate,
      endDate: proposal_.parameters.endDate,
      actions: proposal_.actions,
      allowFailureMap: 0
    });

    if (isEditor(msg.sender)) {
      // We assume that the proposer approves (if an editor)
      vote(proposalId, VoteOption.Yes, true);
    }
  }

  /// @inheritdoc MajorityVotingBase
  function _vote(
    uint256 _proposalId,
    VoteOption _voteOption,
    address _voter,
    bool _tryEarlyExecution
  ) internal override {
    Proposal storage proposal_ = proposals[_proposalId];

    VoteOption state = proposal_.voters[_voter];

    // Remove the previous vote.
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

    proposal_.voters[_voter] = _voteOption;

    emit VoteCast({proposalId: _proposalId, voter: _voter, voteOption: _voteOption, votingPower: 1});

    if (proposalCreators[_proposalId] != msg.sender && !proposal_.didNonProposersVote) {
      proposal_.didNonProposersVote = true;
    }

    if (_tryEarlyExecution && _canExecute(_proposalId)) {
      _execute(_proposalId);
    }
  }

  /// @inheritdoc MajorityVotingBase
  function _canVote(
    uint256 _proposalId,
    address _account,
    VoteOption _voteOption
  ) internal view override returns (bool) {
    Proposal storage proposal_ = proposals[_proposalId];

    // The proposal vote hasn't started or has already ended.
    if (!_isProposalOpen(proposal_)) {
      return false;
    }

    // The voter votes `None` which is not allowed.
    if (_voteOption == VoteOption.None) {
      return false;
    }

    // The voter has no voting power.
    if (!isListedAtBlock(_account, proposal_.parameters.snapshotBlock)) {
      return false;
    }

    // The voter has already voted but vote replacement is not allowed.
    if (proposal_.voters[_account] != VoteOption.None && proposal_.parameters.votingMode != VotingMode.VoteReplacement)
    {
      return false;
    }

    return true;
  }

  /// @dev This empty reserved space is put in place to allow future versions to add new
  /// variables without shifting down storage in the inheritance chain.
  /// https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
  uint256[47] private __gap;
}
