// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

import {IPermissionCondition} from '@aragon/osx/core/permission/IPermissionCondition.sol';

/// @notice The condition associated with `TestSharedPlugin`
interface IMemberAccessExecuteCondition is IPermissionCondition {}
