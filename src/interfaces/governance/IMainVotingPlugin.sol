// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

import {IDAO} from '@aragon/osx/core/plugin/PluginUUPSUpgradeable.sol';

import {MemberAccessPlugin} from 'contracts/governance/MemberAccessPlugin.sol';
import {IEditors} from 'interfaces/base/IEditors.sol';
import {IMembers} from 'interfaces/base/IMembers.sol';
import {IAddresslist} from 'interfaces/governance/base/IAddresslist.sol';
import {IMajorityVoting} from 'interfaces/governance/base/IMajorityVoting.sol';

/// @title IMainVotingPlugin (Address list)
/// @author Aragon - 2023
/// @notice The majority voting implementation using a list of editor addresses.
/// @dev This interface inherits from `IMajorityVoting` interface.
interface IMainVotingPlugin is IAddresslist, IMajorityVoting, IEditors, IMembers {
  event PublishEditsProposalCreated(
    uint256 indexed proposalId,
    address indexed creator,
    uint64 startDate,
    uint64 endDate,
    string editsContentUri,
    address dao
  );

  /// @notice Emitted when a new flag content proposal is created.
  /// @param proposalId Unique identifier of the proposal.
  /// @param creator Address of the user that created the proposal.
  /// @param startDate The timestamp when the proposal becomes active.
  /// @param endDate The timestamp when the proposal ends.
  /// @param flagContentUri URI pointing to the proposal's content that will be flagged.
  /// @param dao Address of the DAO associated with the proposal.
  event FlagContentProposalCreated(
    uint256 indexed proposalId,
    address indexed creator,
    uint64 startDate,
    uint64 endDate,
    string flagContentUri,
    address dao
  );

  event RemoveMemberProposalCreated(
    uint256 indexed proposalId,
    address indexed creator,
    uint64 startDate,
    uint64 endDate,
    bytes metadata,
    address indexed member,
    address dao
  );

  event AddEditorProposalCreated(
    uint256 indexed proposalId,
    address indexed creator,
    uint64 startDate,
    uint64 endDate,
    bytes metadata,
    address indexed editor,
    address dao
  );

  event RemoveEditorProposalCreated(
    uint256 indexed proposalId,
    address indexed creator,
    uint64 startDate,
    uint64 endDate,
    bytes metadata,
    address indexed editor,
    address dao
  );

  event AcceptSubspaceProposalCreated(
    uint256 indexed proposalId,
    address indexed creator,
    uint64 startDate,
    uint64 endDate,
    bytes metadata,
    address indexed subspace,
    address dao
  );

  event RemoveSubspaceProposalCreated(
    uint256 indexed proposalId,
    address indexed creator,
    uint64 startDate,
    uint64 endDate,
    bytes metadata,
    address indexed subspace,
    address dao
  );

  /// @notice Emitted when the creator cancels a proposal
  event ProposalCanceled(uint256 proposalId);

  /// @notice Raised when more than one editor is attempted to be added or removed
  error OnlyOneEditorPerCall(uint256 length);

  /// @notice Raised when attempting to remove the last editor
  error NoEditorsLeft();

  /// @notice Raised when a non-editor attempts to leave a space
  error NotAnEditor();

  /// @notice Raised when a wallet who is not an editor or a member attempts to do something
  error NotAMember(address caller);

  /// @notice Raised when someone who didn't create a proposal attempts to cancel it
  error OnlyCreatorCanCancel();

  /// @notice Raised when attempting to cancel a proposal that already ended
  error ProposalIsNotOpen();

  /// @notice Raised when a content proposal is called with empty data
  error EmptyContent();

  /// @notice Thrown when the given contract doesn't support a required interface.
  error InvalidInterface(address);

  /// @notice Raised when a non-editor attempts to call a restricted function.
  error Unauthorized();

  /// @notice Thrown when attempting propose membership for an existing member.
  error AlreadyAMember(address _member);

  /// @notice Thrown when attempting propose removing membership for a non-member.
  error AlreadyNotAMember(address _member);

  /// @notice Thrown when attempting propose removing membership for a non-member.
  error AlreadyAnEditor(address _editor);

  /// @notice Thrown when attempting propose removing someone who already isn't an editor.
  error AlreadyNotAnEditor(address _editor);

  /// @notice The ID of the permission required to call the `addAddresses` and `removeAddresses` functions.
  function UPDATE_ADDRESSES_PERMISSION_ID() external view returns (bytes32);

  /// @notice The address of the plugin where new memberships are approved, using a different set of rules.
  function memberAccessPlugin() external view returns (MemberAccessPlugin);

  /// @notice Initializes the component.
  /// @dev This method is required to support [ERC-1822](https://eips.ethereum.org/EIPS/eip-1822).
  /// @param _dao The IDAO interface of the associated DAO.
  /// @param _votingSettings The voting settings.
  /// @param _initialEditors The initial editors.
  /// @param _initialMembers The initial members.
  /// @param _memberAccessPlugin The member access plugin.
  function initialize(
    IDAO _dao,
    VotingSettings calldata _votingSettings,
    address[] calldata _initialEditors,
    address[] calldata _initialMembers,
    MemberAccessPlugin _memberAccessPlugin
  ) external;

