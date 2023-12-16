require("@nomiclabs/hardhat-waffle");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});
//https://goerli.infura.io/v3/e4dc43ec8db64b0cbd34f7d424f51b53
// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.8.20",
  networks: {
    hardhat: {
      forking: {
        url: `https://goerli.infura.io/v3/${"e4dc43ec8db64b0cbd34f7d424f51b53"}`,
      },
    },
  },
};
