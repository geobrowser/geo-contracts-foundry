# Background

The Geo governance contracts are centred around the emission of `Action` events emitted from the `SpaceRegistry`, which are then indexed and organised in a knowledge graph offchain. Spaces that wish to govern the curation of their knowledge collectively do so via the `DAOSpace` contract, which implements a dual-path proposal and voting system: 

- **Fast Path**: Enforces a flat threshold voting system with immediate execution. Only editors can create these proposals, which are limited to single, pre-approved actions (such as `addMember`, `removeMember`, `ping`). Any `No` vote escalates the proposal to the slow path.
- **Slow Path**: Enforces a majority voting system with a fixed duration of time that must elapse before execution can occur. Both members and editors can create these proposals, and a minimum quorum of participation must be reached in addition to satisfying the majority voting threshold.

Because execution on the slow path is restricted until the full voting duration has passed, slow path proposals that have unanimous or near-universal support must nonetheless wait for the voting period to end. This creates unnecessary friction for users, and is a particularly acute problem with DAO Spaces that have only a single editor, wherein the delayed execution serves no purpose whatsoever. 

Thus, to allow for faster execution of widely supported slow path proposals, the slow path will be extended with a mechanism that allows for immediate execution given a high degree of support.

# General

To improve the user experience of the slow path a new storage, `slowPathAbsoluteThreshold`, variable will be added to the `VotingSettings` to provide DAO Spaces with an alternative mechanism to allow for early execution. Similar to the percentage-based threshold already used in the slow path, the `slowPathAbsoluteThreshold` will compare the percentage of `YES` votes to the total number of editors, and if the `YES` votes exceed the `slowPathAbsoluteThreshold`, the proposal will be executable immediately. If, however, the percentage of `YES` votes does not, and never, exceeds the `slowPathAbsoluteThreshold`, the proposal may still be executable if the `slowPathPercentageThreshold` and `quorum` are satisfied as before. Therefore, the `slowPathAbsoluteThreshold` will provide an alternative and early execution path while retaining the former slow path execution logic.

## **Requirements**

- Add support to the slow path for `slowPathAbsoluteThreshold` early execution.
- Updated unit, integration, and invariant tests.

# In-Depth

Outlined below the list of changes required to support this new functionality, although some minor and implicit changes have been omitted for the sake of clarity and conciseness.

<aside>
⚠️

What is presented below is neither the final nor the exhaustive implementation; however, it serves as a reference for how the modifications are intended to work.

</aside>

## Smart Contracts

To begin with, the `VotingSettings` and `ProposalParameters` will both be updated with new storage variables, `slowPathAbsoluteThreshold` and `absoluteThreshold`. As is the case with the other voting settings, when a proposal is created, the `ProposalParameters` will be updated with the `slowPathAbsoluteThreshold` at the time of creation.

```solidity
// Global DAO voting settings
struct VotingSettings {
  uint256 slowPathPercentageThreshold;
  uint256 slowPathAbsoluteThreshold;
  uint256 fastPathFlatThreshold;
  uint256 quorum;
  uint256 duration;
}

// Local proposal settings
struct ProposalParameters {
  VotingMode votingMode;
  uint256 supportThreshold;
  uint256 absoluteThreshold;
  uint256 quorum;
  uint256 startDate;
  uint256 lastDate;
}
```

<aside>
🚨

Note, also that the `slowPathAbsoluteThreshold` is intended to be used as a high-bar requirement for early execution of slow path proposals.

</aside>

In addition, and crucially, the `isSupportThresholdReached` function will be updated with a new branch in the slow path logic to allow for the proposal to execute before the duration has expired. Importantly, this `slowPathAbsoluteThreshold` check occurs after the quorum check, which enforces the condition that for a slow path proposal to execute early it must satisfy both the quorum and the added absolute threshold checks.

```solidity
/// @inheritdoc IDAOSpace
function isSupportThresholdReached(bytes16 _proposalId)
  public
  view
  virtual
  returns (bool _isSupportThresholdReached)
{
  DAOSpaceStorage storage $ = _getDAOSpaceStorage();
  Proposal storage proposal_ = _getLatestProposalStorage(_proposalId);
  uint256 supportThreshold =
    (proposal_.parameters.supportThreshold == 0) ? 0 : proposal_.parameters.supportThreshold - 1;
  if (proposal_.parameters.votingMode == VotingMode.Slow) {
	  // Slow path
		// Quorum check
    if (proposal_.tally.yes + proposal_.tally.no + proposal_.tally.abstain < proposal_.parameters.quorum) {
      return false; <- Notice this has been moved up
    }
	  // Absolute threshold check to allow for early execution
    if (proposal_.tally.yes * RATIO_BASE > proposal_.parameters.absoluteThreshold * $.totalEditors) return true;
    // Duration check
    if (block.timestamp <= proposal_.parameters.lastDate) return false;
    // Threshold percentage calculation
    if ((RATIO_BASE - supportThreshold) * proposal_.tally.yes > supportThreshold * proposal_.tally.no) return true;
  } else {
    // Fast path
    // Threshold flat calculation
    if (proposal_.tally.yes > supportThreshold) return true;
  }
}
```

