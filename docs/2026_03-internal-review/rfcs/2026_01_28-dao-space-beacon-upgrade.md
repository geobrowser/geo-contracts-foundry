# Background

These contracts provide an onchain governance platform built on GEO, a new Arbitrum Orbit L3 that settles to Arbitrum One. The core purpose of the system is the emission of `Action` events from the `SpaceRegistry`, which serves as the central event emitter for all actions, which are then indexed, interpreted, and organised in a knowledge graph offchain. DAOs are one access control mechanism that integrates with this system to manage proposals, voting, and roles through registered spaces. The system consists of several key components:

- **`SpaceRegistry`**: Central registry managing space IDs, addresses, and action routing.
- **`DAOSpace`**: Core governance contract managing proposals, voting (fast path and slow path), and role attribution.
- **`VerifierSpace`**: Contract allowing one space to control, via signed messages, several spaces at once.
- **`Factories`**: Two factory contracts deploy DAOSpace and VerifierSpace instances via beacon proxies.

This architecture uses an upgradeable beacon proxy pattern, where multiple `DAOSpace` and `VerifierSpace` instances share a single implementation contract respectively that can be upgraded centrally. This allows for efficient upgrades across all deployed instances of either contract.

# General

This first beacon upgrade will introduce three focused improvements to the `DAOSpace` contract to enhance security and improve event emission consistency. The upgrade will be deployed together as a new implementation contract (v1.0.1) that will be set as the beacon implementation, automatically upgrading all existing `DAOSpace` proxy instances.

The new features in this upgrade will include:

1. **Proposal Version Validation in Voting:** Adding proposal version checking to mitigate against bait-and-switch attacks where proposal creators update proposals, but voters fail to realise they’re voting on a newer version.
2. **Membership Request Validation**: Adding a check to handle membership requests for spaces that are already members.
3. **Global Voting Settings Event**: Emitting a dedicated event when global voting settings are changed.

All changes will maintain backward compatibility with existing proposal data and voting mechanisms.

## **Requirements**

1. **Proposal Version Validation in Voting**: Votes must include and validate proposal version to mitigate against bait-and-switch attacks.
2. **Membership Request Validation**: `_requestMembership` must gracefully handle cases where the requested member is already a member.
3. **Global Voting Settings Event**: Emit a dedicated event when global voting settings are updated.
4. **Version Increase:** Update the versioning to help document the changes.
5. **Backward Compatibility**: All existing proposals, votes, state, and in-DAO access control must remain valid and functioning after the upgrade. 
6. **Testing and Scripts**: All new changes will be thoroughly tested, and new deployment scripts to facilitate the beacon upgrade will also be provided.

# In-Depth

## **1. Proposal Version Validation in Voting**

**Current Behaviour:**

- Votes are cast with only `(proposalId, voteOption)`.
- No version checking occurs, meaning all votes are assumed to be made for the most recent version of the proposal.
- Proposal creator can update proposals after votes are cast, invalidating those votes and reseting the proposal duration.
- This creates a bait-and-switch vulnerability where voters may think they’re voting on one version but they’re actually voting on an updated version.

**New Behaviour:**

- Vote data structure extended to include `(proposalId, voteOption, version)`.
- `_canVote` validates that `version` matches `latestProposalVersion[_proposalId]`.
- Returns `false` if versions don't match, which causes `_voteProposal` to revert with `CanNotVote`.
- Mitigates against bait-and-switch attacks where proposals updated after votes are cast.

**Smart Contract Changes:**

