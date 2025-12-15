// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

/// @dev The ID of the action to register a space
bytes32 constant SPACE_ID_REGISTERED = keccak256('GOVERNANCE.SPACE_ID_REGISTERED');

/// @dev The ID of the action to migrate a space
bytes32 constant SPACE_ID_MIGRATED = keccak256('GOVERNANCE.SPACE_ID_MIGRATED');

/// @dev The ID of the action to create a proposal
bytes32 constant PROPOSAL_CREATED = keccak256('GOVERNANCE.PROPOSAL_CREATED');

/// @dev The ID of the action to vote on a proposal
bytes32 constant PROPOSAL_VOTED = keccak256('GOVERNANCE.PROPOSAL_VOTED');

/// @dev The ID of the action to execute a proposal
bytes32 constant PROPOSAL_EXECUTED = keccak256('GOVERNANCE.PROPOSAL_EXECUTED');

/// @dev The ID of the action to leave a space as a member or editor
bytes32 constant SPACE_LEFT = keccak256('GOVERNANCE.SPACE_LEFT');

/// @dev The ID of the action to add an editor
bytes32 constant EDITOR_ADDED = keccak256('GOVERNANCE.EDITOR_ADDED');

/// @dev The ID of the action to remove an editor
bytes32 constant EDITOR_REMOVED = keccak256('GOVERNANCE.EDITOR_REMOVED');

/// @dev The ID of the action to add a member
bytes32 constant MEMBER_ADDED = keccak256('GOVERNANCE.MEMBER_ADDED');

/// @dev The ID of the action to remove a member
bytes32 constant MEMBER_REMOVED = keccak256('GOVERNANCE.MEMBER_REMOVED');

/// @dev The ID of the action to flag an editor (restricts fast path access)
bytes32 constant EDITOR_FLAGGED = keccak256('GOVERNANCE.EDITOR_FLAGGED');

/// @dev The ID of the action to unflag an editor (restores fast path access)
bytes32 constant EDITOR_UNFLAGGED = keccak256('GOVERNANCE.EDITOR_UNFLAGGED');

/// @dev The ID of the action to publish content edits
bytes32 constant EDITS_PUBLISHED = keccak256('GOVERNANCE.EDITS_PUBLISHED');

/// @dev The ID of the action to flag something (e.g. content, topic, proposal)
bytes32 constant FLAGGED = keccak256('GOVERNANCE.FLAGGED');

/// @dev The ID of the action to unflag something (e.g. content, topic, proposal)
bytes32 constant UNFLAGGED = keccak256('GOVERNANCE.FLAGGED');
