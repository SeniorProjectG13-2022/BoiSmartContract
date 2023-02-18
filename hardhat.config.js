const hardhat = require("hardhat/config");
const { usePlugin } = hardhat;
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-ethers");
// require("@nomiclabs/hardhat-etherscan");
// require("@nomiclabs/hardhat-truffle5");
// require("./scripts/moloch-tasks");
// require("./scripts/pool-tasks");

const INFURA_API_KEY = "";
const MAINNET_PRIVATE_KEY = "";
const ROPSTEN_PRIVATE_KEY = "";
const ETHERSCAN_API_KEY = "";

module.exports = {
  networks: {
    develop: {
      url: "http://localhost:8545",
      deployedContracts: {
        moloch: "",
        pool: "",
      },
    },
    goerli: {
      url: "https://eth-goerli.g.alchemy.com/v2/Qzotqx0kES_6vpzCAVHL_vGX_7lAEQs8", //process.env.GOERLI_URL || "",
      accounts: [
        "cd385b618b23e3416a14efc407866aec72ef532207c51cae5d89cb0b8a359e05",
      ],
      //process.env.GOERLI_PRIVATE_KEY !== undefined ? [process.env.GOERLI_PRIVATE_KEY] : [],
    },
    /* ropsten: {
      url: `https://ropsten.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [ROPSTEN_PRIVATE_KEY],
      deployedContracts: {
        moloch: "",
        pool: ""
      }
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [MAINNET_PRIVATE_KEY],
      deployedContracts: {
        moloch: "0x1fd169A4f5c59ACf79d0Fd5d91D1201EF1Bce9f1", // The original Moloch
        pool: ""
      }
    }, */
    coverage: {
      url: "http://localhost:8555",
    },
  },
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  /*
  etherscan: {
    // The url for the Etherscan API you want to use.
    // For example, here we're using the one for the Ropsten test network
    url: "https://api.etherscan.io/api",
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: ETHERSCAN_API_KEY
  } */
};