```solidity
// Modified _voteProposal to decode version and pass to _canVote
function _voteProposal(bytes16 _fromSpaceId, bytes calldata _data) internal virtual {
    // Decode data to construct vote (now includes version)
    (bytes16 _proposalId, VoteOption _voteOption, uint8 _version) = 
        abi.decode(_data, (bytes16, VoteOption, uint8));
    // Ensure _fromSpaceId can vote (now includes version check)
    if (!_canVote(_fromSpaceId, _proposalId, _voteOption, _version)) revert CanNotVote();
    
    // ... rest of voting logic
}

// Modified _canVote function to include version parameter
function _canVote(
    bytes16 _spaceId,
    bytes16 _proposalId,
    VoteOption _voteOption,
    uint8 _version
) internal view virtual returns (bool) {
    Proposal storage proposal_ = _getLatestProposalStorage(_proposalId);
    // New version check - validate that vote is for the current proposal version
    DAOSpaceStorage storage $ = _getDAOSpaceStorage();
    uint8 _currentVersion = $.latestProposalVersion[_proposalId];
    if (_version != _currentVersion) return false;
    
    // ... rest of can vote logic
}
```

- Note that `fetch` will also require a small update also given these changes. Namely, that the decoded `_data` will include the proposal version, `_version`. Although this does not change what `fetch` returns, which will remain the `_proposalId`.

## 2. Membership Request Validation

**Current Behaviour:**

- `_requestMembership` creates a proposal to add a member without checking if they are already a member.
- Can create duplicate membership proposals for spaces that are already members.

**New Behaviour:**

- `_requestMembership` checks if `_newMemberSpaceId` already has the `MEMBER` role.
- Reverts with `InvalidSpaceIdForRole` if member already exists.

**Smart Contract Changes:**

```solidity
function _requestMembership(bytes16 _fromSpaceId, bytes calldata _data) internal virtual {
    (bytes16 _proposalId, bytes16 _newMemberSpaceId) = abi.decode(_data, (bytes16, bytes16));
    
    // New check to handle the already-member case
    if (hasRole(MEMBER, _newMemberSpaceId)) revert InvalidSpaceIdForRole();
    
    // ... rest of the function logic
}
```

## 3. Global Voting Settings Event

**Current Behaviour:**

- The `PROPOSAL_SETTINGS_SELECTED` action is only emitted with each proposal that is created.
- No dedicated action for global voting settings changes.

**New Behaviour:**

- Add new action `VOTING_SETTINGS_UPDATED` emitted when the global settings change.
- Emitted when `updateVotingSettings` is called.
- Allows off-chain systems to track global voting settings changes separately from proposal settings.

**Smart Contract Changes:**

```solidity
// New action constant in ActionsConstants.sol
bytes32 constant VOTING_SETTINGS_UPDATED = keccak256('GOVERNANCE.VOTING_SETTINGS_UPDATED');

function _updateVotingSettings(VotingSettings memory _votingSettings) internal virtual {
    // ... existing function logic
    
    // New event emission
    _ping(
        ActionsConstants.VOTING_SETTINGS_UPDATED,
        bytes32(0),
        abi.encode(_votingSettings)
    );
}
```

## **4. Version Increase**

Update the version to maintain clarity over the use of the new implementation.

**Smart Contract Changes:**

```solidity
function version() public pure virtual returns (string memory _version) {
    _version = '1.0.1';
}
```

## Event Changes

New Events:

- `VOTING_SETTINGS_UPDATED`: Emitted when global voting settings change via `_updateVotingSettings`.

Modified Events:

- `PROPOSAL_VOTED`: Now includes proposal version in the vote data structure.

# External Requirements

Indexer and user interface changes are also required with this update:

- [ ]  Firstly, the indexer will be required to know that the vote data passed to the contract will now contain the proposal version that the editor is voting for. This change will be reflected in the modified `PROPOSAL_VOTED` event.
- [ ]  Secondly, the indexer will also be required to know that the `VOTING_SETTINGS_UPDATED` event is emitted when a DAO updates their global voting settings via governance.
- [ ]  Thirdly, and crucially, the UI will need to fetch and pass the proposal version when voting; voters must be made aware of the version they’re voting on and what the impacts of it passing will be.

**We should NOT implement a system where this versioning is abstracted away from users, because doing so would defeat the purpose of this added check.**

# Milestones and Estimates

This project is estimated to take one solidity developer 1 week to implement, including updating tests and deployment scripts.

# Open Questions and Thoughts

- 
