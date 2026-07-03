# Deploying the GEO Contracts — Step-by-Step Guide

This guide walks you through deploying the GEO Browser smart contracts, written
so that **you do not need to be a developer** to follow it. Just go through each
step in order, copy-paste the commands exactly as shown, and read the notes.

> ⚠️ **Read this first.** Deploying to "mainnet" (the real network) spends real
> money and cannot be undone. Whatever address you set as the **council address**
> (Step 5) will *own and control* the contracts forever, so double-check it.
> When in doubt, do a **testnet** run first (Step 8) — testnet is a free
> practice network where mistakes are harmless.

---

## What you are deploying

You are publishing five smart contracts to the GEO blockchain:

| Contract | Plain-English purpose |
| --- | --- |
| **SpaceRegistry** | The central address book that keeps track of every space. |
| **DAOSpaceFactory** | A factory that creates new DAO (governance) spaces. |
| **DAOSpace** | The blueprint each DAO space is built from. |
| **VerifierSpaceFactory** | A factory that creates new verifier spaces. |
| **VerifierSpace** | The blueprint each verifier space is built from. |

The deployment is fully automated by a single script. You only need to (a) set a
few values, and (b) run one command.

---

## What you need before you start

Gather these first — you can't finish without them:

1. **A computer with a terminal** (macOS or Linux; on Windows use WSL).
2. **The council address** — a wallet/multisig address. **This address becomes the
   owner of every contract you deploy.** It should be the official GEO multisig,
   *not* your personal deployer wallet. Get this from whoever owns the project.
3. **A deployer wallet** — a wallet that will *send* the deployment transactions.
   You'll need its **private key**, and it must hold **enough GEO tokens to pay
   for gas** (transaction fees). This wallet only pays the fees; it does **not**
   end up owning the contracts (the council address does).
4. **An RPC URL** — a web address that lets your computer talk to the GEO
   blockchain (e.g. `https://rpc.geo...`). Get this from the project team or an
   RPC provider.
5. **The chain ID** — a number identifying the network (the GEO testnet used in
   past deployments is `55516`). Confirm the correct value with the team.
6. *(Optional, for verification)* **A block-explorer (GeoScan) API URL and API
   key** — needed only if you want the contract source code to show up publicly
   on the block explorer.


---

## Step 1 — Install the required tools

Open your terminal and install these one at a time.

**a) Foundry** (the toolkit that compiles and deploys the contracts):

```bash
curl -L https://foundry.paradigm.xyz | bash
```

Then close and reopen your terminal (or run `source ~/.bashrc`) and run:

```bash
foundryup
```

**b) Node.js and Yarn** (used to run the project's helper commands). Install
Node.js 18+ from <https://nodejs.org>, then install Yarn:

```bash
npm install -g yarn
```

**c) Rust + lintspec** (a small helper the build uses). Install Rust from
<https://rustup.rs>, then:

```bash
cargo install lintspec
```

To confirm everything installed, these should each print a version number:

```bash
forge --version
yarn --version
```

---

## Step 2 — Get the project code

If you don't already have the project folder, download it and enter it:

```bash
git clone https://github.com/geobrowser/geo-contracts-foundry.git
cd geo-contracts-foundry
```

If you already have the folder, just `cd` into it.

---

## Step 3 — Install the project's dependencies

Inside the project folder, run:

```bash
yarn install
```

If any command later fails with an error mentioning `forge`, run `foundryup`
once more and try again.

---

## Step 4 — Do a quick sanity build

Make sure everything compiles before you touch any settings:

```bash
yarn build
```

You should see it finish without errors. If it fails here, stop and fix the
installation before continuing — deploying won't work otherwise.

---

## Step 5 — ⭐ Set the council address (the most important step)

This is the value that decides **who will own and control the deployed
contracts**. Set it wrong and the wrong party controls everything.

Open the file **`script/Constants.s.sol`** in any text editor. It looks like
this:

```solidity
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.35;

// GEO
address constant GEO_GEO_MULTISIG_COUNCIL = address(0x200);
```

**Replace the address** after the `=` sign with the correct council address for
your deployment. Keep everything else exactly the same — including the leading
`0x` and the semicolon `;` at the end.

For example, if the council address is `0xABC...123`, the line becomes:

```solidity
address constant GEO_GEO_MULTISIG_COUNCIL = 0xABC...123;
```

Checklist for the address:

