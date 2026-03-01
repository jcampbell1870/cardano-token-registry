# PONG — Ethereum Rewards

A faithful recreation of the original 1972 Atari Pong, playable in any modern
browser. Players connect their **MetaMask** wallet and earn real **ETH** just
for playing — rewarded per rally, per point, and with a win bonus.

---

## Quick Start (no contract needed)

Just open `pong/index.html` in your browser.

The game runs in **demo mode** by default — all reward accounting happens
client-side and no on-chain transactions are made. Connect MetaMask to see your
accumulated earnings and experiment with the claim flow.

---

## Reward Structure

| Event | ETH earned |
|---|---|
| Each ball-paddle rally | 0.000010 ETH |
| Each point you score | 0.000100 ETH |
| Winning a match (first to 11) | 0.000500 ETH |
| Per-session cap | 0.005000 ETH |

---

## Going Live with the Smart Contract

### 1. Prerequisites

```bash
cd pong/contract
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox dotenv
```

### 2. Environment

Create `pong/contract/.env`:

```
PRIVATE_KEY=0x<your deployer wallet private key>
RPC_URL=https://eth-sepolia.g.alchemy.com/v2/<your-api-key>
ETHERSCAN_API_KEY=<optional, for verification>
SEED_FUND=true          # set to true to auto-fund with 0.01 ETH on deploy
```

> **Never commit your `.env` file.** A `.gitignore` entry is included.

### 3. Deploy (Sepolia testnet)

```bash
npx hardhat run contract/deploy.js --network sepolia
```

The script prints the deployed contract address. Copy it.

### 4. Wire up the game

In `pong/index.html`, set:

```js
const CONFIG = {
  CONTRACT_ADDRESS: "0x<your deployed address>",
  // ...
};
```

### 5. Fund the contract

Send ETH to the contract address via MetaMask, or run:

```bash
SEED_FUND=true npx hardhat run contract/deploy.js --network sepolia
```

### 6. (Optional) Verify on Etherscan

```bash
npx hardhat verify --network sepolia <contract address>
```

---

## Controls

| Key | Action |
|---|---|
| `W` / `S` | Left paddle up / down |
| `↑` / `↓` | Right paddle up / down |
| `Space` or click | Start / pause |

---

## Architecture

```
pong/
├── index.html            # Self-contained game + MetaMask UI (vanilla JS + ethers v6)
└── contract/
    ├── PongRewards.sol   # Solidity contract — holds ETH, records games, pays claims
    ├── deploy.js         # Hardhat deployment script
    └── hardhat.config.js # Network / compiler config
```

### PongRewards.sol highlights

- `recordGame(player, rallies, points, won)` — called by owner/relayer after each match to accrue rewards.
- `recordGameSelf(rallies, points, won)` — called directly by the player's wallet (no trusted relayer required).
- `claimRewards()` — player pulls their accumulated ETH (subject to a 1-hour cooldown).
- `setRates(...)` — owner can tune reward rates at any time.
- `setPaused(true)` — emergency pause.
- `withdrawAll()` — owner can recover contract funds.

---

## Security Notes

- The per-session cap (`sessionCap`) limits how much a single game session can accrue, reducing incentive to bot the game.
- The claim cooldown prevents rapid repeated claims.
- `recordGameSelf` relies on the player supplying their own stats — the contract applies the same cap. For a production deployment, use a trusted back-end relayer that verifies game sessions cryptographically before calling `recordGame`.
- Never store a private key in front-end code.

---

## License

MIT
