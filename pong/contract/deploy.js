/**
 * deploy.js — PongRewards contract deployment script
 *
 * Prerequisites:
 *   npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox dotenv
 *
 * Usage:
 *   1. Create .env in this directory:
 *        PRIVATE_KEY=0x...          # deployer wallet private key
 *        RPC_URL=https://...        # e.g. Alchemy / Infura Sepolia endpoint
 *        ETHERSCAN_API_KEY=...      # optional, for verification
 *
 *   2. npx hardhat run contract/deploy.js --network sepolia
 *
 *   3. Copy the printed CONTRACT_ADDRESS into pong/index.html → CONFIG.CONTRACT_ADDRESS
 *
 *   4. Fund the contract:
 *        npx hardhat run contract/fund.js --network sepolia
 *      or send ETH directly to the contract address via MetaMask.
 */

require("dotenv").config();
const { ethers, network } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("──────────────────────────────────────────────────");
  console.log(" Deploying PongRewards");
  console.log("──────────────────────────────────────────────────");
  console.log(` Network   : ${network.name}`);
  console.log(` Deployer  : ${deployer.address}`);
  console.log(
    ` Balance   : ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))} ETH`
  );
  console.log("──────────────────────────────────────────────────");

  const Factory = await ethers.getContractFactory("PongRewards");
  const contract = await Factory.deploy();
  await contract.waitForDeployment();

  const address = await contract.getAddress();
  console.log(`\n Contract deployed at: ${address}`);

  // Optionally fund the contract with a small initial balance
  const INITIAL_FUND_ETH = "0.01"; // 0.01 ETH seed money
  if (process.env.SEED_FUND === "true") {
    const tx = await deployer.sendTransaction({
      to: address,
      value: ethers.parseEther(INITIAL_FUND_ETH),
    });
    await tx.wait();
    console.log(` Funded with ${INITIAL_FUND_ETH} ETH — tx: ${tx.hash}`);
  }

  console.log("\n ✅ Done! Next steps:");
  console.log(`    1. Set CONFIG.CONTRACT_ADDRESS = "${address}" in pong/index.html`);
  console.log("    2. Fund the contract via MetaMask or the fund() function");
  console.log("    3. (Optional) Verify on Etherscan:");
  console.log(`       npx hardhat verify --network ${network.name} ${address}`);
  console.log("──────────────────────────────────────────────────\n");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
