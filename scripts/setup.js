/**
 * setup.js — 元宇宙初始化脚本
 * 运行: npx hardhat run scripts/setup.js --network bscTestnet
 */
const { ethers } = require("hardhat");

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
};
const ROUTER = "0xD99D1c33F9fC3444f8101754aBC46c52416550d1";

// ── ABIs (完全匹配合约源码) ────────────────────────────────────────
// LandInitializer.batchMint 有4个参数，第4个是 address to
const INIT_ABI = [
  "function batchMint(int16[] calldata xs, int16[] calldata ys, uint80[] calldata attrs, address to) external",
  "function owner() view returns (address)",
];
const LAND_ABI = [
  "function setApprovalForAll(address operator, bool approved)",
  "function isApprovedForAll(address owner, address operator) view returns (bool)",
  "function ownerOf(uint256) view returns (address)",
];
const APOSTLE_ABI = [
  "function mint(address to, uint8 strength, uint8 element) returns (uint256)",
  "function setApprovalForAll(address operator, bool approved)",
];
const DRILL_ABI = [
  "function mint(address to, uint8 tier, uint8 affinity) returns (uint256)",
  "function setApprovalForAll(address operator, bool approved)",
];
const MINING_ABI = [
  "function startMining(uint256 landId, uint256 apostleId, uint256 drillId)",
];
const AUCTION_ABI = [
  "function createAuction(uint256 id, uint128 startPrice, uint128 endPrice, uint64 duration)",
];
const ERC20_ABI = [
  "function approve(address spender, uint256 amount) returns (bool)",
  "function setMinter(address minter, bool enabled)",
  "function mint(address to, uint256 amount)",
];
const ROUTER_ABI = [
  "function addLiquidity(address tokenA, address tokenB, uint256 amountADesired, uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline) returns (uint256, uint256, uint256)",
  "function addLiquidityETH(address token, uint256 amountTokenDesired, uint256 amountTokenMin, uint256 amountETHMin, address to, uint256 deadline) payable returns (uint256, uint256, uint256)",
];

function encodeAttr(g, w, wa, f, s) {
  return (BigInt(g) | (BigInt(w)<<16n) | (BigInt(wa)<<32n) | (BigInt(f)<<48n) | (BigInt(s)<<64n));
}

const sleep = ms => new Promise(r => setTimeout(r, ms));

