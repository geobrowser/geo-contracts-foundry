This document outlines how to both encode and interpret an `Action` event from the `SpaceRegistry` contract.

```solidity
/**
 * @notice Emitted from `SpaceRegistry` (`enter`, lifecycle methods, `setPaymentManager`, `setL2IncentivesPayer`, `overrideAction`, re-entrant `enter` e.g. `DAOSpace._ping`)
 */
event Action(
  bytes16 indexed fromSpaceId,
  bytes16 indexed toSpaceId,
  bytes32 indexed action,
  bytes32 indexed subject,
  bytes data
) anonymous;
```

| Action Definitions | Action: `bytes32` | Subject: `bytes32` | Data: `bytes` |
| --- | --- | --- | --- |
| Space Id Registered | `keccak256('GOVERNANCE.SPACE_ID_REGISTERED')` | `bytes32(bytes20(account))` | empty |
| Space Id Archived | `keccak256('GOVERNANCE.SPACE_ID_ARCHIVED')` | `bytes32(bytes20(msg.sender))` | empty |
| Space Id Recovered | `keccak256('GOVERNANCE.SPACE_ID_RECOVERED')` | `bytes32(bytes20(msg.sender))` | empty |
| Space Id Cleared | `keccak256('GOVERNANCE.SPACE_ID_CLEARED')` | `bytes32(bytes20(msg.sender))` | empty |
| Space Id Migration Proposed | `keccak256('GOVERNANCE.SPACE_ID_MIGRATION_PROPOSED')` | `bytes32(bytes20(newAccount))` | empty |
| Space Id Migrated | `keccak256('GOVERNANCE.SPACE_ID_MIGRATED')` | `bytes32(bytes20(msg.sender))` (acceptor) | empty |
| Space Id Overridden | `keccak256('GOVERNANCE.SPACE_ID_OVERRIDDEN')` | `bytes32(bytes20(account))` | empty |
| Space Type Declared | `keccak256('GOVERNANCE.SPACE_TYPE_DECLARED')` | `_type` e.g. `keccak256('DAO_SPACE')` | `_version` e.g. `abi.encode('1.0.0')` |
| Permissionless Action Added | `keccak256('GOVERNANCE.PERMISSIONLESS_ACTION_ADDED')` | `keccak256('PERMISSIONLESS.<NAME>')` allowed | empty |
| Permissionless Action Removed | `keccak256('GOVERNANCE.PERMISSIONLESS_ACTION_REMOVED')` | `keccak256('PERMISSIONLESS.<NAME>')` disallowed | empty |
| Payment Manager Set | `keccak256('GOVERNANCE.PAYMENT_MANAGER_SET')` | `bytes32(bytes20(paymentManager))` | empty |
| L2 Incentives Payer Set | `keccak256('GOVERNANCE.L2_INCENTIVES_PAYER_SET')` | `bytes32(targetId)` | `abi.encode(address payer, uint256 l2MessageId)` |
| Voting Settings Updated | `keccak256('GOVERNANCE.VOTING_SETTINGS_UPDATED')` | `bytes32(0)` | `abi.encode(VotingSettings)` |
| Proposal Created | `keccak256('GOVERNANCE.PROPOSAL_CREATED')` | `bytes32(proposalId)` | `abi.encode(bytes16 proposalId, VotingMode, IDAOSpace.Action[])` |
| Proposal Settings Selected | `keccak256('GOVERNANCE.PROPOSAL_SETTINGS_SELECTED')` | `bytes32(proposalId)` | `abi.encode(ProposalParameters)` |
| Proposal Updated | `keccak256('GOVERNANCE.PROPOSAL_UPDATED')` | `bytes32(proposalId)` | `abi.encode(bytes16 proposalId, VotingMode, IDAOSpace.Action[])` |
| Proposal Voted | `keccak256('GOVERNANCE.PROPOSAL_VOTED')` | `bytes32(proposalId)` | `abi.encode(bytes16 proposalId, uint8 proposalVersion, VoteOption)` |
| Proposal Executed | `keccak256('GOVERNANCE.PROPOSAL_EXECUTED')` | `bytes32(proposalId)` | `abi.encode(bytes16 proposalId)` |
| Space Left | `keccak256('GOVERNANCE.SPACE_LEFT')` | `MEMBER` / `EDITOR` role id | `abi.encode(bytes32 role)` |
| Editor Added | `keccak256('GOVERNANCE.EDITOR_ADDED')` | `bytes32(editorSpaceId)` | empty |
| Editor Removed | `keccak256('GOVERNANCE.EDITOR_REMOVED')` | `bytes32(editorSpaceId)` | empty |
| Member Added | `keccak256('GOVERNANCE.MEMBER_ADDED')` | `bytes32(memberSpaceId)` | empty |
| Member Removed | `keccak256('GOVERNANCE.MEMBER_REMOVED')` | `bytes32(memberSpaceId)` | empty |
| Membership Requested | `keccak256('GOVERNANCE.MEMBERSHIP_REQUESTED')` | `bytes32(proposalId)` | `abi.encode(bytes16 proposalId, bytes16 newMemberSpaceId)` |
| Space Fast Path Restricted | `keccak256('GOVERNANCE.SPACE_FAST_PATH_RESTRICTED')` | `bytes32(restrictedSpaceId)` | `abi.encode(bytes16 restrictedSpaceId)` |
| Space Fast Path Unrestricted | `keccak256('GOVERNANCE.SPACE_FAST_PATH_UNRESTRICTED')` | `bytes32(oldRestrictedSpaceId)` | `abi.encode(bytes16 oldRestrictedSpaceId)` |
| Flagged | `keccak256('GOVERNANCE.FLAGGED')` | `bytes32(TOPIC_UUID)` | `abi.encode(bytes(flaggedUri))` |
| Unflagged | `keccak256('GOVERNANCE.UNFLAGGED')` | `bytes32(TOPIC_UUID)` | `abi.encode(bytes(unflaggedUri))` |
| Topic Set | `keccak256('GOVERNANCE.TOPIC_SET')` | `bytes32(TOPIC_UUID)` | empty |
| Topic Unset | `keccak256('GOVERNANCE.TOPIC_UNSET')` | `bytes32(TOPIC_UUID)` | empty |
| Edits Published | `keccak256('GOVERNANCE.EDITS_PUBLISHED')` | `bytes32(TOPIC_UUID)` (optional) | `abi.encode(bytes(editsContentUri), bytes(editsMetadata))` |
| Entities Linked | `keccak256('GOVERNANCE.ENTITIES_LINKED')` | `bytes32(EntityAId)` | `abi.encode(bytes32(EntityBId))` |
| Entities Unlinked | `keccak256('GOVERNANCE.ENTITIES_UNLINKED')` | `bytes32(EntityAId)` | `abi.encode(bytes32(EntityBId))` |
| Subspace Added | `keccak256('GOVERNANCE.SUBSPACE_ADDED')` | `bytes32(spaceId)` | empty |
| Subspace Removed | `keccak256('GOVERNANCE.SUBSPACE_REMOVED')` | `bytes32(spaceId)` | empty |
| Subspace Verified | `keccak256('GOVERNANCE.SUBSPACE_VERIFIED')` | `bytes32(spaceId)` | empty |
| Subspace Unverified | `keccak256('GOVERNANCE.SUBSPACE_UNVERIFIED')` | `bytes32(spaceId)` | empty |
| Subspace Related | `keccak256('GOVERNANCE.SUBSPACE_RELATED')` | `bytes32(spaceId)` | empty |
| Subspace Unrelated | `keccak256('GOVERNANCE.SUBSPACE_UNRELATED')` | `bytes32(spaceId)` | empty |
| Subspace Topic Set | `keccak256('GOVERNANCE.SUBSPACE_TOPIC_SET')` | packed `bytes32`: high 16 bytes = `spaceId`, low 16 bytes = `topicId` | empty |
| Subspace Topic Unset | `keccak256('GOVERNANCE.SUBSPACE_TOPIC_UNSET')` | packed `bytes32`: high 16 bytes = `spaceId`, low 16 bytes = `topicId` | empty |
| Upvoted | `keccak256('PERMISSIONLESS.UPVOTED')` | 4-byte `objectType` + `bytes16` `objectId` packed (off-chain convention) | e.g. `abi.encode(uint16 version, bytes16 groupId, bytes16 spacePOV)` |
| Downvoted | `keccak256('PERMISSIONLESS.DOWNVOTED')` | 4-byte `objectType` + `bytes16` `objectId` packed (off-chain convention) | e.g. `abi.encode(uint16 version, bytes16 groupId, bytes16 spacePOV)` |
| Unvoted | `keccak256('PERMISSIONLESS.UNVOTED')` | 4-byte `objectType` + `bytes16` `objectId` | e.g. `abi.encode(uint16 version, bytes16 groupId, bytes16 spacePOV)` |
| Commented | `keccak256('PERMISSIONLESS.COMMENTED')` | 4-byte `objectType` + `bytes16` `objectId` | e.g. `abi.encode(bytes commentMetadata)` |

