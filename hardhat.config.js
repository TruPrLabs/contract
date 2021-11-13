require('@nomiclabs/hardhat-waffle');
require('@nomiclabs/hardhat-etherscan');
require('dotenv').config();

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task('accounts', 'Prints the list of accounts', async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

module.exports = {
  solidity: {
    compilers: [
      {
        version: '0.8.4',
        settings: {
          optimizer: {
            // enabled: false,
            enabled: true,
            runs: 10000,
          },
        },
      },
      {
        version: '0.7.0',
      },
    ],
  },
  networks: {
    rinkeby: {
      url: process.env.ALCHEMY_KEY_RINKEBY,
      accounts: [process.env.PRIVATE_KEY1, process.env.PRIVATE_KEY2],
    },
    kovan: {
      url: process.env.ALCHEMY_KEY_KOVAN,
      accounts: [process.env.PRIVATE_KEY1, process.env.PRIVATE_KEY2],
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_KEY,
  },
};
