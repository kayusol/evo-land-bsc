require("@nomicfoundation/hardhat-toolbox");

const PRIVATE_KEY = process.env.PRIVATE_KEY || "";

module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: { enabled: true, runs: 200 }
    }
  },
  networks: {
    bscTestnet: {
      url: "https://bsc-testnet-rpc.publicnode.com",
      chainId: 97,
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
      gasPrice: 10000000000,
      timeout: 120000,
      nonce: "pending"
    }
  },
  etherscan: {
    apiKey: { bscTestnet: process.env.BSCSCAN_API_KEY || "placeholder" },
    customChains: [{
      network: "bscTestnet",
      chainId: 97,
      urls: {
        apiURL: "https://api-testnet.bscscan.com/api",
        browserURL: "https://testnet.bscscan.com"
      }
    }]
  }
};
