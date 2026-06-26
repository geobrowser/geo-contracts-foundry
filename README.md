# GEO Contracts

Smart contracts for the GEO protocol: an L1 ERC-20 governance token on **Ethereum mainnet**, an L2 incentives stack on **Arbitrum**, and L3 Geo governance contracts on the **GEO chain**. Built with Foundry.

`L1/`, `L2/`, and `L3/` name the **deployment chain** for each layer. Sources live under `src/contracts/` and `src/interfaces/` with matching `test/unit/`, `test/integration/`, and `script/` subfolders.

## Contracts

### L1 (Ethereum mainnet)

- **GEOToken** — ERC-20 governance token (UUPS upgradeable)
- **IGEOToken** — token interface

### L2 (Arbitrum — incentives stack)

- **Escrow** — holds GEO for reward claims
- **PaymentManager** — payment requests and execution (L3 SpaceRegistry sets payers via cross-chain messages)
- **Rewarder** — merkle-based reward claims
- **StakingManager** — stake, allocate, unstake
- **StakingRegistry** — allocation targets (spaces, topics)

### L3 (GEO chain — Geo Browser plugin)

- **SpaceRegistry** — Central registry for spaces (UUPS upgradeable)
- **DAOSpaceFactory** / **DAOSpace** — Beacon-proxy DAO spaces
- **VerifierSpaceFactory** / **VerifierSpace** — Beacon-proxy verifier spaces

## Setup

1. Install [Foundry](https://github.com/foundry-rs/foundry#installation).
2. Copy `.env.example` to `.env` and set the variables (RPC URLs and deployer names for the chains you use).
3. Install Rust deps: `cargo install lintspec` (optional: `cargo install bulloak` for tree-based tests).
4. Install deps: `yarn install` (if commands fail, run `foundryup` and retry).

## Build

```bash
yarn build
```

Optimized (via IR):

```bash
yarn build:optimized
```

## Tests

```bash
yarn test              # all tests
yarn test:unit         # unit only
yarn test:unit:deep    # unit with 5x fuzz runs
yarn test:integration  # integration only
yarn test:invariant    # execution-path + invariant / fuzz
yarn coverage          # coverage report
```

## Deploy & verify

### L1 — GEO token (Ethereum)

```bash
yarn deploy:layer-one:ethereum-mainnet
yarn deploy:layer-one:ethereum-sepolia
```

Set `ETHEREUM_MAINNET_DEPLOYER_NAME` / `ETHEREUM_SEPOLIA_DEPLOYER_NAME` and Ethereum RPC URLs in `.env`.

### L2 — incentives stack (Arbitrum)

```bash
yarn deploy:layer-two:arbitrum-one
yarn deploy:layer-two:arbitrum-sepolia
```

Set `ARBITRUM_ONE_DEPLOYER_NAME` / `ARBITRUM_SEPOLIA_DEPLOYER_NAME`, L2 constants in `script/Constants.sol`, and Arbitrum RPC URLs. The deployer must be an **EOA**.

### L3 — Geo Browser (GEO chain)

```bash
yarn deploy:layer-three           # Mainnet
yarn deploy:layer-three:testnet   # Testnet
```

Set `GEO_DEPLOYER_NAME` / `GEO_TESTNET_DEPLOYER_NAME`, `GEO_RPC` / `GEO_TESTNET_RPC`, chain IDs, and `GEO_GEO_MULTISIG_COUNCIL` in `script/Constants.sol`.

Deployments are written to `./broadcast`. See the [Foundry Book](https://book.getfoundry.sh/reference/forge/forge-create.html) for more options.

## License

AGPL-3.0-or-later — see [LICENSE](LICENSE).
