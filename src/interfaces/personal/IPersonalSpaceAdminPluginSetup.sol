// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

import {IPluginSetup} from '@aragon/osx/framework/plugin/setup/IPluginSetup.sol';

/// @title IPersonalSpaceAdminPluginSetup
/// @notice The setup interface of the `PersonalSpaceAdminPlugin` plugin.
interface IPersonalSpaceAdminPluginSetup is IPluginSetup {
  /// @notice Emitted when a `PersonalSpaceAdminPlugin` plugin is created
  /// @param dao The address of the installing DAO
  /// @param personalAdminPlugin The address of the `PersonalSpaceAdminPlugin` plugin
  event GeoPersonalAdminPluginCreated(address dao, address personalAdminPlugin);

  /// @notice Encodes the given installation parameters into a byte array
  /// @param _initialEditors The initial editors
  /// @param _initialMembers The initial members
  /// @return data The encoded installation parameters
  function encodeInstallationParams(
    address[] calldata _initialEditors,
    address[] calldata _initialMembers
  ) external pure returns (bytes memory);

  /// @notice Decodes the given byte array into the original installation parameters
  /// @param _data The encoded installation parameters
  /// @return initialEditors The initial editors
  /// @return initialMembers The initial members
  function decodeInstallationParams(bytes memory _data)
    external
    pure
    returns (address[] memory initialEditors, address[] memory initialMembers);
}
