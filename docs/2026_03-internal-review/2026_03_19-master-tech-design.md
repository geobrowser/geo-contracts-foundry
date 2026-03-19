# Master tech design — motivating ideas (Jan–Mar 2026)

The following is a list of motivating ideas behind recent changes to this repo. For more thorough design and implementation details, see the RCFs in `rcfs/` and the repo history.

---

- **DAO Space beacon upgrade** — This work entailed three small changes to how the DAO Space operated. Firstly, to mitigate against bait-and-switch attacks, votes have been made to validate the proposal version so voters are made more aware of what they're voting for. Secondly, to handle membership requests by those who are already members, a check has been added. And finally, a dedicated `Action` event emission when the global voting settings change so that indexers/UIs can track them separately.

- **Slow path early execution** — This change allows slow-path proposals that have strong support to execute as soon as that support is reached, instead of always waiting for the full voting duration. A new setting (`slowPathAbsoluteThreshold`) lets DAOs set a high bar; when YES votes exceed that bar, the proposal can be executed immediately. This is especially useful for single-editor DAOs, where waiting for the full duration served no clear purpose. The original slow-path logic (duration, quorum, percentage threshold) still applies when the bar is not met.

- **Fast path for members** — This addition allows members, not only editors, to create fast-path proposals so that collaboration can be faster when appropriate. Editors retain the ability to restrict specific members or editors from using the fast path. A governance setting defines whether new members get fast-path access by default; DAOs can keep the previous behaviour (new members restricted) or open it up. As before, only editors can vote, and unrestricting someone from the fast path still requires a slow-path proposal.

- **Archive and recovery** — This change allows spaces to be marked as archived while remaining recoverable. The clear/archive/recovery flow lets spaces be retired without losing the option to restore them later.

- **Space ID format** — This work enforces UUIDv4 on space ID generation so that they can be easily used with offchain tooling and libraries, all while maintaining consistency and uniqueness.

- **Fast path actions** — This change simplifies the use of the fast path by making `ping` a valid fast-path action, while publish, flag, and unflag have been removed from the contract entirely. With that being said, these Actions are still supported by the contract, and can be emitted via `ping`, but now no longer have stand-alone functions. This supports scalability and flexibility moving forward, because unique Action events can be invented in the future and emitted with `ping`.

- **Topic on DAO creation** — This work supports the option that DAO creation includes declaring a topic, so that the DAO's scope is recorded on-chain from the start for indexing and discovery.

- **Membership request** — This change allows non-members to request DAO membership via an on-chain proposal. Existing editors vote on these proposals through normal governance processes.
