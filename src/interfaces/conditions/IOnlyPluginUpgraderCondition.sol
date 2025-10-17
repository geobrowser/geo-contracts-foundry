// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

import {IPermissionCondition} from '@aragon/osx/core/permission/IPermissionCondition.sol';

/// @notice The condition associated with the `pluginUpgrader`
interface IOnlyPluginUpgraderCondition is IPermissionCondition {
  /// @notice Thrown when the constructor receives empty parameters
  error InvalidParameters();
}
