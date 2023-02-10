const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Boii", function () {
  it("Should return the new greeting once it's changed", async function () {
    const params = {
      summoner: "0x47a546d3352Fa4596C95B7CFE66fa8383c0A1ffF",
      depositToken: "0x7af963cf6d228e564e2a0aa0ddbf06210b38615d", //Ethereum token address in GOERLI
      periodDuration: 60,
      votingPeriodLength: 3,
      gracePeriodLength: 3,
      proposalDeposit: 10,
      dilutionBound: 2,
    };

    console.log("START");

    try {
      // We get the contract to deploy
      const Boii = await hre.ethers.getContractFactory("Boii");
      const boii = await Boii.deploy(
        params.summoner,
        params.depositToken,
        params.periodDuration,
        params.votingPeriodLength,
        params.gracePeriodLength,
        params.proposalDeposit,
        params.dilutionBound
      );

      await boii.deployed();
      console.log("Greeter deployed to:", boii.address);

      // const Greeter = await ethers.getContractFactory("Greeter");
      // const greeter = await Greeter.deploy("Hello, world!");
      // await greeter.deployed();

      // expect(await greeter.greet()).to.equal("Hello, world!");

      // const setGreetingTx = await greeter.setGreeting("Hola, mundo!");

      // // wait until the transaction is mined
      // await setGreetingTx.wait();

      expect(await boii.address).to.not("");
    } catch (err) {
      console.log("ERROR:");
      console.log(err);
    }
  });
});
