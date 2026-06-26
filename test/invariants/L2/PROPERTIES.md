## 1. StakingManager

`StakingManager` tracks user stake, per-target allocations, and pending unstake requests. Handlers fuzz stake, stakeFor, allocate, deallocate, reallocate, requestUnstake, unstake, and unsolicited GEO transfers; council handlers toggle active targets via `StakingRegistry`.

| ID | Invariant |
|----|-----------|
| SM-INV-1 | Sum of tracked users' `totalUserStake` equals global `totalStaked` |
| SM-INV-2 | Sum of tracked users' `totalUserAllocation` equals global `totalAllocated` |
| SM-INV-3 | `totalAllocated + totalPendingUnstake <= totalStaked` (global and per-user) |
| SM-INV-4 | Per-user sum of per-target `allocations` equals `totalUserAllocation` |
| SM-INV-5 | Per-target sum of user `allocations` equals `totalTargetAllocation` |
| SM-INV-6 | Sum of tracked users' `totalUserPendingUnstake` equals global `totalPendingUnstake` |
| SM-INV-7 | Sum of open unstake request amounts equals `totalPendingUnstake` |
| SM-INV-8 | ERC-20 balance held by the manager is at least `totalStaked` |
| SM-INV-9 | Per-user sum of open unstake request amounts equals `totalUserPendingUnstake` |
| SM-INV-10 | Sum of tracked targets' `totalTargetAllocation` equals global `totalAllocated` |
| SM-INV-11 | `reallocate` does not change `totalAllocated` or the caller's `totalUserAllocation` |
| SM-INV-12 | `stakedGEOToken.balanceOf(user) == totalUserStake(user)` for tracked users |
