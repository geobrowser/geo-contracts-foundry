# Master tech design — GEO contracts (source of truth)

This document is the **primary reference** for what the GEO contracts found in this repo are for, how they behave, and how the pieces fit together. Use this document when you need the story end-to-end; use the RFCs in `rfcs/` for proposal-level background, requirements, and implementation sketches on specific topics. 

---

## 1. System in one page

- **`SpaceRegistry`** — Single entry point for all space interactions. Users and spaces submit work through **`enter`** on the registry (not by calling **`write`** on a space, which accepts only the registry). It validates `from` (via `verify` when `from ≠ msg.sender`), emits the canonical anonymous **`Action`** event (`fromId`, `toId`, `action`, `topic`, `data`), and for inter-space actions routes **`fetch`** then **`write`** on the target space. It holds the bi-directional **space id ⇔ address** mapping (registration, clear, migration; archive/recovery extends lifecycle without dropping recoverability). The **registry owner** may also **`overrideSpaceId`** (rebind a `spaceId` to an `account` after clearing any prior links on those slots) and **`overrideAction`** (emit arbitrary **`Action`** tuples) to support **space transplantation**—preserving a chosen `spaceId` when moving from another chain or environment.
- **`DAOSpace`** — Default on-chain governance contract that supports proposals, voting, and member/editor roles. The **`write`** function permits only the registry as the caller, and the `action` input selects handlers. **Dual-path governance**: fast path (flat yes threshold via **`flatSupportThreshold`**, single action, immediate execution when threshold met; a **No** vote can escalate to slow path) and slow path (duration, quorum, **`partialPercentageSupportThreshold`** for late yes/no; optional **early execution** when **`universalPercentageSupportThreshold`** is met after quorum—see §4).
- **`DAOSpaceFactory` / `VerifierSpaceFactory`** — Deploy beacon-proxy spaces and register them with the registry. **`DAOSpace`** logic is shared via **`UpgradeableBeacon`**; factories/registry use UUPS where applicable. For transplantation, the factory exposes **`createDAOSpaceProxyForTransplant`** (**`onlyOwner`**, predetermined `spaceId`): the new DAO **does not** self-register until the registry owner calls **`overrideSpaceId`** for that proxy address (standard **`createDAOSpaceProxy`** still registers a fresh id on initialize).
- **`VerifierSpace`** — Lets one controlling identity act **as** multiple spaces via EIP-712 **`verify`** when the caller is not the `from` space’s address (out of scope for some audits; behavior is unchanged in principle).

**Action taxonomy** — Governance vs permissionless actions, naming, and `Action` field rules are specified in `rfcs/2026_01_01-geo-action-definitions-v1.md`. On-chain constants live in `ActionsConstants.sol`.

---

## 2. Original use cases (user stories)

These are the baseline intents the singleton architecture is built to support.

### On-chain identity and management

| Use case | Rough mechanism |
| --- | --- |
| Create a DAO or verifier space | Factory deploys proxy and initializes; in the usual path the space registers a new **`bytes16`** with **`SpaceRegistry`**. |
| Control many spaces from one EOA | Deploy multiple **`VerifierSpace`** instances; call **`enter`** with signatures so **`verify`** authorizes `from ≠ sender`. |
| Reader / personal identity without a space contract | **`registerSpaceId`** maps the EOA to a deterministic id. |
| Leave a space | **`enter`** with **`SPACE_LEFT`** → registry emits **`Action`**, then **`DAOSpace.write`** removes the role. |
| Migrate identity | **`proposeSpaceMigration`** / **`acceptSpaceMigration`** update the id ↔ address mapping. |
| Transplant a space id (e.g. testnet → mainnet, same id) | Registry owner **`overrideSpaceId`** binds the preserved **`bytes16`** to the live contract address; optional **`overrideAction`** emits follow-on **`Action`**s for the indexer. EOA spaces: override only. DAO spaces: deploy via **`createDAOSpaceProxyForTransplant`**, then **`overrideSpaceId`**; until then the DAO exists on-chain but is **not** in the registry mapping. |

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

- **Space transplantation (privileged)** — **`SpaceRegistry.overrideSpaceId`** / **`overrideAction`** (both **`onlyOwner`**). **`DAOSpace.initialize`** accepts an optional predetermined **`_daoSpaceId`**: **`bytes16(0)`** is normal creation (register + optional initial **`ping`**s); non-zero is **transplant** creation (roles and voting settings only—no registry registration until owner **`overrideSpaceId`**). **`DAOSpaceFactory.createDAOSpaceProxyForTransplant`** is the supported entry for transplant DAOs and passes the transplant id into **`initialize`**.

