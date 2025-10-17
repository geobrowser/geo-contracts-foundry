// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

import {IDAO} from '@aragon/osx/core/dao/IDAO.sol';
import {PluginUUPSUpgradeable} from '@aragon/osx/core/plugin/PluginUUPSUpgradeable.sol';
import {ProposalUpgradeable} from '@aragon/osx/core/plugin/proposal/ProposalUpgradeable.sol';
import {SafeCastUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol';

import {MainVotingPlugin} from 'contracts/governance/MainVotingPlugin.sol';
import {Addresslist} from 'contracts/governance/base/Addresslist.sol';
import {IEditors} from 'interfaces/base/IEditors.sol';
import {IMainVotingPlugin} from 'interfaces/governance/IMainVotingPlugin.sol';
import {IMemberAccessPlugin} from 'interfaces/governance/IMemberAccessPlugin.sol';
import {IMultisig} from 'interfaces/governance/base/IMultisig.sol';

/// @title Member access plugin (Multisig) - Release 1, Build 1
/// @notice The on-chain multisig governance plugin in which a proposal passes if X out of Y approvals are met.
contract MemberAccessPlugin is PluginUUPSUpgradeable, ProposalUpgradeable, IMemberAccessPlugin {
  using SafeCastUpgradeable for uint256;

  /// @inheritdoc IMemberAccessPlugin
  bytes32 public constant UPDATE_MULTISIG_SETTINGS_PERMISSION_ID = keccak256('UPDATE_MULTISIG_SETTINGS_PERMISSION');

  /// @inheritdoc IMemberAccessPlugin
  bytes32 public constant PROPOSER_PERMISSION_ID = keccak256('PROPOSER_PERMISSION');

  /// @notice The minimum total amount of approvals required for proposals created by a non-editor
  uint16 internal constant MIN_APPROVALS_WHEN_CREATED_BY_NON_EDITOR = uint16(1);

  /// @notice The minimum total amount of approvals required for proposals created by an editor (single)
  uint16 internal constant MIN_APPROVALS_WHEN_CREATED_BY_SINGLE_EDITOR = uint16(1);

  /// @notice The minimum total amount of approvals required for proposals created by an editor (multiple)
  uint16 internal constant MIN_APPROVALS_WHEN_CREATED_BY_EDITOR_OF_MANY = uint16(2);

  /// @notice A mapping between proposal IDs and proposal information.
  mapping(uint256 => Proposal) internal proposals;

  /// @inheritdoc IMemberAccessPlugin
  MultisigSettings public multisigSettings;

  /// @inheritdoc IMemberAccessPlugin
  uint64 public lastMultisigSettingsChange;

  /// @inheritdoc IMemberAccessPlugin
  function initialize(IDAO _dao, MultisigSettings calldata _multisigSettings) external virtual initializer {
    __PluginUUPSUpgradeable_init(_dao);

    _updateMultisigSettings(_multisigSettings);
  }

  /// @notice Checks if this or the parent contract supports an interface by its ID.
  /// @param _interfaceId The ID of the interface.
  /// @return Returns `true` if the interface is supported.
  function supportsInterface(bytes4 _interfaceId)
    public
    view
    virtual
    override(PluginUUPSUpgradeable, ProposalUpgradeable)
    returns (bool)
  {
    return _interfaceId == type(IMemberAccessPlugin).interfaceId || _interfaceId == type(IMultisig).interfaceId
      || super.supportsInterface(_interfaceId);
  }

  /// @inheritdoc IMemberAccessPlugin
  function updateMultisigSettings(MultisigSettings calldata _multisigSettings)
    external
    auth(UPDATE_MULTISIG_SETTINGS_PERMISSION_ID)
  {
    _updateMultisigSettings(_multisigSettings);
  }

  /// @inheritdoc IMemberAccessPlugin
  function proposeAddMember(
    bytes calldata _metadata,
    address _proposedMember,
    address _proposer
  ) public auth(PROPOSER_PERMISSION_ID) returns (uint256 proposalId) {
    // Check that the caller supports the `addMember` function
    if (
      !MainVotingPlugin(msg.sender).supportsInterface(type(IMainVotingPlugin).interfaceId)
        || !MainVotingPlugin(msg.sender).supportsInterface(type(IEditors).interfaceId)
        || !MainVotingPlugin(msg.sender).supportsInterface(type(Addresslist).interfaceId)
    ) {
      revert InvalidInterface();
    }

    // Build the list of actions
    IDAO.Action[] memory _actions = new IDAO.Action[](1);

    _actions[0] = IDAO.Action({
      to: address(msg.sender), // We are called by the MainVotingPlugin
      value: 0,
      data: abi.encodeCall(MainVotingPlugin.addMember, (_proposedMember))
    });

    // Create proposal
    uint64 snapshotBlock;
    unchecked {
      snapshotBlock = block.number.toUint64() - 1; // The snapshot block must be mined already to protect the transaction against backrunning transactions causing census changes.
    }

    // Revert if the settings have been changed in the same block as this proposal should be created in.
    // This prevents a malicious party from voting with previous addresses and the new settings.
    if (lastMultisigSettingsChange > snapshotBlock) {
      revert ProposalCreationForbiddenOnSameBlock();
    }

    uint64 _startDate = block.timestamp.toUint64();
    uint64 _endDate = _startDate + multisigSettings.proposalDuration;

    proposalId = _createProposalId();

    emit ProposalCreated({
      proposalId: proposalId,
      creator: _proposer,
      metadata: _metadata,
      startDate: _startDate,
      endDate: _endDate,
      actions: _actions,
      allowFailureMap: uint8(0)
    });

    // Create the proposal
    Proposal storage proposal_ = proposals[proposalId];

    proposal_.parameters.snapshotBlock = snapshotBlock;
    proposal_.parameters.startDate = _startDate;
    proposal_.parameters.endDate = _endDate;

    proposal_.mainVotingPlugin = MainVotingPlugin(msg.sender);
    for (uint256 i; i < _actions.length;) {
      proposal_.actions.push(_actions[i]);
      unchecked {
        ++i;
      }
    }

    // Another editor needs to approve. Set the minApprovals accordingly
    /// @dev The _proposer parameter is technically trusted.
    /// @dev However, this function is protected by PROPOSER_PERMISSION_ID and only the MainVoting plugin is granted this permission.
    /// @dev See GovernancePluginsSetup.sol
    if (MainVotingPlugin(msg.sender).isEditor(_proposer)) {
      if (MainVotingPlugin(msg.sender).addresslistLength() < 2) {
        proposal_.parameters.minApprovals = MIN_APPROVALS_WHEN_CREATED_BY_SINGLE_EDITOR;
      } else {
        proposal_.parameters.minApprovals = MIN_APPROVALS_WHEN_CREATED_BY_EDITOR_OF_MANY;
      }

      // If the creator is an editor, we assume that the editor approves
      _approve(proposalId, _proposer);
    } else {
      proposal_.parameters.minApprovals = MIN_APPROVALS_WHEN_CREATED_BY_NON_EDITOR;
    }

    emit AddMemberProposalCreated(
      proposalId,
      _proposer,
      proposal_.parameters.startDate,
      proposal_.parameters.endDate,
      _proposedMember,
      address(dao())
    );
  }

  /// @inheritdoc IMultisig
  function approve(uint256 _proposalId) public {
    _approve(_proposalId, msg.sender);
  }

  /// @notice Internal implementation, allowing proposeAddMember() to specify the proposer.
  function _approve(uint256 _proposalId, address _approver) internal {
    if (!_canApprove(_proposalId, _approver)) {
      revert ApprovalCastForbidden(_proposalId, _approver);
    }

    Proposal storage proposal_ = proposals[_proposalId];

    // As the list can never become more than type(uint16).max(due to addAddresses check)
    // It's safe to use unchecked as it would never overflow.
    unchecked {
      proposal_.approvals += 1;
    }

    proposal_.approvers[_approver] = true;

    emit Approved({proposalId: _proposalId, editor: _approver});

    if (_canExecute(_proposalId)) {
      _execute(_proposalId);
    }
  }

  /// @inheritdoc IMemberAccessPlugin
  function reject(uint256 _proposalId) public {
    if (!_canApprove(_proposalId, msg.sender)) {
      revert ApprovalCastForbidden(_proposalId, msg.sender);
    }

    Proposal storage proposal_ = proposals[_proposalId];

    // Prevent any further approvals, expire it
    proposal_.parameters.endDate = block.timestamp.toUint64();

    emit Rejected({proposalId: _proposalId, editor: msg.sender});
  }

  /// @inheritdoc IMultisig
  function canApprove(uint256 _proposalId, address _account) external view returns (bool) {
    return _canApprove(_proposalId, _account);
  }

  /// @inheritdoc IMultisig
  function canExecute(uint256 _proposalId) external view returns (bool) {
    return _canExecute(_proposalId);
  }

  /// @inheritdoc IMemberAccessPlugin
  function getProposal(uint256 _proposalId)
    public
    view
    returns (
      bool executed,
      uint16 approvals,
      ProposalParameters memory parameters,
      IDAO.Action[] memory actions,
      uint256 failsafeActionMap
    )
  {
    Proposal storage proposal_ = proposals[_proposalId];

    executed = proposal_.executed;
    approvals = proposal_.approvals;
    parameters = proposal_.parameters;
    actions = proposal_.actions;
    failsafeActionMap = proposal_.failsafeActionMap;
  }

  /// @inheritdoc IMultisig
  function hasApproved(uint256 _proposalId, address _account) public view returns (bool) {
    return proposals[_proposalId].approvers[_account];
  }

  /// @inheritdoc IMultisig
  function execute(uint256 _proposalId) public {
    if (!_canExecute(_proposalId)) {
      revert ProposalExecutionForbidden(_proposalId);
    }

    _execute(_proposalId);
  }

  /// @notice Internal function to execute a vote. It assumes the queried proposal exists.
  /// @param _proposalId The ID of the proposal.
  function _execute(uint256 _proposalId) internal {
    Proposal storage proposal_ = proposals[_proposalId];

    proposal_.executed = true;

    _executeProposal(dao(), _proposalId, proposals[_proposalId].actions, proposals[_proposalId].failsafeActionMap);
  }

  /// @notice Internal function to check if an account can approve. It assumes the queried proposal exists.
  /// @param _proposalId The ID of the proposal.
  /// @param _account The account to check.
  /// @return Returns `true` if the given account can approve on a certain proposal and `false` otherwise.
  function _canApprove(uint256 _proposalId, address _account) internal view returns (bool) {
    Proposal storage proposal_ = proposals[_proposalId];

    if (!_isProposalOpen(proposal_)) {
      // The proposal was executed already
      return false;
    } else if (!proposal_.mainVotingPlugin.isEditor(_account)) {
      // The approver has no voting power.
      return false;
    } else if (proposal_.approvers[_account]) {
      // The approver has already approved
      return false;
    }

    return true;
  }

  /// @notice Internal function to check if a proposal can be executed. It assumes the queried proposal exists.
  /// @param _proposalId The ID of the proposal.
  /// @return Returns `true` if the proposal can be executed and `false` otherwise.
  function _canExecute(uint256 _proposalId) internal view returns (bool) {
    Proposal storage proposal_ = proposals[_proposalId];

    // Verify that the proposal has not been executed or expired.
    if (!_isProposalOpen(proposal_)) {
      return false;
    }

    return proposal_.approvals >= proposal_.parameters.minApprovals;
  }

  /// @notice Internal function to check if a proposal vote is still open.
  /// @param proposal_ The proposal struct.
  /// @return True if the proposal vote is open, false otherwise.
  function _isProposalOpen(Proposal storage proposal_) internal view returns (bool) {
    uint64 currentTimestamp64 = block.timestamp.toUint64();
    return !proposal_.executed && proposal_.parameters.startDate <= currentTimestamp64
      && proposal_.parameters.endDate >= currentTimestamp64;
  }

  /// @notice Internal function to update the plugin settings.
  /// @param _multisigSettings The new settings.
  function _updateMultisigSettings(MultisigSettings calldata _multisigSettings) internal {
    multisigSettings = _multisigSettings;
    lastMultisigSettingsChange = block.number.toUint64();

    emit MultisigSettingsUpdated({proposalDuration: _multisigSettings.proposalDuration});
  }

  /// @dev This empty reserved space is put in place to allow future versions to add new
  /// variables without shifting down storage in the inheritance chain.
  /// https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
  uint256[47] private __gap;
}
