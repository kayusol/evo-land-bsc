# Evolution Land BSC — Simplified Single-Chain Edition

## Contracts (all in `contracts/EvoLandBSC.sol`)

| Contract | Role |
|---|---|
| `RingToken` | Main currency (ERC20, 10k initial supply) |
| `GoldToken` / `WoodToken` / `WaterToken` / `FireToken` / `SoilToken` | Resource tokens minted by mining |
| `LandNFT` | 10,000 land parcels (100×100 grid), each with resource rates |
| `DrillNFT` | Equipment NFT, tier 1-5, boosts mining rate for one resource |
| `ApostleNFT` | Worker NFT, strength 1-100, sent to mine on lands |
| `MiningSystem` | Core loop: stake apostle+drill on land → earn resources |
| `LandAuction` | Dutch auction for land sales (4% fee, paid in RING) |
| `LandInitializer` | Batch-mint utility for genesis setup |

## Mining Formula
```
output (wei/s) = landRate * (apostleStrength/50) * drillBoost * 1e18 / 86400
drillBoost = 1.0 + tier*0.2  (if drill affinity matches resource, else 1.0)
```

## Deploy
```bash
npm install
PRIVATE_KEY=0x... npx hardhat run scripts/deploy.js --network bscTestnet
```
