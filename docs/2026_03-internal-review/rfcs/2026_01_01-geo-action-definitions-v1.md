This document outlines how to both encode and interpret an `Action` event for the GEO Singleton contract.

```solidity
/**
 * @notice Emitted when a user calls the enter function
 * @param fromId The from space ID involved
 * @param toId The to space ID involved
 * @param action An action, which is passed to the space contract
 * @param topic A topic, which is passed to the space contract
 * @param data Some arbitrary data for space contract execution
 */
event Action(
  bytes16 indexed fromId,
  bytes16 indexed toId,
  bytes32 indexed action,
  bytes32 indexed topic,
  bytes data
) anonymous;
```

| Action Definitions | Action: `bytes32` | Topic: `bytes32` | Data: `bytes` |
| --- | --- | --- | --- |
| Space Id Registered | `keccak256('GOVERNANCE.SPACE_ID_REGISTERED')` | `bytes32(bytes20(spaceAddress))`  | `''`  - Empty |
| Space Id Cleared | `keccak256('GOVERNANCE.SPACE_ID_CLEARED')` | `bytes32(bytes20(spaceAddress))`  | `''`  - Empty |
| Space Id Migrated | `keccak256('GOVERNANCE.SPACE_ID_MIGRATED')` | `bytes32(bytes20(newSpaceAddress))` | `''`  - Empty |
| Space Type Declared | `keccak256('GOVERNANCE.SPACE_TYPE_DECLARED')` | `keccak256('SPACE_TYPE')`

E.g. `keccak256('DAO_SPACE')` | `abi.encode('VERSION')`

E.g. `abi.encode('1.0.0')` |
| Permissionless Action Added | `keccak256('GOVERNANCE.PERMISSIONLESS_ACTION_ADDED')` | `keccak256('ACTION')`

E.g. `keccak256('PERMISSIONLESS.UPVOTED')` | `''`  - Empty |
| Permissionless Action Removed | `keccak256('GOVERNANCE.PERMISSIONLESS_ACTION_REMOVED')` | `keccak256('ACTION')` | `''`  - Empty |
| Proposal Created | `keccak256('GOVERNANCE.PROPOSAL_CREATED')`  | `bytes32(proposalId)`  | `abi.encode(proposalId, Operation[], VoteOption)`

Proposal Id; An array of onchain operations (e.g. add editor); Vote option |
| Proposal Settings Used | `keccak256('GOVERNANCE.PROPOSAL_SETTINGS_USED')`  | `bytes32(proposalId)`  | `abi.encode(startDate, lastDate, votingMode, quorum, supportThreshold)` |
| Proposal Updated | `keccak256('GOVERNANCE.PROPOSAL_UPDATED')`  | `bytes32(proposalId)`  | `abi.encode(proposalId, Operation[], VoteOption)`

Proposal Id; An array of onchain operations (e.g. add editor); Vote option |
| Proposal Voted | `keccak256('GOVERNANCE.PROPOSAL_VOTED')` | `bytes32(proposalId)`  | `abi.encode(bytes32(proposalId, VoteOption))`

Proposal Id + Vote option |
| Proposal Executed | `keccak256('GOVERNANCE.PROPOSAL_EXECUTED')`  | `bytes32(proposalId)`  | `abi.encode(bytes32(proposalId))`

Proposal Id |
| Space Left | `keccak256('GOVERNANCE.SPACE_LEFT')` | `bytes32(keccak256('ROLE'))` 

E.g. `bytes32(keccak256('EDITOR'))` | `''`  - Empty |
| Editor Added | `keccak256('GOVERNANCE.EDITOR_ADDED')` | `bytes32(_newEditorSpaceId)` | `abi.encode(_newEditor)` |
| Editor Removed | `keccak256('GOVERNANCE.EDITOR_REMOVED')` | `bytes32(_oldEditorSpaceId)` | `abi.encode(_oldEditor)` |
| Member Added | `keccak256('GOVERNANCE.MEMBER_ADDED')` | `bytes32(_newMemberSpaceId)` | `abi.encode(_newMember)` |
| Member Removed | `keccak256('GOVERNANCE.MEMBER_REMOVED')` | `bytes32(_oldMemberSpaceId)` | `abi.encode(_oldMember)` |
| Membership Requested | `keccak256('GOVERNANCE.MEMBERSHIP_REQUESTED')` | `bytes32(proposalId)` | `abi.encode(_proposalId, member)` |
| Space Fast Path Restricted | `keccak256('GOVERNANCE.SPACE_FAST_PATH_RESTRICTED')` | `bytes32(_spaceId)` | `abi.encode(_flaggedEditor)` |
| Editor Space Fast Path Unrestricted | `keccak256('GOVERNANCE.SPACE_FAST_PATH_UNRESTRICTED')` | `bytes32(_spaceId)` | `abi.encode(_unflaggedEditor)` |
| Flagged | `keccak256('GOVERNANCE.FLAGGED')` | `bytes32(TOPIC_UUID)`

