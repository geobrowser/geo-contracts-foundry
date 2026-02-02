# GEO Contracts

Smart contracts for the Geo Browser plugin: a central space registry, DAO spaces, and verifier spaces. Built with Foundry.

## Contracts

- **SpaceRegistry** — Central registry for spaces (UUPS upgradeable)
- **DAOSpaceFactory** — Produces beacon-proxy DAO spaces
- **DAOSpace** — DAO space implementation (beacon proxy)
- **VerifierSpaceFactory** — Produces beacon-proxy verifier spaces
- **VerifierSpace** — Verifier space implementation (beacon proxy)

## Setup

1. Install [Foundry](https://github.com/foundry-rs/foundry#installation).
2. Copy `.env.example` to `.env` and set the variables (RPC URLs and deployer names for the chains you use).
3. Install Rust deps: `cargo install lintspec` (optional: `cargo install bulloak` for tree-based tests)
4. Install deps: `yarn install` (if commands fail, run `foundryup` and retry)

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
yarn test:invariant    # invariant / fuzz
yarn coverage          # coverage report
```

## Deploy & verify

1. **Set deployer in `.env`** — Add `GEO_DEPLOYER_NAME=<keystore_name>` (or the deployer name for the chain you use). `<keystore_name>` is the name you use for the key in Foundry. This must match the name you give when importing.

2. **Import the key** (if you haven’t already):

```bash
source .env
cast wallet import $GEO_DEPLOYER_NAME --interactive
```

3. **Deploy to GEO:**

```bash
yarn deploy:geo-browser
```

Deployments are written to `./broadcast`. See the [Foundry Book](https://book.getfoundry.sh/reference/forge/forge-create.html) for more options.

## License

AGPL-3.0-or-later — see [LICENSE](LICENSE).
