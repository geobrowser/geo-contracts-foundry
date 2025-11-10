// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

/// @dev The ID of the action to register a space
bytes32 constant SPACE_ID_REGISTERED = keccak256('SPACE_ID_REGISTERED');

/// @dev The ID of the action to migrate a space
bytes32 constant SPACE_ID_MIGRATED = keccak256('SPACE_ID_MIGRATED');
