# Background

The Geo governance contracts are centred around the emission of `Action` events emitted from the `SpaceRegistry`, which are then indexed and organised in a knowledge graph offchain. Spaces that wish to govern the curation of their knowledge collectively do so via the `DAOSpace` contract, which implements a dual-path proposal and voting system: 

- **Fast Path**: Enforces a flat threshold voting system with immediate execution. Only editors can create these proposals, which are limited to single, pre-approved actions (such as `addMember`, `removeMember`, `ping`). Any `No` vote escalates the proposal to the slow path.
- **Slow Path**: Enforces a majority voting system with the potential for early execution if sufficient support is received. For contentious proposals, a fixed `duration` of time must elapse before execution can occur, whereas uncontentious proposals can be executed early if the `slowPathAbsoluteThreshold` check has been satisfied. Both members and editors can create these proposals, and a minimum `quorum` of participation must be reached under both early and slow execution options.

While members can create slow path proposals that contribute to a DAO’s knowledge, the restriction from the fast path may nonetheless prove unhelpful in some circumstances. This is primarily because enforcing the slow path could undermine the productive and timely collaboration between members and editors. 

As a result, and to provide DAOs with greater flexibility over their internal processes, several changes will be made to allow for members to create fast path proposals.

# General

In addition to allowing members to create fast path proposals, editors (and only editors) will be able to restrict members from using the fast path if deemed appropriate. Furthermore, a governance setting will be introduced that defines the default restriction status for members in relation to the fast path. This will allow DAOs to retain the current behaviour where new members may only use the slow path, while providing flexibility for certain members to be granted permission to use the fast path in the future. 

Importantly, under the proposed changes, only editors will be permitted to vote on proposals, and only editors will be able to restrict other members and editors from accessing the fast path. To un-restrict a member or editor from the fast path, a slow path DAO proposal must be executed as is currently the case.

Thus, the proposed changes are as follows:

| Current behaviour | Proposed behaviour |
| --- | --- |
| Only editors can submit fast path proposals. | Editors and members can submit fast path proposals. |
| Members must use slow path for all proposals. Editors can be restricted from using fast path by any editor. | Members can use fast path for content and membership operations. Members and editors can be restricted from using fast path by any editor. |
| Editors are not restricted from the fast path by default. | Editors are not restricted from the fast path by default, but members can be. |

## **Requirements**

- Allow members to create fast path proposals, and for them to be restricted by editors.
- Provide a governance setting to define default fast-path privilege access for new members.
- Updated unit, integration, and invariant tests.

# In-Depth

Outlined below the list of changes required to support this new functionality, although some minor and implicit changes have been omitted for the sake of clarity and conciseness.

<aside>
⚠️

What is presented below is neither the final nor the exhaustive implementation; however, it serves as a reference for how the modifications are intended to work.

</aside>

## Smart Contracts

To begin with, an additional boolean variable will be added to the `VotingSettings` struct, `defaultFastPathAccessForMembers`. This variable will provide a switch for DAOs to define whether newly added members can access the fast path or not; `true` if they can, `false` if not.

<aside>
📔

Note: The DAO can still grant members fast path access even if the `defaultFastPathAccessForMembers` is set to false. This variable only defines the default behaviour for newly added members.

</aside>

```solidity
struct VotingSettings {
  uint256 slowPathPercentageThreshold;
  uint256 slowPathAbsoluteThreshold;
  uint256 fastPathFlatThreshold;
  uint256 quorum;
  uint256 duration;
  bool defaultFastPathAccessForMembers;
}
```

This new storage variable is then used when members are added to the DAO; where when `defaultFastPathAccessForMembers` equals false, members are immediately restricted from using the fast path.

```solidity
function _addMember(bytes16 _newMemberSpaceId) internal virtual {
  if (hasRole(MEMBER, _newMemberSpaceId)) revert InvalidSpaceIdForRole();
  DAOSpaceStorage storage $ = _getDAOSpaceStorage();
  if (!$.defaultFastPathAccessForMembers) _grantRole(FAST_PATH_RESTRICTED, _newMemberSpaceId);
  _grantRole(MEMBER, _newMemberSpaceId);
  _ping(ActionsConstants.MEMBER_ADDED, bytes32(_newMemberSpaceId), '');
}
```

Finally, the `_checkProposalPath` function will be updated to allow members to access the fast path when creating proposals.

```solidity
function _checkProposalPath(
  bytes16 _fromSpaceId,
  VotingMode _votingMode,
  Action[] memory _actions
) internal virtual returns (uint256 _supportThreshold) {
  DAOSpaceStorage storage $ = _getDAOSpaceStorage();
  if (_votingMode == VotingMode.Slow) {
    // Slow path
    // Only members or editors can create slow path proposals
    if (!(hasRole(MEMBER, _fromSpaceId) || hasRole(EDITOR, _fromSpaceId))) revert InvalidFromSpace();
    _supportThreshold = $.votingSettings.slowPathPercentageThreshold;
  } else {
    // Fast path
    // Only members or editors can create fast path proposals
    if (!(hasRole(MEMBER, _fromSpaceId) || hasRole(EDITOR, _fromSpaceId))) revert InvalidFromSpace();
    // Checks from space is allowed to use fast path
    if (hasRole(FAST_PATH_RESTRICTED, _fromSpaceId)) revert FastPathRestricted();
    // limit the actions to one call
    if (_actions.length != 1) revert OneActionForFastPath();
    // limit to only valid fast path actions
    if (!$.actionIsFastPathValid[bytes4(_actions[0].data)]) revert InvalidAction();
    // limit the target to only this address
    if (_actions[0].to != address(this)) revert InvalidTarget();
    // limit the transfer of funds
    if (_actions[0].value != 0) revert InvalidFundsTransfer();
    _supportThreshold = $.votingSettings.fastPathFlatThreshold;
  }
}
```

# Resources

- [Idea: Fast Path Proposals for Members](https://www.notion.so/Idea-Fast-Path-Proposals-for-Members-30c9a4c092c781b192a9eee0197f6008?pvs=21)
- [Batching Transactions in Privy/Safe Setup](https://www.notion.so/Batching-Transactions-in-Privy-Safe-Setup-30d273e214eb80b08faae12e508fb0c5?pvs=21)

# Milestones and Estimates

It is estimated to take one solidity developer 1-1.5 week/s to implement the changes outlined, including full unit, integration, and invariant testing.

The security team’s internal review effort is still to be defined.

# Open Questions and Thoughts

- 

# Signatures

- @Cooki 0x at February 25, 2026