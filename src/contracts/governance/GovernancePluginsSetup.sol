// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {IDAO} from '@aragon/osx/core/dao/IDAO.sol';
import {PermissionLib} from '@aragon/osx/core/permission/PermissionLib.sol';
import {IPluginSetup, PluginSetup} from '@aragon/osx/framework/plugin/setup/PluginSetup.sol';

import {MemberAccessExecuteCondition} from 'contracts/conditions/MemberAccessExecuteCondition.sol';
import {MainVotingPlugin} from 'contracts/governance/MainVotingPlugin.sol';
import {IMemberAccessPlugin, MemberAccessPlugin} from 'contracts/governance/MemberAccessPlugin.sol';
import {IGovernancePluginsSetup} from 'interfaces/governance/IGovernancePluginsSetup.sol';
import {IMajorityVoting} from 'interfaces/governance/base/IMajorityVoting.sol';
import {EXECUTE_PERMISSION_ID} from 'src/constants.sol';

/// @title GovernancePluginsSetup
/// @dev Release 1, Build 1
contract GovernancePluginsSetup is PluginSetup, IGovernancePluginsSetup {
  /// @notice The address of the MainVotingPlugin implementation
  address private immutable mainVotingPluginImplementation;
  /// @inheritdoc IGovernancePluginsSetup
  address public immutable memberAccessPluginImplementation;

  /// @notice Initializes the setup contract
  constructor() {
    mainVotingPluginImplementation = address(new MainVotingPlugin());
    memberAccessPluginImplementation = address(new MemberAccessPlugin());
  }

  /// @inheritdoc IPluginSetup
  /// @notice Prepares the installation of the two governance plugins in one go
  function prepareInstallation(
    address _dao,
    bytes memory _data
  ) external returns (address mainVotingPlugin, PreparedSetupData memory preparedSetupData) {
    // Decode the custom installation parameters
    (
      IMajorityVoting.VotingSettings memory _votingSettings,
      address[] memory _initialEditors,
      address[] memory _initialMembers,
      uint64 _memberAccessProposalDuration
    ) = decodeInstallationParams(_data);

    // Deploy the member access plugin
    address _memberAccessPlugin = createERC1967Proxy(
      memberAccessPluginImplementation,
      abi.encodeCall(
        MemberAccessPlugin.initialize,
        (IDAO(_dao), IMemberAccessPlugin.MultisigSettings({proposalDuration: _memberAccessProposalDuration}))
      )
    );

    // Deploy the main voting plugin
    mainVotingPlugin = createERC1967Proxy(
      mainVotingPluginImplementation,
      abi.encodeCall(
        MainVotingPlugin.initialize,
        (IDAO(_dao), _votingSettings, _initialEditors, _initialMembers, MemberAccessPlugin(_memberAccessPlugin))
      )
    );

    // Condition contract (member access plugin execute)
    address _memberAccessExecuteCondition = address(new MemberAccessExecuteCondition(mainVotingPlugin));

    // List the requested permissions
    PermissionLib.MultiTargetPermission[] memory permissions = new PermissionLib.MultiTargetPermission[](6);

    // The main voting plugin can execute on the DAO
    permissions[0] = PermissionLib.MultiTargetPermission({
      operation: PermissionLib.Operation.Grant,
      where: _dao,
      who: mainVotingPlugin,
      condition: PermissionLib.NO_CONDITION,
      permissionId: EXECUTE_PERMISSION_ID
    });
    // The DAO can update the main voting plugin settings
    permissions[1] = PermissionLib.MultiTargetPermission({
      operation: PermissionLib.Operation.Grant,
      where: mainVotingPlugin,
      who: _dao,
      condition: PermissionLib.NO_CONDITION,
      permissionId: MainVotingPlugin(mainVotingPluginImplementation).UPDATE_VOTING_SETTINGS_PERMISSION_ID()
    });
    // The DAO can manage the list of addresses
    permissions[2] = PermissionLib.MultiTargetPermission({
      operation: PermissionLib.Operation.Grant,
      where: mainVotingPlugin,
      who: _dao,
      condition: PermissionLib.NO_CONDITION,
      permissionId: MainVotingPlugin(mainVotingPluginImplementation).UPDATE_ADDRESSES_PERMISSION_ID()
    });

    // The MainVotingPlugin can create membership proposals on the MemberAccessPlugin
    permissions[3] = PermissionLib.MultiTargetPermission({
      operation: PermissionLib.Operation.Grant,
      where: _memberAccessPlugin,
      who: mainVotingPlugin,
      condition: PermissionLib.NO_CONDITION,
      permissionId: MemberAccessPlugin(memberAccessPluginImplementation).PROPOSER_PERMISSION_ID()
    });

    // The member access plugin needs to execute on the DAO
    permissions[4] = PermissionLib.MultiTargetPermission({
      operation: PermissionLib.Operation.GrantWithCondition,
      where: _dao,
      who: _memberAccessPlugin,
      // Conditional execution
      condition: _memberAccessExecuteCondition,
      permissionId: EXECUTE_PERMISSION_ID
    });
    // The DAO needs to be able to update the member access plugin settings
    permissions[5] = PermissionLib.MultiTargetPermission({
      operation: PermissionLib.Operation.Grant,
      where: _memberAccessPlugin,
      who: _dao,
      condition: PermissionLib.NO_CONDITION,
      permissionId: MemberAccessPlugin(memberAccessPluginImplementation).UPDATE_MULTISIG_SETTINGS_PERMISSION_ID()
    });

    // The DAO doesn't need APPLY_UPDATE_PERMISSION_ID on the PSP

    preparedSetupData.permissions = permissions;
    preparedSetupData.helpers = new address[](1);
    preparedSetupData.helpers[0] = _memberAccessPlugin;

    emit GeoGovernancePluginsCreated(_dao, mainVotingPlugin, _memberAccessPlugin);
  }

  /// @inheritdoc IPluginSetup
  function prepareUninstallation(
    address _dao,
    SetupPayload calldata _payload
  ) external view returns (PermissionLib.MultiTargetPermission[] memory permissionChanges) {
    if (_payload.currentHelpers.length != 1) {
      revert InvalidHelpers(_payload.currentHelpers.length);
    }

    address _memberAccessPlugin = _payload.currentHelpers[0];

    permissionChanges = new PermissionLib.MultiTargetPermission[](6);

    // Main voting plugin permissions

    // The plugin can no longer execute on the DAO
    permissionChanges[0] = PermissionLib.MultiTargetPermission({
      operation: PermissionLib.Operation.Revoke,
      where: _dao,
      who: _payload.plugin,
      condition: PermissionLib.NO_CONDITION,
      permissionId: EXECUTE_PERMISSION_ID
    });
    // The DAO can no longer update the plugin settings
    permissionChanges[1] = PermissionLib.MultiTargetPermission({
      operation: PermissionLib.Operation.Revoke,
      where: _payload.plugin,
      who: _dao,
      condition: PermissionLib.NO_CONDITION,
      permissionId: MainVotingPlugin(mainVotingPluginImplementation).UPDATE_VOTING_SETTINGS_PERMISSION_ID()
    });
    // The DAO can no longer manage the list of addresses
    permissionChanges[2] = PermissionLib.MultiTargetPermission({
      operation: PermissionLib.Operation.Revoke,
      where: _payload.plugin,
      who: _dao,
      condition: PermissionLib.NO_CONDITION,
      permissionId: MainVotingPlugin(mainVotingPluginImplementation).UPDATE_ADDRESSES_PERMISSION_ID()
    });

    // Plugin permissions

    // The MainVotingPlugin can no longer propose on the MemberAccessPlugin
    permissionChanges[3] = PermissionLib.MultiTargetPermission({
      operation: PermissionLib.Operation.Revoke,
      where: _memberAccessPlugin,
      who: _payload.plugin,
      condition: PermissionLib.NO_CONDITION,
      permissionId: MemberAccessPlugin(memberAccessPluginImplementation).PROPOSER_PERMISSION_ID()
    });

    // The plugin can no longer execute on the DAO
    permissionChanges[4] = PermissionLib.MultiTargetPermission({
      operation: PermissionLib.Operation.Revoke,
      where: _dao,
      who: _memberAccessPlugin,
      condition: PermissionLib.NO_CONDITION,
      permissionId: EXECUTE_PERMISSION_ID
    });
    // The DAO can no longer update the plugin settings
    permissionChanges[5] = PermissionLib.MultiTargetPermission({
      operation: PermissionLib.Operation.Revoke,
      where: _memberAccessPlugin,
      who: _dao,
      condition: PermissionLib.NO_CONDITION,
      permissionId: MemberAccessPlugin(memberAccessPluginImplementation).UPDATE_MULTISIG_SETTINGS_PERMISSION_ID()
    });
  }

  /// @inheritdoc IPluginSetup
  function implementation() external view returns (address) {
    return mainVotingPluginImplementation;
  }

  /// @inheritdoc IGovernancePluginsSetup
  function encodeInstallationParams(
    IMajorityVoting.VotingSettings calldata _votingSettings,
    address[] calldata _initialEditors,
    address[] calldata _initialMembers,
    uint64 _memberAccessProposalDuration
  ) public pure returns (bytes memory) {
    return abi.encode(_votingSettings, _initialEditors, _initialMembers, _memberAccessProposalDuration);
  }

  /// @inheritdoc IGovernancePluginsSetup
  function decodeInstallationParams(bytes memory _data)
    public
    pure
    returns (
      IMajorityVoting.VotingSettings memory votingSettings,
      address[] memory initialEditors,
      address[] memory initialMembers,
      uint64 memberAccessProposalDuration
    )
  {
    (votingSettings, initialEditors, initialMembers, memberAccessProposalDuration) =
      abi.decode(_data, (IMajorityVoting.VotingSettings, address[], address[], uint64));
  }
}