- ✅ It starts with `0x` and is 42 characters long (`0x` + 40 characters).
- ✅ It is the **multisig/council** address, not your deployer wallet.
- ✅ You copied it from a trusted source (don't type it by hand).

Save the file. Then rebuild to make sure your edit is valid:

```bash
yarn build
```

If it builds cleanly, your edit is good.

---

## Step 6 — Fill in the `.env` configuration file

The `.env` file holds the network settings. Create it by copying the example:

```bash
cp .env.example .env
```

Open `.env` in a text editor. You'll see empty fields — fill them in like this:

```bash
# --- Mainnet (the real network) ---
GEO_RPC=https://your-geo-rpc-url          # the RPC address from Step "What you need"
GEO_CHAIN_ID=                             # the GEO mainnet chain ID (confirm with team)
GEO_DEPLOYER_NAME=geo-deployer            # any nickname you choose for your wallet (see Step 7)

# --- Testnet (the free practice network) ---
GEO_TESTNET_RPC=https://your-geo-testnet-rpc-url
GEO_TESTNET_CHAIN_ID=55516                # the GEO testnet chain ID
GEO_TESTNET_DEPLOYER_NAME=geo-deployer-testnet

# --- Block explorer verification (optional) ---
GEOSCAN_API_URL=https://api.geoscan..../api                          # explorer API URL (mainnet)
GEOSCAN_TESTNET_API_URL=https://explorer-geo-testnet-irdc0cgb0w...   # explorer API URL (testnet)
GEOSCAN_API_KEY=your-api-key                                         # your explorer API key
```

Notes:

- **`GEO_DEPLOYER_NAME`** is just a nickname (a label) for your deployer wallet.
  Pick anything you like, e.g. `geo-deployer`. You'll use the **same nickname**
  in Step 7 when you import the wallet.
- The **GEOSCAN** values are only needed for mainnet **verification** (making the
  source code public on the explorer). The mainnet deploy command uses them
  automatically. You can leave them blank if you don't need verification, but
  then remove `--verify` — see the note in Step 9.
- If you're only doing a testnet run, you only need to fill in the testnet
  fields.

> 🔒 The `.env` file is already listed in `.gitignore`, so it won't be committed
> to git. Still, treat it as private.

---

## Step 7 — Import your deployer wallet (securely)

Instead of pasting your private key into commands, you load it once into
Foundry's encrypted keystore under the nickname you chose in Step 6.

**For mainnet:**

```bash
source .env
cast wallet import $GEO_DEPLOYER_NAME --interactive
```

**For testnet:**

```bash
source .env
cast wallet import $GEO_TESTNET_DEPLOYER_NAME --interactive
```

When prompted:

1. Paste your deployer wallet's **private key** and press Enter.
   *(Nothing will show on screen as you paste — that's normal.)*
2. Choose a **password** to encrypt it locally, and press Enter.

You only do this **once per wallet, per machine**. From now on, deployments will
just ask for that password instead of your private key.

---

## Step 8 — Practice on testnet first (strongly recommended)

Testnet is free and safe. Run:

```bash
yarn deploy:geo-browser:testnet
```

Enter your keystore password when asked. Watch the output — it will show each
contract being deployed. If this succeeds, you're ready for the real thing.

> If it fails, see **Troubleshooting** below. Fixing problems on testnet costs
> nothing.

---

## Step 9 — Deploy to mainnet (the real deployment)

When you're confident, run:

```bash
yarn deploy:geo-browser
```

Enter your keystore password when asked. This spends real GEO tokens on gas and
deploys the live contracts owned by the council address from Step 5.

The command automatically:

- recompiles the contracts,
- deploys all five contracts and wires them together,
- **verifies** the source code on the block explorer (the `--verify` flag).

> **If you don't have GeoScan verification set up** (Step 6) and the deploy fails
> at the verification stage, you can deploy without it. Open `package.json`, find
> the `deploy:geo-browser` line, and remove the word `--verify`. The contracts
> will still deploy — they just won't have their source shown on the explorer.
> (You can verify them later separately.)

---

## Step 10 — Find your deployed addresses

After a successful deployment, the results are saved automatically in the
**`broadcast/`** folder:

```
broadcast/DeployGEOBrowser.s.sol/<chain-id>/run-latest.json
```

Open `run-latest.json` and look for the deployed contract addresses (search for
the contract names like `SpaceRegistry` or `DAOSpaceFactory`). Save these
addresses somewhere safe and share them with the team — the app and other tools
will need them.

---

## Quick reference (the whole thing at a glance)

```bash
# 1–3. Install tools, get code, install deps
foundryup
yarn install

# 4. Sanity build
yarn build

# 5. Edit script/Constants.s.sol -> set GEO_GEO_MULTISIG_COUNCIL to the council address

# 6. cp .env.example .env  -> fill in RPC, chain ID, deployer name (+ GeoScan for verify)

# 7. Import the deployer wallet once
source .env
cast wallet import $GEO_DEPLOYER_NAME --interactive          # mainnet
cast wallet import $GEO_TESTNET_DEPLOYER_NAME --interactive  # testnet

# 8. Practice on testnet
yarn deploy:geo-browser:testnet

# 9. Deploy for real
yarn deploy:geo-browser

# 10. Read broadcast/DeployGEOBrowser.s.sol/<chain-id>/run-latest.json
```

---

## Troubleshooting

| Problem | What to do |
| --- | --- |
| `forge: command not found` | Run `foundryup`, then reopen your terminal. |
| Build fails after editing `Constants.s.sol` | You probably deleted the `0x`, a character, or the `;`. Re-check Step 5 — the address must be `0x` + 40 characters, ending in `;`. |
| "insufficient funds" during deploy | Your **deployer wallet** doesn't have enough GEO for gas. Top it up. |
| Wrong password / can't unlock wallet | Re-import the wallet (Step 7) with the correct private key and set a new password. |
| Deploy works but verification fails | Check `GEOSCAN_API_URL` and `GEOSCAN_API_KEY` in `.env`, or remove `--verify` (see Step 9). The contracts are still deployed. |
| "nonce too low" / network hiccup | Simply re-run the same deploy command; the script resumes safely. |
| Not sure the council address is right | **Stop.** Confirm it with the project owner before deploying to mainnet. If the address is not correct, you will be forced to deploy new instances of the contracts. |

---

## Glossary

- **Gas** — the fee paid (in GEO tokens) to run a transaction on the blockchain.
- **Deployer wallet** — the wallet that pays gas and sends the deploy
  transactions. Does *not* own the contracts.
- **Council / multisig address** — the address that *owns and governs* the
  deployed contracts. Set in `script/Constants.s.sol`.
- **RPC URL** — the internet endpoint your computer uses to reach the
  blockchain.
- **Chain ID** — a number that uniquely identifies a blockchain network.
- **Keystore** — Foundry's encrypted, password-protected storage for your
  private key, so you never type the key into commands.
- **Verification** — publishing the contract source code on the block explorer
  so anyone can read it.
- **Testnet vs. mainnet** — testnet is a free practice network; mainnet is the
  real network where value and ownership are real.