---

## 5. Deliberate design decisions (for reviewers)

Some behaviours look like inconsistencies when compared to adjacent code paths or to older RFC documentation. The items below are **intentional**, and are highlighted here so human and LLM-led reviews do not treat them as accidental gaps or critical defects.

### 5.1 Membership requests do not require MEMBER/EDITOR on the caller

**`MEMBERSHIP_REQUESTED`** is handled by **`_requestMembership`**, which does **not** repeat the **`hasRole(MEMBER) || hasRole(EDITOR)`** check used in **`_checkProposalPath`** for **`PROPOSAL_CREATED`**.

That difference is deliberate: a membership request is how a **registered space that is not yet a member** of this DAO asks to join. Requiring MEMBER or EDITOR on **`_fromSpaceId`** would make the flow impossible for the intended caller. Governance still proceeds via the normal proposal path (fast path for this flow, with editors voting).

### 5.2 `ping` on the fast path is permissive by design

Fast-path proposals may include **`ping`** when that selector is configured as a valid fast-path action. **`ping`** takes **`(action, subject, data)`** and emits further **`Action`** events through the registry (see §4). That means a successful fast-path execution can surface a wide range of event shapes “as” the DAO space in the event stream.

This is **not** an oversight: **`ping`** is the single generic mechanism for follow-on **`Action`** emissions (including kinds that older designs exposed via separate entrypoints). **Execution remains gated** by DAO governance (fast-path rules, editor votes, and whitelist of selectors). **Downstream systems** (indexers, clients) must not assume that every DAO-originated **`Action`** implies the same kind of on-chain state change as a direct governance operation—they should decode **`action` / `topic` / `data`** and apply product-specific trust and interpretation rules (e.g. the off-chain "Web of Trust"). Treating ambiguous or high-impact events as authoritative without that context is an integration risk, not a contract bug.

### 5.3 Registry owner override and transplantation

**`overrideSpaceId`** and **`overrideAction`** are **owner-only** back-doors: they can reassign **`spaceId` ⇄ address** and emit **synthetic `Action` events** that were not produced by a space’s normal **`enter` → write** path. That is intentional for **transplantation** (same `spaceId` on a new deployment) and for **indexer continuity** (e.g. member/editor **`Action`** shapes after a transplant DAO initializes without registering). It concentrates **operational and trust risk** in whoever controls the registry owner key (expected: Geo multisig). A DAO created for transplant but **never** **`overrideSpaceId`** remains **off-registry** and unusable through **`enter`** until fixed. Reviewers and integrators should treat **`SPACE_ID_OVERRIDDEN`** and owner-emitted batches from **`overrideAction`** as **first-class** signals, not anomalies.

### 5.4 Pending space migration and `overrideSpaceId`

**`spaceIdToProposedAddress`** is set by **`proposeSpaceMigration`** and cleared only by **`acceptSpaceMigration`** or **`clearSpaceId`**—not by owner **`overrideSpaceId`**. That is deliberate: rebinding is a separate, privileged mapping change; it does not imply cancellation of an in-flight migration workflow. **Operators** must **`clearSpaceId`** / resolve the migration before rebinding if a stale proposed recipient must not be able to complete **`acceptSpaceMigration`** against the rebound id. Treating this as a defect misses that the registry owner already has full mapping authority; safe sequencing is an operational contract, not an automatic invariant.

### 5.5 Vote eligibility uses the live EDITOR role (no proposal-time snapshot)

**`_canVote`** checks the caller’s **current** EDITOR role, not a frozen electorate at proposal creation. **By design:** governance answers “who may vote **now**,” which keeps storage and logic simple and aligns voting power with present editorial membership. **Consequences (accepted):** editors added after a proposal opens may vote on it; editors removed before voting cannot; outcomes can shift when membership changes during the window. Reviewers should not flag this as an oversight—snapshotting the electorate would be a different product choice.

### 5.6 Early-execution math uses live `totalEditors` (no snapshot)

Slow-path **early execution** (e.g. universal percentage support) is evaluated against **`totalEditors` at check time**, not at proposal creation or per-vote. **By design:** the bar tracks **current** governance size, avoiding per-proposal snapshots of editor counts. **Consequences (accepted):** removing editors after votes are cast can change whether a proposal becomes executable without new votes; removed editors’ prior votes still count; creators may lose **`PROPOSAL_UPDATED`** ability if stripped of EDITOR. Same “live context” philosophy as §5.5.

---

**Implementation note:** The codebase is authoritative for exact selectors, storage layout, and edge cases; this doc and the RFCs describe intended behaviour and history—if they diverge, trust **`src/`** and tests.
