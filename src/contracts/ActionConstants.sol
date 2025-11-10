// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

import {IActionConstants} from 'interfaces/IActionConstants.sol';

abstract contract ActionConstants is IActionConstants {
  /// @inheritdoc IActionConstants
  bytes32 public constant SPACE_ID_REGISTERED = keccak256('SPACE_ID_REGISTERED');

  /// @inheritdoc IActionConstants
  bytes32 public constant SPACE_ID_MIGRATED = keccak256('SPACE_ID_MIGRATED');
}
