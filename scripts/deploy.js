const { ethers } = require("hardhat");
const fs = require("fs");

// Resource rate encoding helper
// resourceRateAttr = gold | (wood<<16) | (water<<32) | (fire<<48) | (soil<<64)
function encodeResourceRate(gold, wood, water, fire, soil) {
  return BigInt(gold) |
    (BigInt(wood) << 16n) |
    (BigInt(water) << 32n) |
    (BigInt(fire) << 48n) |
    (BigInt(soil) << 64n);
}

// Generate 10000 land resource rates
// Simple distribution: varied rates across the map
function generateLandData() {
  const xs = [], ys = [], rates = [], masks = [];
  for (let x = 0; x <= 99; x++) {
    for (let y = 0; y <= 99; y++) {
      // Generate pseudo-random resource rates based on position
      const seed = x * 137 + y * 97;
      const gold  = ((seed * 3 + 10) % 100) + 5;
      const wood  = ((seed * 7 + 20) % 100) + 5;
      const water = ((seed * 11 + 30) % 100) + 5;
      const fire  = ((seed * 13 + 40) % 100) + 5;
      const soil  = ((seed * 17 + 50) % 100) + 5;

      // Special lands: corners and center
      let mask = 0;
      if ((x === 0 && y === 0) || (x === 99 && y === 99) ||
          (x === 0 && y === 99) || (x === 99 && y === 0) ||
          (x === 49 && y === 49) || (x === 50 && y === 50)) {
        mask = 2; // special
      }

      xs.push(x);
      ys.push(y);
      rates.push(encodeResourceRate(gold, wood, water, fire, soil).toString());
      masks.push(mask);
    }
  }
  return { xs, ys, rates, masks };
}

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying from:", deployer.address);
  
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("Balance:", ethers.formatEther(balance), "tBNB");

  const deployed = {};

  // ===== 1. SettingsRegistry =====
  console.log("\n[1/10] Deploying SettingsRegistry...");
  const SettingsRegistry = await ethers.getContractFactory("SettingsRegistry");
  const registry = await SettingsRegistry.deploy();
  await registry.waitForDeployment();
  deployed.settingsRegistry = await registry.getAddress();
  console.log("SettingsRegistry:", deployed.settingsRegistry);

  // ===== 2. ObjectOwnership =====
  console.log("[2/10] Deploying ObjectOwnership...");
  const ObjectOwnership = await ethers.getContractFactory("ObjectOwnership");
  const objectOwnership = await ObjectOwnership.deploy();
  await objectOwnership.waitForDeployment();
  deployed.objectOwnership = await objectOwnership.getAddress();
  console.log("ObjectOwnership:", deployed.objectOwnership);

  // ===== 3. RING Token =====
  console.log("[3/10] Deploying RING Token...");
  const RingToken = await ethers.getContractFactory("RingToken");
  const ring = await RingToken.deploy();
  await ring.waitForDeployment();
  deployed.ring = await ring.getAddress();
  console.log("RING:", deployed.ring);
  console.log("RING total supply:", ethers.formatEther(await ring.totalSupply()));

  // ===== 4. KTON Token =====
  console.log("[4/10] Deploying KTON Token...");
  const KtonToken = await ethers.getContractFactory("KtonToken");
  const kton = await KtonToken.deploy();
  await kton.waitForDeployment();
  deployed.kton = await kton.getAddress();
  console.log("KTON:", deployed.kton);

  // ===== 5. Resource Tokens =====
  console.log("[5/10] Deploying Resource Tokens...");
  const ResourceToken = await ethers.getContractFactory("ResourceToken");

  const gold = await ResourceToken.deploy("Evolution Land Gold", "GOLD");
  await gold.waitForDeployment();
  deployed.gold = await gold.getAddress();

  const wood = await ResourceToken.deploy("Evolution Land Wood", "WOOD");
  await wood.waitForDeployment();
  deployed.wood = await wood.getAddress();

  const water = await ResourceToken.deploy("Evolution Land Water", "HHO");
  await water.waitForDeployment();
  deployed.water = await water.getAddress();

  const fire = await ResourceToken.deploy("Evolution Land Fire", "FIRE");
  await fire.waitForDeployment();
  deployed.fire = await fire.getAddress();

  const soil = await ResourceToken.deploy("Evolution Land Soil", "SIOO");
  await soil.waitForDeployment();
  deployed.soil = await soil.getAddress();

  console.log("GOLD:", deployed.gold);
  console.log("WOOD:", deployed.wood);
  console.log("HHO(Water):", deployed.water);
  console.log("FIRE:", deployed.fire);
  console.log("SIOO(Soil):", deployed.soil);

  // ===== 6. RevenuePool =====
  console.log("[6/10] Deploying RevenuePool...");
  const RevenuePool = await ethers.getContractFactory("RevenuePool");
  const revenuePool = await RevenuePool.deploy(deployed.ring);
  await revenuePool.waitForDeployment();
  deployed.revenuePool = await revenuePool.getAddress();
  console.log("RevenuePool:", deployed.revenuePool);

  // ===== 7. LandBase =====
  console.log("[7/10] Deploying LandBase...");
  const LandBase = await ethers.getContractFactory("LandBase");
  const landBase = await LandBase.deploy(deployed.settingsRegistry);
  await landBase.waitForDeployment();
  deployed.landBase = await landBase.getAddress();
  console.log("LandBase:", deployed.landBase);

  // ===== 8. ClockAuction =====
  console.log("[8/10] Deploying ClockAuction...");
  const ClockAuction = await ethers.getContractFactory("ClockAuction");
  const clockAuction = await ClockAuction.deploy(deployed.settingsRegistry);
  await clockAuction.waitForDeployment();
  deployed.clockAuction = await clockAuction.getAddress();
  console.log("ClockAuction:", deployed.clockAuction);

  // ===== 9. GringottsBank =====
  console.log("[9/10] Deploying GringottsBank...");
  const GringottsBank = await ethers.getContractFactory("GringottsBank");
  const bank = await GringottsBank.deploy(deployed.ring, deployed.kton);
  await bank.waitForDeployment();
  deployed.bank = await bank.getAddress();
  console.log("GringottsBank:", deployed.bank);

  // ===== 10. LandResource =====
  console.log("[10/10] Deploying LandResource...");
  const LandResource = await ethers.getContractFactory("LandResource");
  const landResource = await LandResource.deploy(deployed.settingsRegistry);
  await landResource.waitForDeployment();
  deployed.landResource = await landResource.getAddress();
  console.log("LandResource:", deployed.landResource);

  // ===== Configure SettingsRegistry =====
  console.log("\n--- Configuring SettingsRegistry ---");
  const keys = {
    CONTRACT_OBJECT_OWNERSHIP:  deployed.objectOwnership,
    CONTRACT_RING_ERC20_TOKEN:  deployed.ring,
    CONTRACT_KTON_ERC20_TOKEN:  deployed.kton,
    CONTRACT_GOLD_ERC20_TOKEN:  deployed.gold,
    CONTRACT_WOOD_ERC20_TOKEN:  deployed.wood,
    CONTRACT_WATER_ERC20_TOKEN: deployed.water,
    CONTRACT_FIRE_ERC20_TOKEN:  deployed.fire,
    CONTRACT_SOIL_ERC20_TOKEN:  deployed.soil,
    CONTRACT_REVENUE_POOL:      deployed.revenuePool,
    CONTRACT_LAND_BASE:         deployed.landBase,
    CONTRACT_LAND_RESOURCE:     deployed.landResource,
    CONTRACT_CLOCK_AUCTION:     deployed.clockAuction,
  };
  for (const [key, addr] of Object.entries(keys)) {
    const tx = await registry.setAddressProperty(ethers.encodeBytes32String(key), addr);
    await tx.wait();
    console.log(`  Registry[${key}] = ${addr}`);
  }

  // ===== Set Operators =====
  console.log("\n--- Setting Operators ---");
  // ObjectOwnership: LandBase can mint
  let tx = await objectOwnership.setOperator(deployed.landBase, true);
  await tx.wait();
  // ObjectOwnership: ClockAuction can transfer
  tx = await objectOwnership.setOperator(deployed.clockAuction, true);
  await tx.wait();
  // LandBase: deployer is operator (for initialization)
  tx = await landBase.setOperator(deployer.address, true);
  await tx.wait();
  // Resource tokens: LandResource can mint
  for (const token of [gold, wood, water, fire, soil]) {
    tx = await token.setOperator(deployed.landResource, true);
    await tx.wait();
  }
  // KTON: Bank can mint
  tx = await kton.setOperator(deployed.bank, true);
  await tx.wait();
  console.log("All operators configured.");

  // ===== Initialize Lands (batch, 100 at a time) =====
  console.log("\n--- Initializing 10000 lands (100 batches of 100) ---");
  const { xs, ys, rates, masks } = generateLandData();
  const BATCH = 100;
  for (let i = 0; i < 10000; i += BATCH) {
    const bxs = xs.slice(i, i + BATCH);
    const bys = ys.slice(i, i + BATCH);
    const brates = rates.slice(i, i + BATCH);
    const bmasks = masks.slice(i, i + BATCH);
    const tx = await landBase.batchAssignLands(bxs, bys, deployer.address, brates, bmasks);
    await tx.wait();
    if ((i / BATCH + 1) % 10 === 0) {
      console.log(`  Initialized ${i + BATCH} / 10000 lands`);
    }
  }
  console.log("All 10000 lands initialized!");

  // ===== Setup Genesis Auctions (list first 20 lands for testing) =====
  console.log("\n--- Setting up 20 genesis auctions ---");
  const startPrice = ethers.parseEther("10");   // 10 RING
  const endPrice   = ethers.parseEther("1");    // 1 RING
  const duration   = 7 * 24 * 3600;             // 7 days

  // Approve ClockAuction to transfer NFTs
  tx = await objectOwnership.setApprovalForAll(deployed.clockAuction, true);
  await tx.wait();

  for (let i = 0; i < 20; i++) {
    const x = i % 10;
    const y = Math.floor(i / 10);
    const tokenId = x * 10000 + y + 1;
    try {
      const atx = await clockAuction.createAuction(tokenId, startPrice, endPrice, duration);
      await atx.wait();
    } catch (e) {
      console.log(`  Auction for tokenId ${tokenId} failed: ${e.message}`);
    }
  }
  console.log("20 genesis auctions created!");

  // ===== Save deployment addresses =====
  const output = {
    network: "bscTestnet",
    chainId: 97,
    deployedAt: new Date().toISOString(),
    deployer: deployer.address,
    contracts: deployed
  };

  fs.writeFileSync("deployed.json", JSON.stringify(output, null, 2));
  console.log("\n✅ Deployment complete! Addresses saved to deployed.json");
  console.log(JSON.stringify(deployed, null, 2));
}

main().catch((e) => { console.error(e); process.exit(1); });