And finally, the `_updateVotingSettings` will include an additional check to ensure that the `slowPathAbsoluteThreshold` cannot exceed the `RATIO_BASE`. 

<aside>
📒

If the `slowPathAbsoluteThreshold` is set to equal `RATIO_BASE`, this is equivalent to disabling the early execution logic (because total `YES` votes will never exceed 100%). 

</aside>

```solidity
function _updateVotingSettings(VotingSettings memory _votingSettings) internal virtual {
  DAOSpaceStorage storage $ = _getDAOSpaceStorage();
  if (_votingSettings.slowPathPercentageThreshold > RATIO_BASE) revert InvalidSetting();
  if (_votingSettings.slowPathAbsoluteThreshold > RATIO_BASE) revert InvalidSetting();
  if (_votingSettings.fastPathFlatThreshold > $.totalEditors) revert InvalidSetting();
  if (_votingSettings.quorum > $.totalEditors) revert InvalidSetting();
  if (_votingSettings.duration < MINIMUM_VOTING_DURATION) revert InvalidSetting();
  $.votingSettings = _votingSettings;
}
```

# External Requirements

- The `PROPOSAL_SETTINGS_SELECTED` action event will now also include the `absoluteThreshold` in the `_data` field:
    
    ```solidity
    _ping(
      ActionsConstants.PROPOSAL_SETTINGS_SELECTED,
      bytes32(_proposalId),
      abi.encode(
        proposal_.parameters.startDate,
        proposal_.parameters.lastDate,
        proposal_.parameters.votingMode,
        proposal_.parameters.quorum,
        proposal_.parameters.supportThreshold,
        proposal_.parameters.absoluteThreshold
      );
    ```
    
    - The indexer should store this new parameter
    - The UI should be aware of this during space creation and voting settings update
    - Anything else?
- To assist with the user interface experience, it would be helpful to add front-end logic that could batch a vote and an execution transaction together on the slow path if the `slowPathAbsoluteThreshold` check has been satisfied.

# Scenarios

Given this design, the following scenarios become possible:

- **Uncontentious early execution**
    - A slow path proposal is created in a DAO with only one editor
    - The editor votes `YES` and the proposal can be executed immediately, bypassing the otherwise enforced `duration` delay.
- **Fast path escalation and early execution**
    - A fast path proposal is created.
    - One editor votes `NO` quickly, and pushes the proposal to the slow path.
    - A sufficient number of other editors vote `YES`, and the proposal is executed rapidly regardless.
- **Fast path escalation and no early execution**
    - A fast path proposal is created.
    - One editor votes `NO`, and pushes the proposal to the slow path.
    - A sufficient number of other editors vote `NO`, which ensures that early execution is disabled for this proposal
        - E.g. if `slowPathAbsoluteThreshold` is set to 70% and one editor out of a total of three votes `NO`.
        - Alternatively, if the `slowPathAbsoluteThreshold` is set to 51%, there are ten editors, and a `quorum` of 7 is required; 6 editors vote `YES`, satisfying the `slowPathAbsoluteThreshold` check but not the `quorum` check.

# Resources

- [Batching Transactions in Privy/Safe Setup](https://www.notion.so/Batching-Transactions-in-Privy-Safe-Setup-30d273e214eb80b08faae12e508fb0c5?pvs=21)

# Milestones and Estimates

It is estimated to take one solidity developer 1-1.5 week/s to implement the changes outlined, including full unit, integration, and invariant testing.

The security team’s internal review effort is still to be defined.

# Open Questions and Thoughts

- Should we have another check when the voting settings are updated to enforce that the `slowPathAbsoluteThreshold` is greater than `slowPathPercentageThreshold`?
    - Or should we allow DAOs the flexibility to invert this relationship if they wish?
    - There are a few options for limits we could place on the `slowPathAbsoluteThreshold`:
        - No limit.
        - Enforce, `slowPathAbsoluteThreshold` > `slowPathPercentageThreshold`.
        - Enforce, 50% < `slowPathAbsoluteThreshold` < 100%.
    - **Decision**: given that the `quorum` check is now also enforced, DAOs are free to set their own `slowPathAbsoluteThreshold` to whatever they wish.

# Signatures

- @Cooki 0x at February 20, 2026
- @Joxes at February 20, 2026
- @Yaco 0x at February 20, 2026