// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.30;

/// @dev The ID of the action to register a space
bytes32 constant SPACE_ID_REGISTERED = keccak256('GOVERNANCE.SPACE_ID_REGISTERED');

/// @dev The ID of the action to archive a space ID
bytes32 constant SPACE_ID_ARCHIVED = keccak256('GOVERNANCE.SPACE_ID_ARCHIVED');

/// @dev The ID of the action to recover an archived space ID
bytes32 constant SPACE_ID_RECOVERED = keccak256('GOVERNANCE.SPACE_ID_RECOVERED');

/// @dev The ID of the action to clear a space ID from the registry
bytes32 constant SPACE_ID_CLEARED = keccak256('GOVERNANCE.SPACE_ID_CLEARED');

/// @dev The ID of the action to propose a space migration
bytes32 constant SPACE_ID_MIGRATION_PROPOSED = keccak256('GOVERNANCE.SPACE_ID_MIGRATION_PROPOSED');

/// @dev The ID of the action to migrate a space
bytes32 constant SPACE_ID_MIGRATED = keccak256('GOVERNANCE.SPACE_ID_MIGRATED');

/// @dev The ID of the action when a space ID is overridden by the registry owner
bytes32 constant SPACE_ID_OVERRIDDEN = keccak256('GOVERNANCE.SPACE_ID_OVERRIDDEN');

/// @dev The ID of the action to declare a space type. Should be emitted when a space is registered
bytes32 constant SPACE_TYPE_DECLARED = keccak256('GOVERNANCE.SPACE_TYPE_DECLARED');

/// @dev The ID of the action when a permissionless action is added to the space registry
bytes32 constant PERMISSIONLESS_ACTION_ADDED = keccak256('GOVERNANCE.PERMISSIONLESS_ACTION_ADDED');

/// @dev The ID of the action when a permissionless action is removed from the space registry
bytes32 constant PERMISSIONLESS_ACTION_REMOVED = keccak256('GOVERNANCE.PERMISSIONLESS_ACTION_REMOVED');

/// @dev The ID of the action when the registry owner sets the Arbitrum PaymentManager proxy
bytes32 constant PAYMENT_MANAGER_SET = keccak256('GOVERNANCE.PAYMENT_MANAGER_SET');

/// @dev The ID of the action when a space enqueues an L2 incentives payer update via cross-chain messaging
bytes32 constant L2_INCENTIVES_PAYER_ENQUEUED = keccak256('GOVERNANCE.L2_INCENTIVES_PAYER_ENQUEUED');

/// @dev The ID of the action to update the voting settings
bytes32 constant VOTING_SETTINGS_UPDATED = keccak256('GOVERNANCE.VOTING_SETTINGS_UPDATED');

/// @dev The ID of the action to create a proposal
bytes32 constant PROPOSAL_CREATED = keccak256('GOVERNANCE.PROPOSAL_CREATED');

/// @dev The ID of the action to declare the proposal settings selected. Should be emitted when a proposal is created or updated
bytes32 constant PROPOSAL_SETTINGS_SELECTED = keccak256('GOVERNANCE.PROPOSAL_SETTINGS_SELECTED');

/// @dev The ID of the action to update a proposal
bytes32 constant PROPOSAL_UPDATED = keccak256('GOVERNANCE.PROPOSAL_UPDATED');

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

/// @dev The ID of the action to request a space to become a member
bytes32 constant MEMBERSHIP_REQUESTED = keccak256('GOVERNANCE.MEMBERSHIP_REQUESTED');

/// @dev The ID of the action to restrict a space (fast path access)
bytes32 constant SPACE_FAST_PATH_RESTRICTED = keccak256('GOVERNANCE.SPACE_FAST_PATH_RESTRICTED');

/// @dev The ID of the action to unrestrict a space (fast path access)
bytes32 constant SPACE_FAST_PATH_UNRESTRICTED = keccak256('GOVERNANCE.SPACE_FAST_PATH_UNRESTRICTED');

/// @dev The ID of the action to flag something (e.g. content, topic, proposal)
bytes32 constant FLAGGED = keccak256('GOVERNANCE.FLAGGED');

/// @dev The ID of the action to unflag something (e.g. content, topic, proposal)
bytes32 constant UNFLAGGED = keccak256('GOVERNANCE.UNFLAGGED');

/// @dev The ID of the action to set a new topic for a space
bytes32 constant TOPIC_SET = keccak256('GOVERNANCE.TOPIC_SET');

/// @dev The ID of the action to unset a topic for a space
bytes32 constant TOPIC_UNSET = keccak256('GOVERNANCE.TOPIC_UNSET');

/// @dev The ID of the action to publish content edits
bytes32 constant EDITS_PUBLISHED = keccak256('GOVERNANCE.EDITS_PUBLISHED');

/// @dev The ID of the action to link entities together (e.g. a proposal to a bounty or another proposal)
bytes32 constant ENTITIES_LINKED = keccak256('GOVERNANCE.ENTITIES_LINKED');

/// @dev The ID of the action to break the link between entities
bytes32 constant ENTITIES_UNLINKED = keccak256('GOVERNANCE.ENTITIES_UNLINKED');

/// @dev The ID of the action to add a subspace
bytes32 constant SUBSPACE_ADDED = keccak256('GOVERNANCE.SUBSPACE_ADDED');

/// @dev The ID of the action to remove a subspace
bytes32 constant SUBSPACE_REMOVED = keccak256('GOVERNANCE.SUBSPACE_REMOVED');

/// @dev The ID of the action to verify a subspace
bytes32 constant SUBSPACE_VERIFIED = keccak256('GOVERNANCE.SUBSPACE_VERIFIED');

/// @dev The ID of the action to unverify a subspace
bytes32 constant SUBSPACE_UNVERIFIED = keccak256('GOVERNANCE.SUBSPACE_UNVERIFIED');

/// @dev The ID of the action to relate a subspace to something (e.g. link subspaces)
bytes32 constant SUBSPACE_RELATED = keccak256('GOVERNANCE.SUBSPACE_RELATED');

/// @dev The ID of the action to break a subspace relation (e.g. linked subspaces)
bytes32 constant SUBSPACE_UNRELATED = keccak256('GOVERNANCE.SUBSPACE_UNRELATED');

/// @dev The ID of the action to set a new topic for a subspace
bytes32 constant SUBSPACE_TOPIC_SET = keccak256('GOVERNANCE.SUBSPACE_TOPIC_SET');

/// @dev The ID of the action to unset a topic for in a subspace
bytes32 constant SUBSPACE_TOPIC_UNSET = keccak256('GOVERNANCE.SUBSPACE_TOPIC_UNSET');

/// @dev The ID of the action to upvote something (e.g. content, topic, proposal)
bytes32 constant UPVOTED = keccak256('PERMISSIONLESS.UPVOTED');

/// @dev The ID of the action to downvote something (e.g. content, topic, proposal)
bytes32 constant DOWNVOTED = keccak256('PERMISSIONLESS.DOWNVOTED');

/// @dev The ID of the action to remove a vote on something (e.g. content, topic, proposal)
bytes32 constant UNVOTED = keccak256('PERMISSIONLESS.UNVOTED');

/// @dev The ID of the action to comment on something (e.g. content, topic, proposal)
bytes32 constant COMMENTED = keccak256('PERMISSIONLESS.COMMENTED');
