const { ethers } = require("hardhat");
const fs = require("fs");

// Resource rate encoding: 5x uint16 packed into uint80
function encodeAttr(g, w, wa, f, s) {
  return (
    BigInt(g) |
    (BigInt(w)  << 16n) |
    (BigInt(wa) << 32n) |
    (BigInt(f)  << 48n) |
    (BigInt(s)  << 64n)
  ).toString();
}

// Generate deterministic attributes for all 10000 lands
function landData() {
  const xs = [], ys = [], attrs = [];
  for (let x = 0; x <= 99; x++) {
    for (let y = 0; y <= 99; y++) {
      const s = x * 137 + y * 97;
      xs.push(x); ys.push(y);
      attrs.push(encodeAttr(
        (s * 3  + 10) % 100 + 5,
        (s * 7  + 20) % 100 + 5,
        (s * 11 + 30) % 100 + 5,
        (s * 13 + 40) % 100 + 5,
        (s * 17 + 50) % 100 + 5
      ));
    }
  }
  return { xs, ys, attrs };
}

async function deploy(name, ...args) {
  const C = await ethers.getContractFactory(name);
  const c = await C.deploy(...args);
  await c.waitForDeployment();
  const addr = await c.getAddress();
  console.log(`  ${name}: ${addr}`);
  return { contract: c, address: addr };
}

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);
  const bal = await ethers.provider.getBalance(deployer.address);
  console.log("Balance :", ethers.formatEther(bal), "tBNB\n");

  const dep = {};

  // ── 1. Tokens ────────────────────────────────────────────────
  console.log("[1/12] RING token...");
  const { address: ringAddr } = await deploy("RingToken");
  dep.ring = ringAddr;

  console.log("[2/12] Resource tokens...");
  for (const [cname, key] of [
    ["GoldToken",  "gold"],
    ["WoodToken",  "wood"],
    ["WaterToken", "water"],
    ["FireToken",  "fire"],
    ["SoilToken",  "soil"],
  ]) {
    const { address } = await deploy(cname);
    dep[key] = address;
  }

  // ── 2. NFTs ──────────────────────────────────────────────────
  console.log("[3/12] LandNFT...");
  const { address: landAddr } = await deploy("LandNFT");
  dep.land = landAddr;

  console.log("[4/12] DrillNFT...");
  const { address: drillAddr } = await deploy("DrillNFT");
  dep.drill = drillAddr;

  console.log("[5/12] ApostleNFT...");
  const { address: apoAddr } = await deploy("ApostleNFT");
  dep.apostle = apoAddr;

  // ── 3. Systems ───────────────────────────────────────────────
  console.log("[6/12] MiningSystem...");
  const { address: miningAddr } = await deploy(
    "MiningSystem",
    dep.land, dep.drill, dep.apostle,
    [dep.gold, dep.wood, dep.water, dep.fire, dep.soil]
  );
  dep.mining = miningAddr;

  console.log("[7/12] LandAuction...");
  const { address: auctionAddr } = await deploy("LandAuction", dep.land, dep.ring);
  dep.auction = auctionAddr;

  console.log("[8/12] LandInitializer...");
  const { address: initAddr } = await deploy("LandInitializer", dep.land, dep.auction, dep.ring);
  dep.initializer = initAddr;

  console.log("[9/12] ReferralReward...");
  const { address: refAddr } = await deploy("ReferralReward");
  dep.referral = refAddr;

  console.log("[10/12] BlindBox...");
  const apostleBoxPrice = ethers.parseEther("1");   // 1 RING per apostle box
  const drillBoxPrice   = ethers.parseEther("0.5"); // 0.5 RING per drill box
  const { address: bbAddr } = await deploy(
    "BlindBox",
    dep.ring, dep.apostle, dep.drill,
    deployer.address,   // treasury = deployer for now
    apostleBoxPrice,
    drillBoxPrice
  );
  dep.blindbox = bbAddr;

  // ── 4. Permissions ────────────────────────────────────────────
  console.log("\n[11/12] Setting permissions...");
  let tx;

  const landC    = await ethers.getContractAt("LandNFT",    dep.land);
  const drillC   = await ethers.getContractAt("DrillNFT",   dep.drill);
  const apoC     = await ethers.getContractAt("ApostleNFT", dep.apostle);
  const refC     = await ethers.getContractAt("ReferralReward", dep.referral);

  // Land operators: initializer + auction + mining
  tx = await landC.setOperator(dep.initializer, true); await tx.wait();
  tx = await landC.setOperator(dep.auction,     true); await tx.wait();
  tx = await landC.setOperator(dep.mining,      true); await tx.wait();

  // Drill & Apostle operators: mining (escrow) + blindbox (mint)
  tx = await drillC.setOperator(dep.mining,   true); await tx.wait();
  tx = await drillC.setOperator(dep.blindbox, true); await tx.wait();
  tx = await apoC.setOperator(dep.mining,     true); await tx.wait();
  tx = await apoC.setOperator(dep.blindbox,   true); await tx.wait();

  // Resource token minters: mining system
  for (const [cname, key] of [
    ["GoldToken","gold"],["WoodToken","wood"],["WaterToken","water"],
    ["FireToken","fire"],["SoilToken","soil"]
  ]) {
    const t = await ethers.getContractAt(cname, dep[key]);
    tx = await t.setMinter(dep.mining, true); await tx.wait();
  }

  // ReferralReward: set miningSystem
  tx = await refC.setMiningSystem(dep.mining); await tx.wait();

  console.log("  All permissions configured.");

  // ── 5. Mint 10000 Lands ───────────────────────────────────────
  console.log("\n[12/12] Minting 10000 lands (200 batches x 50)...");
  const initC = await ethers.getContractAt("LandInitializer", dep.initializer);
  const { xs, ys, attrs } = landData();
  const BATCH = 50;
  for (let i = 0; i < 10000; i += BATCH) {
    tx = await initC.batchMint(
      xs.slice(i, i + BATCH),
      ys.slice(i, i + BATCH),
      attrs.slice(i, i + BATCH),
      deployer.address,
      { gasLimit: 8_000_000 }
    );
    await tx.wait();
    if (Math.floor(i / BATCH) % 40 === 39)
      console.log(`  ${i + BATCH}/10000 minted`);
  }
  console.log("  10000 lands minted!");

  // ── 6. Genesis Auctions (first 20 lands) ─────────────────────
  console.log("\nCreating 20 genesis auctions (tokenId 1-20)...");
  const auctionC = await ethers.getContractAt("LandAuction", dep.auction);
  const landApproved = await landC.setApprovalForAll(dep.auction, true);
  await landApproved.wait();

  const startP = ethers.parseEther("10");  // 10 RING start
  const endP   = ethers.parseEther("1");   // 1  RING floor
  const dur    = 7 * 24 * 3600;            // 7 days
  for (let i = 0; i < 20; i++) {
    try {
      tx = await auctionC.createAuction(i + 1, startP, endP, dur, { gasLimit: 200_000 });
      await tx.wait();
    } catch (e) {
      console.log(`  skip ${i + 1}:`, e.message.slice(0, 80));
    }
  }
  console.log("  20 genesis auctions live!");

  // ── 7. Save results ──────────────────────────────────────────
  const output = {
    network:    "bscTestnet",
    chainId:    97,
    deployedAt: new Date().toISOString(),
    deployer:   deployer.address,
    contracts:  dep
  };
  fs.writeFileSync("deployed.json", JSON.stringify(output, null, 2));

  console.log("\n✅ ALL CONTRACTS DEPLOYED");
  console.log("==========================");
  console.log(JSON.stringify(dep, null, 2));
}

main().catch(e => { console.error(e); process.exit(1); });