  /// @notice Returns whether the given address is currently listed as an editor
  function isEditor(address _account) external view returns (bool);

  /// @notice Returns whether the given address holds membership/editor permission on the main voting plugin
  function isMember(address _account) external view returns (bool);

  /// @notice Adds new editors to the address list.
  /// @param _account The address of the new editor.
  /// @dev This function is used during the plugin initialization.
  function addEditor(address _account) external;

  /// @notice Removes existing editors from the address list.
  /// @param _account The addresses of the editors to be removed. NOTE: Only one editor can be removed at a time.
  function removeEditor(address _account) external;

  /// @notice Defines the given address as a new space member that can create proposals.
  /// @param _account The address of the space member to be added.
  function addMember(address _account) external;

  /// @notice Removes the given address as a proposal creator.
  /// @param _account The address of the space member to be removed.
  function removeMember(address _account) external;

  /// @notice Removes msg.sender from the list of editors and members, whichever is applicable. If the last editor leaves the space, the space will become read-only.
  function leaveSpace() external;

  /// @notice Removes msg.sender from the list of editors. If the last editor leaves the space, the space will become read-only.
  function leaveSpaceAsEditor() external;

  /// @notice Creates and executes a proposal that makes the DAO emit new content on the given space.
  /// @param _metadataContentUri The metadata of the proposal.
  /// @param _editsContentUri The URI of the IPFS content to publish.
  /// @param _editsMetadata The metadata of the edits to publish.
  /// @param _spacePlugin The address of the space plugin where changes will be executed.
  /// @return proposalId The ID of the created proposal.
  function proposeEdits(
    bytes calldata _metadataContentUri,
    string memory _editsContentUri,
    bytes memory _editsMetadata,
    address _spacePlugin
  ) external returns (uint256 proposalId);

  /// @notice Creates and executes a proposal that makes the DAO emit flag content on the given space.
  /// @param _metadataContentUri The metadata of the proposal.
  /// @param _flagContentUri The URI of the IPFS content to flag.
  /// @param _spacePlugin The address of the space plugin where changes will be executed.
  /// @return proposalId The ID of the created proposal.
  function proposeFlagContent(
    bytes calldata _metadataContentUri,
    string memory _flagContentUri,
    address _spacePlugin
  ) external returns (uint256 proposalId);

  /// @notice Creates a proposal to make the DAO accept the given DAO as a subspace.
  /// @param _metadataContentUri The metadata of the proposal.
  /// @param _subspaceDao The address of the DAO that holds the new subspace.
  /// @param _spacePlugin The address of the space plugin where changes will be executed.
  /// @return proposalId The ID of the created proposal.
  function proposeAcceptSubspace(
    bytes calldata _metadataContentUri,
    IDAO _subspaceDao,
    address _spacePlugin
  ) external returns (uint256 proposalId);

  /// @notice Creates a proposal to make the DAO remove the given DAO as a subspace.
  /// @param _metadataContentUri The metadata of the proposal.
  /// @param _subspaceDao The address of the DAO that holds the subspace to remove.
  /// @param _spacePlugin The address of the space plugin where changes will be executed.
  /// @return proposalId The ID of the created proposal.
  function proposeRemoveSubspace(
    bytes calldata _metadataContentUri,
    IDAO _subspaceDao,
    address _spacePlugin
  ) external returns (uint256 proposalId);

  /// @notice Creates a proposal to add a new member.
  /// @param _metadataContentUri The metadata of the proposal.
  /// @param _proposedMember The address of the member who may eventually be added.
  /// @return proposalId NOTE: The proposal ID will belong to the Multisig plugin, not to this contract.
  function proposeAddMember(
    bytes calldata _metadataContentUri,
    address _proposedMember
  ) external returns (uint256 proposalId);

  /// @notice Creates a proposal to remove an existing member.
  /// @param _metadataContentUri The metadata of the proposal.
  /// @param _member The address of the member who may eventually be removed.
  /// @return proposalId The ID of the created proposal.
  function proposeRemoveMember(
    bytes calldata _metadataContentUri,
    address _member
  ) external returns (uint256 proposalId);

  /// @notice Creates a proposal to remove an existing member.
  /// @param _metadataContentUri The metadata of the proposal.
  /// @param _proposedEditor The address of the wallet who may eventually be made an editor.
  /// @return proposalId The ID of the created proposal.
  function proposeAddEditor(
    bytes calldata _metadataContentUri,
    address _proposedEditor
  ) external returns (uint256 proposalId);

  /// @notice Creates a proposal to remove an existing editor.
  /// @param _metadataContentUri The metadata of the proposal.
  /// @param _editor The address of the editor who may eventually be removed.
  /// @return proposalId The ID of the created proposal.
  function proposeRemoveEditor(
    bytes calldata _metadataContentUri,
    address _editor
  ) external returns (uint256 proposalId);

  /// @notice Cancels the given proposal. It can only be called by the creator and the proposal must have not ended.
  function cancelProposal(uint256 _proposalId) external;
}