async function sendTx(contract, fn, args, opts = {}) {
  for (let retry = 0; retry < 5; retry++) {
    try {
      const tx = await contract[fn](...args, ...(Object.keys(opts).length ? [opts] : []));
      process.stdout.write(`  [tx] ${tx.hash.slice(0,12)}... `);
      await tx.wait();
      process.stdout.write('ok\n');
      await sleep(1500);
      return;
    } catch(e) {
      const msg = (e.message||'').toLowerCase();
      if (msg.includes('rate') || msg.includes('429')) {
        const w = 3000 * (2**retry);
        console.log(`\n  ⚠ 限速，等待 ${w}ms...`);
        await sleep(w); continue;
      }
      throw e;
    }
  }
}

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("\n🚀 元宇宙初始化");
  console.log("  deployer:", deployer.address);
  const bal = await ethers.provider.getBalance(deployer.address);
  console.log("  tBNB:", ethers.formatEther(bal), "\n");

  const init    = new ethers.Contract(ADDR.initializer, INIT_ABI,    deployer);
  const land    = new ethers.Contract(ADDR.land,        LAND_ABI,    deployer);
  const apoC    = new ethers.Contract(ADDR.apostle,     APOSTLE_ABI, deployer);
  const drillC  = new ethers.Contract(ADDR.drill,       DRILL_ABI,   deployer);
  const mining  = new ethers.Contract(ADDR.mining,      MINING_ABI,  deployer);
  const auction = new ethers.Contract(ADDR.auction,     AUCTION_ABI, deployer);
  const ring    = new ethers.Contract(ADDR.ring,        ERC20_ABI,   deployer);
  const router  = new ethers.Contract(ROUTER,           ROUTER_ABI,  deployer);

  // 检查 owner
  const owner = await init.owner();
  console.log("LandInitializer.owner:", owner);
  if (owner.toLowerCase() !== deployer.address.toLowerCase()) {
    throw new Error(`你不是 owner！owner=${owner}, 你=${deployer.address}`);
  }

  // ── 1. 铸造 20 块土地（分2批，每批10块）────────────────────
  console.log("[1/6] 铸造 20 块土地...");
  for (let batch = 0; batch < 2; batch++) {
    const xs = [], ys = [], attrs = [];
    for (let i = batch*10; i < batch*10+10; i++) {
      xs.push(i); ys.push(0);
      const s = i * 137;
      attrs.push(encodeAttr((s*3+10)%100+5,(s*7+20)%100+5,(s*11+30)%100+5,(s*13+40)%100+5,(s*17+50)%100+5));
    }
    // 第4个参数 to = deployer 自己
    await sendTx(init, 'batchMint', [xs, ys, attrs, deployer.address]);
    console.log(`  ✅ 第${batch+1}批 地块 #${batch*10+1}-${batch*10+10}`);
  }

  // ── 2. 铸造 10 个使徒 ─────────────────────────────────────
  console.log("\n[2/6] 铸造 10 个使徒...");
  for (let i = 0; i < 10; i++) {
    await sendTx(apoC, 'mint', [deployer.address, 30+i*7, i%5]);
    console.log(`  ✅ 使徒 #${i+1}: 力量=${30+i*7} 元素=${'金木水火土'[i%5]}`);
  }

  // ── 3. 铸造 10 个钻头 ─────────────────────────────────────
  console.log("\n[3/6] 铸造 10 个钻头...");
  for (let i = 0; i < 10; i++) {
    await sendTx(drillC, 'mint', [deployer.address, (i%5)+1, i%5]);
    console.log(`  ✅ 钻头 #${i+1}: ${'★'.repeat((i%5)+1)} 亲和=${'金木水火土'[i%5]}`);
  }

  // ── 4. 地块1-5 开挖矿 ─────────────────────────────────────
  console.log("\n[4/6] 地块1-5 开挖矿...");
  await sendTx(apoC,  'setApprovalForAll', [ADDR.mining, true]);
  await sendTx(drillC,'setApprovalForAll', [ADDR.mining, true]);
  await sendTx(land,  'setApprovalForAll', [ADDR.mining, true]);
  console.log("  ✅ 三项 NFT 授权完成");
  for (let i = 0; i < 5; i++) {
    try {
      await sendTx(mining, 'startMining', [i+1, i+1, i+1]);
      console.log(`  ✅ 地块 #${i+1} 挖矿中`);
    } catch(e) { console.log(`  ⚠ 地块 #${i+1}: ${e.reason||e.message}`); }
  }

  // ── 5. 地块6-10 挂拍卖 ────────────────────────────────────
  console.log("\n[5/6] 地块6-10 挂拍卖...");
  await sendTx(land, 'setApprovalForAll', [ADDR.auction, true]);
  await sendTx(ring, 'approve', [ADDR.auction, ethers.parseEther('100000')]);
  const SP=[10,8,12,6,15], EP=[2,1,3,1,2], DUR=3*24*3600;
  for (let i = 0; i < 5; i++) {
    try {
      await sendTx(auction,'createAuction',[i+6,ethers.parseEther(String(SP[i])),ethers.parseEther(String(EP[i])),DUR]);
      console.log(`  ✅ 地块 #${i+6}: ${SP[i]}→${EP[i]} RING (3天)`);
    } catch(e) { console.log(`  ⚠ 地块 #${i+6}: ${e.reason||e.message}`); }
  }

  // ── 6. 加流动性 ───────────────────────────────────────────
  console.log("\n[6/6] 添加流动性...");
  const RING_PP=ethers.parseEther('200'), RES_PP=ethers.parseEther('1000');
  const dl=BigInt(Math.floor(Date.now()/1000)+1800);
  const resAddrs=[ADDR.gold,ADDR.wood,ADDR.water,ADDR.fire,ADDR.soil];
  const resNames=['GOLD','WOOD','HHO','FIRE','SIOO'];
  await sendTx(ring,'approve',[ROUTER,ethers.parseEther('1200')]);
  for (let i = 0; i < 5; i++) {
    const resC=new ethers.Contract(resAddrs[i],ERC20_ABI,deployer);
    try {
      await sendTx(resC,'setMinter',[deployer.address,true]);
      await sendTx(resC,'mint',[deployer.address,RES_PP]);
      await sendTx(resC,'approve',[ROUTER,RES_PP]);
      await sendTx(router,'addLiquidity',[ADDR.ring,resAddrs[i],RING_PP,RES_PP,0n,0n,deployer.address,dl]);
      console.log(`  ✅ RING-${resNames[i]} LP`);
    } catch(e) { console.log(`  ⚠ RING-${resNames[i]}: ${e.reason||e.message}`); }
  }
  try {
    await sendTx(ring,'approve',[ROUTER,ethers.parseEther('100')]);
    await sendTx(router,'addLiquidityETH',[ADDR.ring,ethers.parseEther('100'),0n,0n,deployer.address,dl],{value:ethers.parseEther('0.05')});
    console.log('  ✅ RING-BNB LP');
  } catch(e) { console.log(`  ⚠ RING-BNB: ${e.reason||e.message}`); }

  console.log("\n🎉 初始化完成！刷新前端查看数据。");
}

main().catch(e => { console.error('❌', e.message); process.exit(1); });
