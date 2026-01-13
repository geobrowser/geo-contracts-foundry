## 1. SpaceRegistry

The SpaceRegistry maintains bidirectional mappings between addresses and spaceIds and serves as the entry point for all Actions.

| ID | Invariant |
|----|-----------|
| SR-INV-1 | For any registered spaceId: `addressToSpaceId[spaceIdToAddress[spaceId]] == spaceId` |
| SR-INV-2 | For any registered address: `spaceIdToAddress[addressToSpaceId[addr]] == addr` |
| SR-INV-3 | After migration completes: old address has no spaceId AND new address has the migrated spaceId |

---

## 2. DAOSpaceFactory & VerifierSpaceFactory

| ID | Invariant |
|----|-----------|
| FACT-INV-1 | Every created Space instance has a registered spaceId in SpaceRegistry (No "orphan" spaces) |
| FACT-INV-2 | All Space instances created by a factory share the same logic via a consistent Beacon address |

---

## 3. DAOSpace

The DAOSpace contract manages governance with roles and a proposal lifecycle.

| ID | Invariant |
|----|-----------|
| DS-INV-1 | A proposal cannot be executed unless its status is "Passed" (Calculated from voting logic) |
| DS-INV-2 | An executed proposal cannot be re-executed (Replay protection / ADX-146) |
| DS-INV-3 | Each editor can only vote once per proposal (GP-001 / Sybil/Double-voting) |

| ID | Invariant |
|----|-----------|
| DS-INV-4 | Member/Editor counts must match the actual number of addresses granted those roles in AccessControl |
| DS-INV-5 | `yesVotes + noVotes + abstainVotes == totalVotesCast` for any proposal |
| DS-INV-6 | Quorum setting must be less than or equal to total editors |
| DS-INV-7 | Fast path flat threshold setting must be less than or equal to total editors |
---

## 4. VerifierSpace

Allows EOA control over spaces via signature verification.

| ID | Invariant |
|----|-----------|
| VS-INV-1 | `nonce` for a VerifierSpace instance must monotonically increase after every successful `verify()` (SOL-Signature-1) |
| VS-INV-2 | `SignatureChecker.isValidSignatureNow` must fail for any message previously used with the current space/nonce combination (Replay protection) |
