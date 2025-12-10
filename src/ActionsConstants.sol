// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

/// @dev The ID of the action to register a space
bytes32 constant SPACE_ID_REGISTERED = keccak256('SPACE_ID_REGISTERED');

/// @dev The ID of the action to migrate a space
bytes32 constant SPACE_ID_MIGRATED = keccak256('SPACE_ID_MIGRATED');

/// @dev The ID of the action to create a proposal
bytes32 constant CREATE_PROPOSAL = keccak256('CREATE_PROPOSAL');

/// @dev The ID of the action to vote on a proposal
bytes32 constant VOTE = keccak256('VOTE');

/// @dev The ID of the action to execute a proposal
bytes32 constant EXECUTE_PROPOSAL = keccak256('EXECUTE_PROPOSAL');

/// @dev The ID of the action to leave a space as a member or editor
bytes32 constant LEAVE = keccak256('LEAVE');

/// @dev The ID of the action to add an editor
bytes32 constant ADD_EDITOR = keccak256('ADD_EDITOR');

/// @dev The ID of the action to remove an editor
bytes32 constant REMOVE_EDITOR = keccak256('REMOVE_EDITOR');

/// @dev The ID of the action to add a member
bytes32 constant ADD_MEMBER = keccak256('ADD_MEMBER');

/// @dev The ID of the action to remove a member
bytes32 constant REMOVE_MEMBER = keccak256('REMOVE_MEMBER');

/// @dev The ID of the action to flag an editor (restricts fast path access)
bytes32 constant FLAG_EDITOR = keccak256('FLAG_EDITOR');

/// @dev The ID of the action to unflag an editor (restores fast path access)
bytes32 constant UNFLAG_EDITOR = keccak256('UNFLAG_EDITOR');
