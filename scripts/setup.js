/**
 * setup.js — 元宇宙 Metaverse 初始化脚本
 *
 * 功能：
 *  1. 铸造 20 块土地（通过 LandInitializer）
 *  2. 铸造 10 个使徒 NFT（直接调用 mint）
 *  3. 铸造 10 个钒头 NFT
 *  4. 在地块 1-5 上各放 1个使徒 + 1个钒头（共 5 块地）
 *  5. 将地块 6-10 挂卖到拍卖市场
 *  6. PancakeSwap: 添加 5 个交易对流动性（RING-GOLD/WOOD/HHO/FIRE/SIOO）
 *  7. 另加 RING-BNB 流动性
 *
 * 运行: npx hardhat run scripts/setup.js --network bscTestnet
 */

const { ethers } = require("hardhat");

// ── 已部署的合约地址 ──────────────────────────────────────────────
const ADDR = {
  ring:        "0x41550a11B94ee1c78898FEaae0617AAC3E155ec6",
  gold:        "0xbFaEb7b0BeD3684051F8d087717009eEd131C69f",
  wood:        "0x138C98Ca717917C584D878028bB02fB0BAc6E2c4",
  water:       "0x3618bCa0A8B4a56E1cC57b6B6F4e145104f4ea49",
  fire:        "0x3fb8134A6FFedc5bc467179905955fbE25780B33",
  soil:        "0xedAED55F28480839C5417D54160a1E0dDA7E9f13",
  land:        "0x6cE20f0306036F6f17e0D69B5Cd6b5d5D0EBf073",
  drill:       "0xbA1C81247D9627b4F6EF4E40febB8D70E7bEd9Fe",
  apostle:     "0x3D06422b6623b422c4152cd53231f0F45232197A",
  mining:      "0x9eAcA7E8d08767BE5c00C92A7721FB4aC60ea3F2",
  auction:     "0x6dfAEDBD161f99d655a818AF23377344FB16db1a",
  initializer: "0x78707C585E3C28D6f861b9b3Ef14b0e665f52a7B",
  referral:    "0xdefE1Df8a0F2bd91e6F2d88E564BDD511Ce87b1c",
  blindbox:    "0x77AAB7a9CD934D9aEc5fE60b15DbFbCDe5BC6252",
};

// PancakeSwap Testnet
const PANCAKE_ROUTER = "0xD99D1c33F9fC3444f8101754aBC46c52416550d1";
const WBNB           = "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd";

const ROUTER_ABI = [
  "function addLiquidity(address tokenA, address tokenB, uint256 amountADesired, uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline) returns (uint256, uint256, uint256)",
  "function addLiquidityETH(address token, uint256 amountTokenDesired, uint256 amountTokenMin, uint256 amountETHMin, address to, uint256 deadline) payable returns (uint256, uint256, uint256)",
];

const ERC20_ABI = [
  "function approve(address spender, uint256 amount) returns (bool)",
  "function balanceOf(address) view returns (uint256)",
  "function mint(address to, uint256 amount)",
  "function setMinter(address minter, bool enabled)",
];

const LAND_ABI = [
  "function ownerOf(uint256) view returns (address)",
  "function setApprovalForAll(address operator, bool approved)",
  "function isApprovedForAll(address owner, address operator) view returns (bool)",
];

const INIT_ABI = [
  "function batchMint(int16[] calldata xs, int16[] calldata ys, uint80[] calldata attrs)",
];

const APOSTLE_ABI = [
  "function mint(address to, uint8 strength, uint8 element) returns (uint256)",
  "function setApprovalForAll(address operator, bool approved)",
  "function ownerOf(uint256) view returns (address)",
  "function nextId() view returns (uint256)",
];

const DRILL_ABI = [
  "function mint(address to, uint8 tier, uint8 affinity) returns (uint256)",
  "function setApprovalForAll(address operator, bool approved)",
  "function ownerOf(uint256) view returns (address)",
  "function nextId() view returns (uint256)",
];

const MINING_ABI = [
  "function startMining(uint256 landId, uint256 apostleId, uint256 drillId)",
];

const AUCTION_ABI = [
  "function createAuction(uint256 id, uint128 startPrice, uint128 endPrice, uint64 duration)",
];