## Schema and Rules

- There exist two types of actions; governance and permissionless actions.
    - Governance actions concern those actions where onchain governance, using either the `DAOSpace`, `VerifierSpace`, a user’s EOA, or some third-party governance contracts, are required to mediate access control and execution permissions.
    - Permissionless actions concern those actions where onchain governance and permissions are not required.
- The `action` field is always the `keccak256` of the past-tense name of the action, printed in bold snake-case, and pre-fixed with the type of action that it is (e.g. `GOVERNANCE.`).
    - E.g. `GOVERNANCE.SPACE_ID_REGISTERED`
    - This field may **not** be left empty.
- The `subject` field provides more granular flags
    - E.g. Up-Vote/Down-Vote group and object Ids that aren’t passed in data.
    - This field may be left empty.
- The `data` field is normally `abi.encoded` structured payload (or empty), for on- or off-chain execution.
- On proposal creation (and update), `ProposalParameters.startDate`, `lastDate`, and `executeBy` are zero in the emitted settings. They are snapshotted from `VotingSettings` and re-emitted on the first cast vote; a first fast-path `No` (escalation) sets timers and emits slow-path settings once.
- **L2 incentives target ids** (e.g. `L2_INCENTIVES_PAYER_SET` subject, Arbitrum `PaymentManager.setPayer`, merkle leaves) use `bytes32(bytes16 spaceId)` — the GEO space UUID from `SpaceRegistry`, not the space contract address. This matches geo-incentives `StakingRegistry` space targets and is stable across space migration.

Schema above is the intended convention for callers and the table, not something the registry enforces on every emit.

## Exceptions

- Some `Action` events may have modified `_data` fields when emitted via the `overrideAction` function. This allows indexers to identify those actions that occurred before transplantation occurred. These modified events are:
    - Proposal Created: `abi.encode(bytes16 proposalId, VotingMode, IDAOSpace.Action[], bool proposalTransplanted)`