Optional | `abi.encode(bytes(flaggedUri))` |
| Unflagged | `keccak256('GOVERNANCE.UNFLAGGED')` | `bytes32(TOPIC_UUID)`

Optional | `abi.encode(bytes(unflaggedUri))`

 |
| Topic Declared | `keccak256('GOVERNANCE.TOPIC_DECLARED')`  | `bytes32('TOPIC_UUID')`

E.g. `bytes32('0x12345678')` | `abi.encode(bytes(contentMetadata))`

Optional |
| Topic Removed | `keccak256('GOVERNANCE.TOPIC_REMOVED')`  | `bytes32('TOPIC_UUID')`
 | `abi.encode(bytes(contentMetadata))`

Optional |
| Edits Published | `keccak256('GOVERNANCE.EDITS_PUBLISHED')` | `bytes32(TOPIC_UUID)`

Optional | `abi.encode(bytes(editsContentUri), bytes(editsMetadata))` |
| Entities Linked | `keccak256('GOVERNANCE.ENTITIES_LINKED')` | `bytes32(EntityAId)` | `abi.encode(bytes32(EntityBId))` |
| Entity Unlinked | `keccak256('GOVERNANCE.ENTITY_UNLINKED')` | `bytes32(EntityAId)` | `abi.encode(bytes32(EntityBId))` |
| Subspace Added | `keccak256('GOVERNANCE.SUBSPACE_ADDED')` | `bytes32(spaceId)`

Space Id of the subspace | `''`  - Empty |
| Subspace Removed | `keccak256('GOVERNANCE.SUBSPACE_REMOVED')` | `bytes32(spaceId)`

Space Id of the subspace | `''`  - Empty |
| Subspace Verified | `keccak256('GOVERNANCE.SUBSPACE_VERIFIED')` | `bytes32(spaceId)`

Space Id of the subspace | `''`  - Empty |
| Subspace Unverified | `keccak256('GOVERNANCE.SUBSPACE_UNVERIFIED')` | `bytes32(spaceId)`

Space Id of the subspace | `''`  - Empty |
| Subspace Related | `keccak256('GOVERNANCE.SUBSPACE_RELATED')` | `bytes32(spaceId)`

Space Id of the subspace | `''`  - Empty |
| Subspace Relation Broken | `keccak256('GOVERNANCE.SUBSPACE_RELATION_BROKEN')` | `bytes32(spaceId)`

Space Id of the subspace | `''`  - Empty |
| Subspace topic Declared | `keccak256('GOVERNANCE.SUBSPACE_TOPIC_DECLARED')` | `bytes32(bytes16(spaceId)) | bytes16(topicId) >> 128)`

Space Id + Topic Id | `''`  - Empty |
| Subspace topic Removed | `keccak256('GOVERNANCE.SUBSPACE_TOPIC_REMOVED')` | `bytes32(bytes16(spaceId)) | bytes16(topicId) >> 128)`

Space Id + Topic Id | `''`  - Empty |
| Upvoted | `keccak256('PERMISSIONLESS.UPVOTED')` | `bytes32(bytes4(objectType) << 224) | (bytes16(objectId) << 96)`

Object Type + Object Id | `abi.encode(uint16(version), bytes16(groupId), bytes16(spacePOV))` |
| Downvoted | `keccak256('PERMISSIONLESS.DOWNVOTED')` | `bytes32(bytes4(objectType) << 224) | (bytes16(objectId) << 96)`

Object Type+ Object Id | `abi.encode(uint16(version), bytes16(groupId), bytes16(spacePOV))` |
| Unvoted | `keccak256('PERMISSIONLESS.UNVOTED')` | `bytes32(bytes4(objectType) << 224) | (bytes16(objectId) << 96)`

Object Type + Object Id | `abi.encode(uint16(version), bytes16(groupId), bytes16(spacePOV))` |
| Commented | `keccak256('PERMISSIONLESS.COMMENTED')` | `bytes32(bytes4(objectType) << 224) | (bytes16(objectId) << 96)`

Object Type+ Object Id | `abi.encode(bytes(commentMetadata))` |

## Schema and Rules

- There exist two types of actions; governance and permissionless actions.
    - Governance actions concern those actions where onchain governance, using either the `DAOSpace`, `VerifierSpace`, a user’s EOA, or some third-party governance contracts, are required to mediate access control and execution permissions.
    - Permissionless actions concern those actions where onchain governance and permissions are not required.
- The `action` field is always the `keccak256` of the past-tense name of the action, printed in bold snake-case, and pre-fixed with the type of action that it is (e.g. `GOVERNANCE.`).
    - E.g. `GOVERNANCE.SPACE_ID_REGISTERED`
    - This field may **not** be left empty.
- The `topic` field provides more granular flags
    - E.g. Up-Vote/Down-Vote group and object Ids that aren’t passed in data.
    - This field may be left empty.
- The `data` is always `abi.encoded`, and either:
    - contains the payload for onchain execution
    - contains the payload for offchain execution
    - This field may also be left empty