// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

import {IDAO} from '@aragon/osx/core/dao/IDAO.sol';
import {PermissionLib} from '@aragon/osx/core/permission/PermissionLib.sol';
import {IPluginSetup, PluginSetup} from '@aragon/osx/framework/plugin/setup/PluginSetup.sol';

import {SpacePlugin} from 'contracts/space/SpacePlugin.sol';
import {ISpacePluginSetup} from 'interfaces/space/ISpacePluginSetup.sol';
import {CONTENT_PERMISSION_ID, SUBSPACE_PERMISSION_ID} from 'src/constants.sol';

/// @title SpacePluginSetup
/// @dev Release 1, Build 1
contract SpacePluginSetup is PluginSetup, ISpacePluginSetup {
  /// @notice The plugin implementation address
  address private immutable pluginImplementation;

  /// @notice Initializes the setup contract
  constructor() {
    pluginImplementation = address(new SpacePlugin());
  }

  /// @inheritdoc IPluginSetup
  function prepareInstallation(
    address _dao,
    bytes memory _data
  ) external returns (address plugin, PreparedSetupData memory preparedSetupData) {
    // Decode incoming params
    (
      address _paymentManager,
      string memory _firstBlockEditsContentUri,
      bytes memory _firstBlockEditsMetadata,
      address _predecessorAddress
    ) = decodeInstallationParams(_data);

    // Deploy new plugin instance
    plugin = createERC1967Proxy(
      pluginImplementation,
      abi.encodeCall(
        SpacePlugin.initialize,
        (IDAO(_dao), _paymentManager, _firstBlockEditsContentUri, _firstBlockEditsMetadata, _predecessorAddress)
      )
    );

    PermissionLib.MultiTargetPermission[] memory permissions = new PermissionLib.MultiTargetPermission[](2);

    // The DAO can emit content
    permissions[0] = PermissionLib.MultiTargetPermission({
      operation: PermissionLib.Operation.Grant,
      where: plugin,
      who: _dao,
      condition: PermissionLib.NO_CONDITION,
      permissionId: CONTENT_PERMISSION_ID
    });
    // The DAO can accept a subspace
    permissions[1] = PermissionLib.MultiTargetPermission({
      operation: PermissionLib.Operation.Grant,
      where: plugin,
      who: _dao,
      condition: PermissionLib.NO_CONDITION,
      permissionId: SUBSPACE_PERMISSION_ID
    });

    preparedSetupData.permissions = permissions;

    emit GeoSpacePluginCreated(_dao, plugin);
  }

  /// @inheritdoc IPluginSetup
  function prepareUninstallation(
    address _dao,
    SetupPayload calldata _payload
  ) external view returns (PermissionLib.MultiTargetPermission[] memory permissionChanges) {
    permissionChanges = new PermissionLib.MultiTargetPermission[](2);

    // The DAO can make it emit content
    permissionChanges[0] = PermissionLib.MultiTargetPermission({
      operation: PermissionLib.Operation.Revoke,
      where: _payload.plugin,
      who: _dao,
      condition: PermissionLib.NO_CONDITION,
      permissionId: CONTENT_PERMISSION_ID
    });
    // The DAO can make it accept/reject a subspace
    permissionChanges[1] = PermissionLib.MultiTargetPermission({
      operation: PermissionLib.Operation.Revoke,
      where: _payload.plugin,
      who: _dao,
      condition: PermissionLib.NO_CONDITION,
      permissionId: SUBSPACE_PERMISSION_ID
    });
  }

  /// @inheritdoc IPluginSetup
  function implementation() external view returns (address) {
    return pluginImplementation;
  }

  /// @inheritdoc ISpacePluginSetup
  function encodeInstallationParams(
    address _paymentManager,
    string memory _firstBlockEditsContentUri,
    bytes memory _firstBlockEditsMetadata,
    address _predecessorAddress
  ) public pure returns (bytes memory) {
    return abi.encode(_paymentManager, _firstBlockEditsContentUri, _firstBlockEditsMetadata, _predecessorAddress);
  }

  /// @inheritdoc ISpacePluginSetup
  function decodeInstallationParams(bytes memory _data)
    public
    pure
    returns (
      address paymentManager,
      string memory firstBlockEditsContentUri,
      bytes memory firstBlockEditsMetadata,
      address predecessorAddress
    )
  {
    (
      paymentManager, firstBlockEditsContentUri, firstBlockEditsMetadata, predecessorAddress
    ) = abi.decode(_data, (address, string, bytes, address));
  }
}
