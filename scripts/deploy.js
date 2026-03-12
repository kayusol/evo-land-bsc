const { ethers } = require("hardhat");
const fs = require("fs");

// Resource rate encoding: 5x uint16 packed into uint80
// bits [0-15]=gold, [16-31]=wood, [32-47]=water, [48-63]=fire, [64-79]=soil
function encodeAttr(g, w, wa, f, s) {
  return BigInt(g) | (BigInt(w)<<16n) | (BigInt(wa)<<32n) | (BigInt(f)<<48n) | (BigInt(s)<<64n);
}

function landData() {
  const xs=[], ys=[], attrs=[];
  for (let x=0; x<=99; x++) {
    for (let y=0; y<=99; y++) {
      const seed = x*137+y*97;
      xs.push(x); ys.push(y);
      attrs.push(encodeAttr(
        (seed*3  +10)%100+5,
        (seed*7  +20)%100+5,
        (seed*11 +30)%100+5,
        (seed*13 +40)%100+5,
        (seed*17 +50)%100+5
      ).toString());
    }
  }
  return {xs, ys, attrs};
}

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deployer :", deployer.address);
  console.log("Balance  :", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "tBNB\n");

  const dep = {};

  // ── Tokens ───────────────────────────────────────────────────
  console.log("[1] Deploying RING...");
  const ring = await (await ethers.getContractFactory("RingToken")).deploy();
  await ring.waitForDeployment(); dep.ring = await ring.getAddress();
  console.log("  RING:", dep.ring);

  const tokenNames = [
    ["GoldToken",  "gold"],
    ["WoodToken",  "wood"],
    ["WaterToken", "water"],
    ["FireToken",  "fire"],
    ["SoilToken",  "soil"],
  ];
  console.log("[2] Deploying resource tokens...");
  for (const [cname, key] of tokenNames) {
    const t = await (await ethers.getContractFactory(cname)).deploy();
    await t.waitForDeployment(); dep[key] = await t.getAddress();
    console.log(`  ${cname}: ${dep[key]}`);
  }

  // ── NFTs ─────────────────────────────────────────────────────
  console.log("[3] Deploying LandNFT...");
  const land = await (await ethers.getContractFactory("LandNFT")).deploy();
  await land.waitForDeployment(); dep.land = await land.getAddress();
  console.log("  LandNFT:", dep.land);

  console.log("[4] Deploying DrillNFT...");
  const drill = await (await ethers.getContractFactory("DrillNFT")).deploy();
  await drill.waitForDeployment(); dep.drill = await drill.getAddress();
  console.log("  DrillNFT:", dep.drill);

  console.log("[5] Deploying ApostleNFT...");
  const apo = await (await ethers.getContractFactory("ApostleNFT")).deploy();
  await apo.waitForDeployment(); dep.apostle = await apo.getAddress();
  console.log("  ApostleNFT:", dep.apostle);

  // ── Systems ───────────────────────────────────────────────────
  console.log("[6] Deploying MiningSystem...");
  const mining = await (await ethers.getContractFactory("MiningSystem")).deploy(
    dep.land, dep.drill, dep.apostle,
    [dep.gold, dep.wood, dep.water, dep.fire, dep.soil]
  );
  await mining.waitForDeployment(); dep.mining = await mining.getAddress();
  console.log("  MiningSystem:", dep.mining);

  console.log("[7] Deploying LandAuction...");
  const auction = await (await ethers.getContractFactory("LandAuction")).deploy(dep.land, dep.ring);
  await auction.waitForDeployment(); dep.auction = await auction.getAddress();
  console.log("  LandAuction:", dep.auction);

  console.log("[8] Deploying LandInitializer...");
  const init = await (await ethers.getContractFactory("LandInitializer")).deploy(
    dep.land, dep.auction, dep.ring
  );
  await init.waitForDeployment(); dep.initializer = await init.getAddress();
  console.log("  LandInitializer:", dep.initializer);

  // ── Permissions ───────────────────────────────────────────────
  console.log("\n[9] Setting permissions...");
  let tx;

  // LandNFT operators: initializer (mint), auction (transfer), mining (transfer check)
  tx = await (await ethers.getContractAt("LandNFT", dep.land)).setOperator(dep.initializer, true); await tx.wait();
  tx = await (await ethers.getContractAt("LandNFT", dep.land)).setOperator(dep.auction, true);     await tx.wait();
  tx = await (await ethers.getContractAt("LandNFT", dep.land)).setOperator(dep.mining, true);      await tx.wait();

  // DrillNFT operator: mining (escrow)
  tx = await (await ethers.getContractAt("DrillNFT", dep.drill)).setOperator(dep.mining, true); await tx.wait();

  // ApostleNFT operator: mining (escrow)
  tx = await (await ethers.getContractAt("ApostleNFT", dep.apostle)).setOperator(dep.mining, true); await tx.wait();

  // Resource tokens minter: mining system
  const resAddrs = [dep.gold, dep.wood, dep.water, dep.fire, dep.soil];
  const resNames = ["GoldToken","WoodToken","WaterToken","FireToken","SoilToken"];
  for (let i=0; i<5; i++) {
    tx = await (await ethers.getContractAt(resNames[i], resAddrs[i])).setMinter(dep.mining, true);
    await tx.wait();
  }
  console.log("  All permissions set.");

  // ── Init 10000 Lands ──────────────────────────────────────────
  console.log("\n[10] Minting 10000 lands (200 batches x 50)...");
  const {xs, ys, attrs} = landData();
  const BATCH = 50;
  for (let i=0; i<10000; i+=BATCH) {
    tx = await (await ethers.getContractAt("LandInitializer", dep.initializer)).batchMint(
      xs.slice(i, i+BATCH),
      ys.slice(i, i+BATCH),
      attrs.slice(i, i+BATCH),
      deployer.address,
      { gasLimit: 8_000_000 }
    );
    await tx.wait();
    if ((i/BATCH+1) % 40 === 0) console.log(`  ${i+BATCH}/10000`);
  }
  console.log("  10000 lands minted!");

  // ── Genesis Auctions (first 20 lands) ─────────────────────────
  console.log("\n[11] Creating 20 genesis auctions...");
  // Approve auction to take land from deployer (initializer is operator so it can transfer)
  const landContract = await ethers.getContractAt("LandNFT", dep.land);
  tx = await landContract.setApprovalForAll(dep.auction, true); await tx.wait();

  const startP = ethers.parseEther("10");
  const endP   = ethers.parseEther("1");
  const dur    = 7 * 24 * 3600;
  for (let i=0; i<20; i++) {
    const tid = i+1; // tokenIds 1-20
    try {
      tx = await (await ethers.getContractAt("LandAuction", dep.auction)).createAuction(
        tid, startP, endP, dur
      );
      await tx.wait();
    } catch(e) { console.log(`  skip ${tid}:`, e.message.slice(0,60)); }
  }
  console.log("  Genesis auctions created!");

  // ── Save ──────────────────────────────────────────────────────
  const out = {
    network: "bscTestnet", chainId: 97,
    deployedAt: new Date().toISOString(),
    deployer: deployer.address,
    contracts: dep
  };
  fs.writeFileSync("deployed.json", JSON.stringify(out, null, 2));
  console.log("\n✅ DEPLOYMENT COMPLETE");
  console.log(JSON.stringify(dep, null, 2));
}

main().catch(e => { console.error(e); process.exit(1); });
