# Master tech design — GEO contracts (source of truth)

This document is the **primary reference** for what the GEO contracts found in this repo are for, how they behave, and how the pieces fit together. Use this document for when you need the story end-to-end; use the RFCs in `rfcs/` for proposal-level background, requirements, and implementation sketches on specific topics. 

---

## 1. System in one page

- **`SpaceRegistry`** — Single entry point for all space interactions. Users and spaces submit work through **`enter`** on the registry (not by calling **`write`** on a space, which accepts only the registry). It validates `from` (via `verify` when `from ≠ msg.sender`), emits the canonical anonymous **`Action`** event (`fromId`, `toId`, `action`, `topic`, `data`), and for inter-space actions routes **`fetch`** then **`write`** on the target space. It holds the bi-directional **space id ⇔ address** mapping (registration, clear, migration; archive/recovery extends lifecycle without dropping recoverability).
- **`DAOSpace`** — Default on-chain governance contract that supports proposals, voting, and member/editor roles. The **`write`** function permits only the registry as the caller, and the `action` input selects handlers. **Dual-path governance**: fast path (flat yes threshold via **`flatSupportThreshold`**, single action, immediate execution when threshold met; a **No** vote can escalate to slow path) and slow path (duration, quorum, **`partialPercentageSupportThreshold`** for late yes/no; optional **early execution** when **`universalPercentageSupportThreshold`** is met after quorum—see §4).
- **`DAOSpaceFactory` / `VerifierSpaceFactory`** — Deploy beacon-proxy spaces and register them with the registry. **`DAOSpace`** logic is shared via **`UpgradeableBeacon`**; factories/registry use UUPS where applicable.
- **`VerifierSpace`** — Lets one controlling identity act **as** multiple spaces via EIP-712 **`verify`** when the caller is not the `from` space’s address (out of scope for some audits; behavior is unchanged in principle).

**Action taxonomy** — Governance vs permissionless actions, naming, and `Action` field rules are specified in `rfcs/2026_01_01-geo-action-definitions-v1.md`. On-chain constants live in `ActionsConstants.sol`.

---

## 2. Original use cases (user stories)

These are the baseline intents the singleton architecture is built to support.

### On-chain identity and management

| Use case | Rough mechanism |
| --- | --- |
| Create a DAO or verifier space | Factory deploys proxy, initializes, registers a **`bytes16`** space id with **`SpaceRegistry`**. |
| Control many spaces from one EOA | Deploy multiple **`VerifierSpace`** instances; call **`enter`** with signatures so **`verify`** authorizes `from ≠ sender`. |
| Reader / personal identity without a space contract | **`registerSpaceId`** maps the EOA to a deterministic id. |
| Leave a space | **`enter`** with **`SPACE_LEFT`** → registry emits **`Action`**, then **`DAOSpace.write`** removes the role. |
| Migrate identity | **`proposeSpaceMigration`** / **`acceptSpaceMigration`** update the id ↔ address mapping. |

### DAO governance

| Use case | Rough mechanism |
| --- | --- |
| Propose work (edits, members, editors, …) | **`enter`** with **`PROPOSAL_CREATED`**; payload encodes operations and voting mode. |
| Vote | **`enter`** with **`PROPOSAL_VOTED`** (editors vote; see §3). |
| Execute | **`enter`** with **`PROPOSAL_EXECUTED`** when thresholds/time rules pass; stored calls run and may **`ping`** back into the registry for follow-on **`Action`** emissions. |
| Update a proposal before execution | **`PROPOSAL_UPDATED`** creates a new version (votes reset; **latest** version is tracked, and new votes must target the current version). |
| Restrict fast-path participation | Editors can restrict fast path; lifting restriction is via **slow-path** execution. |

### Knowledge graph signals (permissionless)

| Use case | Rough mechanism |
| --- | --- |
| Upvote / downvote / unvote / comment | **`enter`** with **`PERMISSIONLESS.*`** actions; no **`fetch`/`write`** on a space—event only for the indexer. |
| Read content | Off-chain API/KG (fed by decoded **`Action`** events)—no tx required. |

---

## 3. Governance behaviour FAQ (reference)

- **Who proposes?** — **Members and editors** can create **slow-path** proposals. **Fast-path** proposals can be created by members and editors who are **not** **`FAST_PATH_RESTRICTED`**; when **`disableFastPathAccessForNewMembers`** is **true**, newly added **non-editor** members are **`FAST_PATH_RESTRICTED`** by default.
- **Who votes?** — **Editors only** (including on proposals created by members).
- **What's the fast path?** — A proposal that enforces one on-chain operation per proposal; valid selectors are configured per DAO; execution when yes tally exceeds **`flatSupportThreshold`** (after the contract’s effective-threshold helper); **`ping`** is the generic path to emit further **`Action`** kinds (including those previously tied to dedicated entrypoints—see §4).
- **What's the slow path?** — Voting runs for a fixed window ending at **`lastDate`**. Execution requires **quorum** first. If quorum is met, **early execution** is allowed when **`yes * RATIO_BASE > _computeEffectiveSupportThreshold(universalPercentageSupportThreshold) * totalEditors`**. If that bar is not met in time, execution waits until after **`lastDate`**, then passes only if **`partialPercentageSupportThreshold`** is satisfied (yes vs no). Details: **`isSupportThresholdReached`** in `DAOSpace.sol` / **`IDAOSpace`** (see §4).

---

## 4. Implementation pointers (where to look in code)

- **Slow-path thresholds and early execution** — **`isSupportThresholdReached`** in **`DAOSpace`** defines the order of **quorum**, **`lastDate`**, **`universalPercentageSupportThreshold`** (including **`_computeEffectiveSupportThreshold`**), and **`partialPercentageSupportThreshold`**. **`IDAOSpace`** and NatSpec on those settings are the interface-level reference.

- **`ping` and follow-on `Action` emissions** — **`DAOSpace.ping`** (callable only with the DAO role) invokes **`_ping`**, which calls **`SpaceRegistry.enter`** with both **`from`** and **`to`** set to the DAO’s space id so the registry emits further **`Action`** events—covering kinds that supplement direct user **`enter`** flows, including behaviour historically exposed via dedicated registry entrypoints.

---

**Implementation note:** The codebase is authoritative for exact selectors, storage layout, and edge cases; this doc and the RFCs describe intended behaviour and history—if they diverge, trust **`src/`** and tests.
