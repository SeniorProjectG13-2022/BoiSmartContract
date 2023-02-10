// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

//   temp constructor parameter
const params = {
    summoner: "0x47a546d3352Fa4596C95B7CFE66fa8383c0A1ffF",
    depositToken: "0x7af963cf6d228e564e2a0aa0ddbf06210b38615d",//Ethereum token address in GOERLI
    periodDuration: 60,
    votingPeriodLength: 3,
    gracePeriodLength: 3,
    proposalDeposit: 10,
    dilutionBound: 2,
}

console.log("START");
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
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.log("CATCH ERROR: ")
  console.error(error);
  process.exitCode = 1;
});