function encodeAttr(g, w, wa, f, s) {
  return (
    BigInt(g) | (BigInt(w) << 16n) | (BigInt(wa) << 32n) |
    (BigInt(f) << 48n) | (BigInt(s) << 64n)
  );
}

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("\n🚀 元宇宙初始化脚本");
  console.log("  deployer:", deployer.address);
  const bal = await ethers.provider.getBalance(deployer.address);
  console.log("  tBNB bal:", ethers.formatEther(bal), "\n");

  const ring    = new ethers.Contract(ADDR.ring,        ERC20_ABI,    deployer);
  const land    = new ethers.Contract(ADDR.land,        LAND_ABI,     deployer);
  const init    = new ethers.Contract(ADDR.initializer, INIT_ABI,     deployer);
  const apoC    = new ethers.Contract(ADDR.apostle,     APOSTLE_ABI,  deployer);
  const drillC  = new ethers.Contract(ADDR.drill,       DRILL_ABI,    deployer);
  const mining  = new ethers.Contract(ADDR.mining,      MINING_ABI,   deployer);
  const auction = new ethers.Contract(ADDR.auction,     AUCTION_ABI,  deployer);
  const router  = new ethers.Contract(PANCAKE_ROUTER,   ROUTER_ABI,   deployer);

  // ── 1. 铸造 20 块土地 ─────────────────────────────────────────────────
  console.log("[1/6] 铸造 20 块土地...");
  {
    const xs = [], ys = [], attrs = [];
    for (let i = 0; i < 20; i++) {
      xs.push(i); ys.push(0);
      const s = i * 137;
      attrs.push(encodeAttr(
        (s * 3  + 10) % 100 + 5,
        (s * 7  + 20) % 100 + 5,
        (s * 11 + 30) % 100 + 5,
        (s * 13 + 40) % 100 + 5,
        (s * 17 + 50) % 100 + 5
      ));
    }
    const tx = await init.batchMint(xs, ys, attrs);
    await tx.wait();
    console.log("  ✅ 20 块土地铸造完成");
  }

  // ── 2. 铸造 10 个使徒 ───────────────────────────────────────────────
  console.log("\n[2/6] 铸造 10 个使徒 NFT...");
  const apostleIds = [];
  for (let i = 0; i < 10; i++) {
    const strength = 30 + i * 7;  // 30,37,44...93
    const element  = i % 5;       // 0-4 cycle
    const tx = await apoC.mint(deployer.address, strength, element);
    const rc = await tx.wait();
    // ID = nextId before mint, but we track from nextId
    apostleIds.push(i + 1);
    console.log(`  使徒 #${i+1}: 力量=${strength} 元素=${['\u91d1','\u6728','\u6c34','\u706b','\u571f'][element]}`);
  }

  // ── 3. 铸造 10 个钒头 ───────────────────────────────────────────────
  console.log("\n[3/6] 铸造 10 个钒头 NFT...");
  const drillIds = [];
  for (let i = 0; i < 10; i++) {
    const tier     = (i % 5) + 1;  // 1-5
    const affinity = i % 5;
    const tx = await drillC.mint(deployer.address, tier, affinity);
    await tx.wait();
    drillIds.push(i + 1);
    console.log(`  钒头 #${i+1}: 等级=${'\u2605'.repeat(tier)} 亲和=${['\u91d1','\u6728','\u6c34','\u706b','\u571f'][affinity]}`);
  }

  // ── 4. 地块 1-5 开启挖矿 (使徒+钒头) ──────────────────────────────────
  console.log("\n[4/6] 地块 1-5 开启挖矿...");
  {
    // Approve mining to manage apostles and drills
    let tx;
    tx = await apoC.setApprovalForAll(ADDR.mining, true); await tx.wait();
    tx = await drillC.setApprovalForAll(ADDR.mining, true); await tx.wait();
    // Land must be approved for mining to escrow
    tx = await land.setApprovalForAll(ADDR.mining, true); await tx.wait();
    console.log("  授权完成");

    for (let i = 0; i < 5; i++) {
      const landId    = i + 1;
      const apostleId = i + 1;
      const drillId   = i + 1;
      try {
        const tx = await mining.startMining(landId, apostleId, drillId);
        await tx.wait();
        console.log(`  ✅ 地块 #${landId} 开启挖矿（使徒#${apostleId} + 钒头#${drillId}）`);
      } catch(e) {
        console.log(`  ⚠️  地块 #${landId} 挖矿失败: ${e.reason ?? e.message}`);
      }
    }
  }

  // ── 5. 地块 6-10 挂卖到拍卖市场 ──────────────────────────────────────────
  console.log("\n[5/6] 地块 6-10 挂卖到拍卖市场...");
  {
    // Approve auction contract to transfer land NFTs
    const approved = await land.isApprovedForAll(deployer.address, ADDR.auction);
    if (!approved) {
      const tx = await land.setApprovalForAll(ADDR.auction, true);
      await tx.wait();
    }

    // Approve auction to spend RING (for fee)
    const approveTx = await ring.approve(ADDR.auction, ethers.parseEther("10000"));
    await approveTx.wait();

    const startPrices = [10, 8, 12, 6, 15];   // RING
    const endPrices   = [2,  1,  3, 1,  2];   // RING
    const DURATION    = 3 * 24 * 3600;         // 3天

    for (let i = 0; i < 5; i++) {
      const landId = i + 6;
      try {
        const tx = await auction.createAuction(
          landId,
          ethers.parseEther(String(startPrices[i])),
          ethers.parseEther(String(endPrices[i])),
          DURATION
        );
        await tx.wait();
        console.log(`  ✅ 地块 #${landId} 挂卖 ${startPrices[i]}→${endPrices[i]} RING (3天)`);
      } catch(e) {
        console.log(`  ⚠️  地块 #${landId} 挂卖失败: ${e.reason ?? e.message}`);
      }
    }
  }

  // ── 6. PancakeSwap 添加流动性 ────────────────────────────────────────
  console.log("\n[6/6] 添加流动性...");
  const deadline = Math.floor(Date.now() / 1000) + 1800;
  const RING_PER_PAIR  = ethers.parseEther("200");    // 200 RING per pair
  const RES_PER_PAIR   = ethers.parseEther("1000");   // 1000 resource token
  const BNB_FOR_RING   = ethers.parseEther("0.05");   // 0.05 BNB for RING-BNB
  const RING_FOR_BNB   = ethers.parseEther("100");    // 100 RING for RING-BNB

  // Approve router to spend RING (large amount for all pairs)
  const totalRingNeeded = RING_PER_PAIR * 5n + RING_FOR_BNB;
  let tx = await ring.approve(PANCAKE_ROUTER, totalRingNeeded);
  await tx.wait();
  console.log("  RING 已授权给 Router");

  // Resource tokens approve
  const resourceAddrs = [ADDR.gold, ADDR.wood, ADDR.water, ADDR.fire, ADDR.soil];
  const resourceNames = ["GOLD", "WOOD", "HHO", "FIRE", "SIOO"];

  // Mint resource tokens to deployer if needed (deployer should have minter role via MiningSystem)
  // Actually resource tokens mint only via mining system... 
  // We'll use setMinter on resource tokens to mint directly for LP seeding
  // Note: resource tokens were minted only via MiningSystem — we need to set deployer as minter temporarily
  const RESOURCE_ABI_FULL = [
    "function setMinter(address minter, bool enabled)",
    "function mint(address to, uint256 amount)",
    "function approve(address spender, uint256 amount) returns (bool)",
    "function balanceOf(address) view returns (uint256)",
  ];

  for (let i = 0; i < 5; i++) {
    const resToken = new ethers.Contract(resourceAddrs[i], RESOURCE_ABI_FULL, deployer);
    // Enable deployer as minter temporarily
    try {
      const t1 = await resToken.setMinter(deployer.address, true); await t1.wait();
      const t2 = await resToken.mint(deployer.address, RES_PER_PAIR); await t2.wait();
      console.log(`  铸造 1000 ${resourceNames[i]}`);
    } catch(e) {
      console.log(`  ⚠️  无法铸造 ${resourceNames[i]}: ${e.reason ?? e.message}`);
      continue;
    }

    // Approve resource token
    const t3 = await resToken.approve(PANCAKE_ROUTER, RES_PER_PAIR); await t3.wait();

    // Add liquidity RING + Resource
    try {
      const t4 = await router.addLiquidity(
        ADDR.ring, resourceAddrs[i],
        RING_PER_PAIR, RES_PER_PAIR,
        0n, 0n,
        deployer.address,
        deadline
      );
      await t4.wait();
      console.log(`  ✅ RING-${resourceNames[i]} 流动性添加成功`);
    } catch(e) {
      console.log(`  ⚠️  RING-${resourceNames[i]} LP 失败: ${e.reason ?? e.message}`);
    }
  }

  // Add RING-BNB liquidity
  try {
    const t5 = await router.addLiquidityETH(
      ADDR.ring,
      RING_FOR_BNB,
      0n, 0n,
      deployer.address,
      deadline,
      { value: BNB_FOR_RING }
    );
    await t5.wait();
    console.log("  ✅ RING-BNB 流动性添加成功");
  } catch(e) {
    console.log(`  ⚠️  RING-BNB LP 失败: ${e.reason ?? e.message}`);
  }

  console.log("\n✨ 全部初始化完成!");
  console.log("下一步: 刷新前端即可看到地图、市场和池子数据");
}

main().catch(e => { console.error(e); process.exit(1); });
