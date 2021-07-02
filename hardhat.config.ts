import 'dotenv/config';
import {HardhatUserConfig} from 'hardhat/types';
import 'hardhat-deploy';
import 'hardhat-deploy-ethers';
import 'hardhat-gas-reporter';
import {node_url, accounts} from './utils/networks';

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: '0.8.4',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  networks: {
    hardhat: {
      accounts: accounts('localhost'),
    },
    localhost: {
      url: 'http://localhost:8545',
      accounts: accounts('localhost'),
    },
    testnet: {
      url: 'https://data-seed-prebsc-1-s1.binance.org:8545',
      accounts: accounts('testnet'),
      live: true,
    },
    mainnet: {
      url: 'https://bsc-dataseed.binance.org',
      accounts: accounts('mainnet'),
      live: true,
    },
    matic: {
      url: 'https://rpc-mainnet.maticvigil.com/v1/a50eb5139e4cb2ce865cf47c1b664985eb69b86e',
      accounts: accounts('matic'),
      live: true,
    },
  },
  gasReporter: {
    currency: 'USD',
    gasPrice: 5,
    enabled: !!process.env.REPORT_GAS,
  },
  namedAccounts: {
    creator: 1,
  },
};

export default config;
