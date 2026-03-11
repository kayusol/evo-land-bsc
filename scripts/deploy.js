const { ethers } = require("hardhat");
const fs = require("fs");

// Must match contracts: keccak256(abi.encodePacked("KEY"))
function key(name) {
  return ethers.keccak256(ethers.toUtf8Bytes(name));
}

function encodeResourceRate(gold, wood, water, fire, soil) {
  return BigInt(gold) |
    (BigInt(wood)  << 16n) |
    (BigInt(water) << 32n) |
    (BigInt(fire)  << 48n) |
    (BigInt(soil)  << 64n);
}

function generateLandData() {
  const xs = [], ys = [], rates = [], masks = [];
  for (let x = 0; x <= 99; x++) {
    for (let y = 0; y <= 99; y++) {
      const seed = x * 137 + y * 97;
      const gold  = ((seed * 3  + 10) % 100) + 5;
      const wood  = ((seed * 7  + 20) % 100) + 5;
      const water = ((seed * 11 + 30) % 100) + 5;
      const fire  = ((seed * 13 + 40) % 100) + 5;
      const soil  = ((seed * 17 + 50) % 100) + 5;
      let mask = 0;
      if ((x === 0  && y === 0)  || (x === 99 && y === 99) ||
          (x === 0  && y === 99) || (x === 99 && y === 0)  ||
          (x === 49 && y === 49) || (x === 50 && y === 50)) {
        mask = 2;
      }
      xs.push(x); ys.push(y);
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
  console.log("Balance:", ethers.formatEther(balance), "tBNB\n");

  const deployed = {};

  // 1. SettingsRegistry
  console.log("[1/10] Deploying SettingsRegistry...");
  const registry = await (await ethers.getContractFactory("SettingsRegistry")).deploy();
  await registry.waitForDeployment();
  deployed.settingsRegistry = await registry.getAddress();
  console.log("  =>", deployed.settingsRegistry);

  // 2. ObjectOwnership
  console.log("[2/10] Deploying ObjectOwnership...");
  const objectOwnership = await (await ethers.getContractFactory("ObjectOwnership")).deploy();
  await objectOwnership.waitForDeployment();
  deployed.objectOwnership = await objectOwnership.getAddress();
  console.log("  =>", deployed.objectOwnership);

  // 3. RING
  console.log("[3/10] Deploying RING Token...");
  const ring = await (await ethers.getContractFactory("RingToken")).deploy();
  await ring.waitForDeployment();
  deployed.ring = await ring.getAddress();
  console.log("  =>", deployed.ring, "(supply:", ethers.formatEther(await ring.totalSupply()), "RING)");

  // 4. KTON
  console.log("[4/10] Deploying KTON Token...");
  const kton = await (await ethers.getContractFactory("KtonToken")).deploy();
  await kton.waitForDeployment();
  deployed.kton = await kton.getAddress();
  console.log("  =>", deployed.kton);

  // 5. Resource tokens
  console.log("[5/10] Deploying Resource Tokens...");
  const RT = await ethers.getContractFactory("ResourceToken");
  const gold  = await (await RT.deploy("Evolution Land Gold",  "GOLD")).waitForDeployment();
  const wood  = await (await RT.deploy("Evolution Land Wood",  "WOOD")).waitForDeployment();
  const water = await (await RT.deploy("Evolution Land Water", "HHO" )).waitForDeployment();
  const fire  = await (await RT.deploy("Evolution Land Fire",  "FIRE")).waitForDeployment();
  const soil  = await (await RT.deploy("Evolution Land Soil",  "SIOO")).waitForDeployment();
  deployed.gold  = await gold.getAddress();
  deployed.wood  = await wood.getAddress();
  deployed.water = await water.getAddress();
  deployed.fire  = await fire.getAddress();
  deployed.soil  = await soil.getAddress();
  console.log("  GOLD:", deployed.gold);
  console.log("  WOOD:", deployed.wood);
  console.log("  HHO:", deployed.water);
  console.log("  FIRE:", deployed.fire);
  console.log("  SIOO:", deployed.soil);

  // 6. RevenuePool
  console.log("[6/10] Deploying RevenuePool...");
  const revenuePool = await (await ethers.getContractFactory("RevenuePool")).deploy(deployed.ring);
  await revenuePool.waitForDeployment();
  deployed.revenuePool = await revenuePool.getAddress();
  console.log("  =>", deployed.revenuePool);

  // 7. LandBase
  console.log("[7/10] Deploying LandBase...");
  const landBase = await (await ethers.getContractFactory("LandBase")).deploy(deployed.settingsRegistry);
  await landBase.waitForDeployment();
  deployed.landBase = await landBase.getAddress();
  console.log("  =>", deployed.landBase);

  // 8. ClockAuction
  console.log("[8/10] Deploying ClockAuction...");
  const clockAuction = await (await ethers.getContractFactory("ClockAuction")).deploy(deployed.settingsRegistry);
  await clockAuction.waitForDeployment();
  deployed.clockAuction = await clockAuction.getAddress();
  console.log("  =>", deployed.clockAuction);

  // 9. GringottsBank
  console.log("[9/10] Deploying GringottsBank...");
  const bank = await (await ethers.getContractFactory("GringottsBank")).deploy(deployed.ring, deployed.kton);
  await bank.waitForDeployment();
  deployed.bank = await bank.getAddress();
  console.log("  =>", deployed.bank);

  // 10. LandResource
  console.log("[10/10] Deploying LandResource...");
  const landResource = await (await ethers.getContractFactory("LandResource")).deploy(deployed.settingsRegistry);
  await landResource.waitForDeployment();
  deployed.landResource = await landResource.getAddress();
  console.log("  =>", deployed.landResource);

  // Configure SettingsRegistry
  console.log("\n--- Configuring SettingsRegistry ---");
  const entries = [
    ["CONTRACT_OBJECT_OWNERSHIP",  deployed.objectOwnership],
    ["CONTRACT_RING_ERC20_TOKEN",  deployed.ring],
    ["CONTRACT_KTON_ERC20_TOKEN",  deployed.kton],
    ["CONTRACT_GOLD_ERC20_TOKEN",  deployed.gold],
    ["CONTRACT_WOOD_ERC20_TOKEN",  deployed.wood],
    ["CONTRACT_WATER_ERC20_TOKEN", deployed.water],
    ["CONTRACT_FIRE_ERC20_TOKEN",  deployed.fire],
    ["CONTRACT_SOIL_ERC20_TOKEN",  deployed.soil],
    ["CONTRACT_REVENUE_POOL",      deployed.revenuePool],
    ["CONTRACT_LAND_BASE",         deployed.landBase],
    ["CONTRACT_LAND_RESOURCE",     deployed.landResource],
    ["CONTRACT_CLOCK_AUCTION",     deployed.clockAuction],
  ];
  for (const [name, addr] of entries) {
    const tx = await registry.setAddressProperty(key(name), addr);
    await tx.wait();
    console.log(`  [${name}] = ${addr}`);
  }

  // Set Operators
  console.log("\n--- Setting Operators ---");
  let tx;
  tx = await objectOwnership.setOperator(deployed.landBase, true);    await tx.wait();
  tx = await objectOwnership.setOperator(deployed.clockAuction, true); await tx.wait();
  tx = await landBase.setOperator(deployer.address, true);             await tx.wait();
  for (const token of [gold, wood, water, fire, soil]) {
    tx = await token.setOperator(deployed.landResource, true); await tx.wait();
  }
  tx = await kton.setOperator(deployed.bank, true); await tx.wait();
  console.log("All operators configured.");

  // Initialize Lands (batches of 50 to stay within gas limit)
  console.log("\n--- Initializing 10000 lands ---");
  const { xs, ys, rates, masks } = generateLandData();
  const BATCH = 50;
  for (let i = 0; i < 10000; i += BATCH) {
    const bxs    = xs.slice(i, i + BATCH);
    const bys    = ys.slice(i, i + BATCH);
    const brates = rates.slice(i, i + BATCH);
    const bmasks = masks.slice(i, i + BATCH);
    tx = await landBase.batchAssignLands(bxs, bys, deployer.address, brates, bmasks,
      { gasLimit: 8000000 });
    await tx.wait();
    if ((i / BATCH + 1) % 20 === 0) {
      console.log(`  ${i + BATCH} / 10000 lands initialized`);
    }
  }
  console.log("All 10000 lands initialized!");

  // Genesis Auctions
  console.log("\n--- Creating 20 genesis auctions ---");
  const startPrice = ethers.parseEther("10");
  const endPrice   = ethers.parseEther("1");
  const duration   = 7 * 24 * 3600;
  tx = await objectOwnership.setApprovalForAll(deployed.clockAuction, true);
  await tx.wait();

  for (let i = 0; i < 20; i++) {
    const x = i % 10, y = Math.floor(i / 10);
    const tokenId = x * 10000 + y + 1;
    try {
      tx = await clockAuction.createAuction(tokenId, startPrice, endPrice, duration);
      await tx.wait();
    } catch (e) {
      console.log(`  tokenId ${tokenId} auction failed: ${e.message.slice(0, 80)}`);
    }
  }
  console.log("Genesis auctions created!");

  // Save
  const output = {
    network: "bscTestnet", chainId: 97,
    deployedAt: new Date().toISOString(),
    deployer: deployer.address,
    contracts: deployed
  };
  fs.writeFileSync("deployed.json", JSON.stringify(output, null, 2));
  console.log("\n✅ DEPLOYMENT COMPLETE");
  console.log(JSON.stringify(deployed, null, 2));
}

main().catch((e) => { console.error(e); process.exit(1); });
