// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

import {IPluginSetup} from '@aragon/osx/framework/plugin/setup/IPluginSetup.sol';

/// @title ISpacePluginSetup
/// @dev Release 1, Build 1
interface ISpacePluginSetup is IPluginSetup {
  event GeoSpacePluginCreated(address dao, address plugin);

  /// @notice Encodes the given installation parameters into a byte array
  function encodeInstallationParams(
    address _paymentManager,
    string memory _firstBlockEditsContentUri,
    bytes memory _firstBlockEditsMetadata,
    address _predecessorAddress,
    address _pluginUpgrader
  ) external pure returns (bytes memory);

  /// @notice Decodes the given byte array into the original installation parameters
  function decodeInstallationParams(bytes memory _data)
    external
    pure
    returns (
      address paymentManager,
      string memory firstBlockEditsContentUri,
      bytes memory firstBlockEditsMetadata,
      address predecessorAddress,
      address pluginUpgrader
    );

  /// @notice Encodes the given uninstallation parameters into a byte array
  function encodeUninstallationParams(address _pluginUpgrader) external pure returns (bytes memory);

  /// @notice Decodes the given byte array into the original uninstallation parameters
  function decodeUninstallationParams(bytes memory _data) external pure returns (address pluginUpgrader);
}
