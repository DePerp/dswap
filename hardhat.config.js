require('@nomicfoundation/hardhat-toolbox');
require('@nomicfoundation/hardhat-chai-matchers');
require('dotenv').config();

/** @type import('hardhat/config').HardhatUserConfig */

task("accounts", "Prints the list of accounts", async () => {
  const accounts = await hre.ethers.getSigners()

  for (const account of accounts) {
    console.info(account.address)
  }
})

module.exports = {
  defaultNetwork: 'hardhat',
  networks: {
    localhost: {
    },
    hardhat: {
      initialBaseFeePerGas: 0,
      gasPrice: 0,
    },
    base: {
    url: 'https://mainnet.base.org',
    chainId: 8453,
      accounts: [process.env.KEY],
    },
    eth: {
      url: 'https://1rpc.io/holesky',
      chainId: 17000,
        accounts: [process.env.KEY],
      },
  },
  etherscan: {
    apiKey: {
     "base": ""
    },
    customChains: [
      {
        network: "base",
        chainId: 8453,
        urls: {
         apiURL: "https://api.basescan.org/api",
         browserURL: "https://basescan.org"
        }
      }
    ]
  },
  solidity: {
    compilers: [
      {
        version: '0.8.22',
        settings: {
          viaIR: true,
          optimizer: {
            enabled: true,
            runs: 100,
          },
        },
      },
    ],
  },
};
