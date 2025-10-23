// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

import {IDAO} from '@aragon/osx/core/dao/IDAO.sol';
import {IPlugin} from '@aragon/osx/core/plugin/IPlugin.sol';
import {IProposal} from '@aragon/osx/core/plugin/proposal/IProposal.sol';

import {MainVotingPlugin} from 'contracts/governance/MainVotingPlugin.sol';
import {IMultisig} from 'interfaces/governance/base/IMultisig.sol';

/// @title Member access plugin (Multisig) - Release 1, Build 1
/// @notice The on-chain multisig governance plugin in which a proposal passes if X out of Y approvals are met.
interface IMemberAccessPlugin is IMultisig, IPlugin, IProposal {
  /// @notice A container for proposal-related information.
  /// @param executed Whether the proposal is executed or not.
  /// @param approvals The number of approvals casted.
  /// @param parameters The proposal-specific approve settings at the time of the proposal creation.
  /// @param approvers The approves casted by the approvers.
  /// @param actions The actions to be executed when the proposal passes.
  /// @param mainVotingPlugin The `MainVotingPlugin` contract.
  /// @param failsafeActionMap A bitmap allowing the proposal to succeed, even if certain actions might revert. If the bit at index `i` is 1, the proposal succeeds even if the `i`th action reverts. A failure map value of 0 requires every action to not revert.
  struct Proposal {
    bool executed;
    uint16 approvals;
    ProposalParameters parameters;
    mapping(address => bool) approvers;
    IDAO.Action[] actions;
    MainVotingPlugin mainVotingPlugin;
    uint256 failsafeActionMap;
  }

  /// @notice A container for the proposal parameters.
  /// @param minApprovals The number of approvals required.
  /// @param snapshotBlock The number of the block prior to the proposal creation.
  /// @param startDate The timestamp when the proposal starts.
  /// @param endDate The timestamp when the proposal expires.
  struct ProposalParameters {
    uint16 minApprovals;
    uint64 snapshotBlock;
    uint64 startDate;
    uint64 endDate;
  }

  /// @notice A container for the plugin settings.
  /// @param proposalDuration The amount of time before a non-approved proposal expires.
  struct MultisigSettings {
    uint64 proposalDuration;
  }

  /// @notice Emitted when a proposal to add a new member is created.
  /// @param proposalId The ID of the proposal.
  /// @param creator The address of the proposal creator.
  /// @param startDate The timestamp when the proposal starts.
  /// @param endDate The timestamp when the proposal expires.
  /// @param member The address of the member who may eventually be added.
  /// @param dao The address of the associated DAO.
  event AddMemberProposalCreated(
    uint256 indexed proposalId,
    address indexed creator,
    uint64 startDate,
    uint64 endDate,
    address indexed member,
    address dao
  );

  /// @notice Emitted when a proposal is approved by an editor.
  /// @param proposalId The ID of the proposal.
  /// @param editor The editor casting the approve.
  event Approved(uint256 indexed proposalId, address indexed editor);

  /// @notice Emitted when a proposal is rejected by an editor.
  /// @param proposalId The ID of the proposal.
  /// @param editor The editor casting the rejection.
  event Rejected(uint256 indexed proposalId, address indexed editor);

  /// @notice Emitted when the plugin settings are set.
  /// @param proposalDuration The amount of time before a non-approved proposal expires.
  event MultisigSettingsUpdated(uint64 proposalDuration);

  /// @notice Thrown when creating a proposal at the same block that the settings were changed.
  error ProposalCreationForbiddenOnSameBlock();

  /// @notice Thrown if an approver is not allowed to cast an approve. This can be because the proposal
  /// - is not open,
  /// - was executed, or
  /// - the approver is not on the address list
  /// @param proposalId The ID of the proposal.
  /// @param sender The address of the sender.
  error ApprovalCastForbidden(uint256 proposalId, address sender);

  /// @notice Thrown if the proposal execution is forbidden.
  /// @param proposalId The ID of the proposal.
  error ProposalExecutionForbidden(uint256 proposalId);

  /// @notice Thrown when called from an incompatible contract.
  error InvalidInterface();

  /// @notice The ID of the permission required to call the `addAddresses` functions.
  /// @return updateMultisigSettingsPermissionId The ID of the update-multisig-settings permission.
  function UPDATE_MULTISIG_SETTINGS_PERMISSION_ID() external view returns (bytes32 updateMultisigSettingsPermissionId);

  /// @notice The ID of the permission required to create new membership proposals.
  /// @return proposerPermissionId The ID of the proposer permission.
  function PROPOSER_PERMISSION_ID() external view returns (bytes32 proposerPermissionId);

  /// @notice The current plugin settings.
  /// @return multisigSettings The multisig settings.
  function multisigSettings() external view returns (uint64 multisigSettings);

  /// @notice Keeps track at which block number the multisig settings have been changed the last time.
  /// @dev This variable prevents a proposal from being created in the same block in which the multisig settings change.
  /// @return lastMultisigSettingsChange The block number at which the multisig settings have been changed the last time.
  function lastMultisigSettingsChange() external view returns (uint64 lastMultisigSettingsChange);

  /// @notice Initializes Release 1, Build 1.
  /// @dev This method is required to support [ERC-1822](https://eips.ethereum.org/EIPS/eip-1822).
  /// @param _dao The IDAO interface of the associated DAO.
  /// @param _multisigSettings The multisig settings.
  function initialize(IDAO _dao, MultisigSettings calldata _multisigSettings) external;

  /// @notice Updates the plugin settings.
  /// @param _multisigSettings The new settings.
  function updateMultisigSettings(MultisigSettings calldata _multisigSettings) external;

  /// @notice Creates a proposal to add a new member.
  /// @param _metadata The metadata of the proposal.
  /// @param _proposedMember The address of the member who may eventually be added.
  /// @param _proposer The address to use as the proposal creator.
  /// @return proposalId The ID of the proposal.
  function proposeAddMember(
    bytes calldata _metadata,
    address _proposedMember,
    address _proposer
  ) external returns (uint256 proposalId);

  /// @notice Rejects the given proposal immediately.
  /// @param _proposalId The Id of the proposal to reject.
  function reject(uint256 _proposalId) external;

  /// @notice Returns all information for a proposal vote by its ID.
  /// @param _proposalId The ID of the proposal.
  /// @return executed Whether the proposal is executed or not.
  /// @return approvals The number of approvals casted.
  /// @return parameters The parameters of the proposal vote.
  /// @return actions The actions to be executed in the associated DAO after the proposal has passed.
  /// @return failsafeActionMap A bitmap allowing the proposal to succeed, even if individual actions might revert. If the bit at index `i` is 1, the proposal succeeds even if the `i`th action reverts. A failure map value of 0 requires every action to not revert.
  function getProposal(uint256 _proposalId)
    external
    view
    returns (
      bool executed,
      uint16 approvals,
      ProposalParameters memory parameters,
      IDAO.Action[] memory actions,
      uint256 failsafeActionMap
    );
}
