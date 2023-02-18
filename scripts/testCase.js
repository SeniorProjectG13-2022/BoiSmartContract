var assert = require("assert");
const { Contract } = require("ethers");
const { waffle } = require("hardhat");
const provider = waffle.provider;
signer = provider.getSigner();

const tokenAbi = [
  {
    constant: true,
    inputs: [],
    name: "name",
    outputs: [
      {
        name: "",
        type: "string",
      },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      {
        name: "guy",
        type: "address",
      },
      {
        name: "wad",
        type: "uint256",
      },
    ],
    name: "approve",
    outputs: [
      {
        name: "",
        type: "bool",
      },
    ],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "totalSupply",
    outputs: [
      {
        name: "",
        type: "uint256",
      },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      {
        name: "src",
        type: "address",
      },
      {
        name: "dst",
        type: "address",
      },
      {
        name: "wad",
        type: "uint256",
      },
    ],
    name: "transferFrom",
    outputs: [
      {
        name: "",
        type: "bool",
      },
    ],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      {
        name: "wad",
        type: "uint256",
      },
    ],
    name: "withdraw",
    outputs: [],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "decimals",
    outputs: [
      {
        name: "",
        type: "uint8",
      },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [
      {
        name: "",
        type: "address",
      },
    ],
    name: "balanceOf",
    outputs: [
      {
        name: "",
        type: "uint256",
      },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: true,
    inputs: [],
    name: "symbol",
    outputs: [
      {
        name: "",
        type: "string",
      },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    constant: false,
    inputs: [
      {
        name: "dst",
        type: "address",
      },
      {
        name: "wad",
        type: "uint256",
      },
    ],
    name: "transfer",
    outputs: [
      {
        name: "",
        type: "bool",
      },
    ],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    constant: false,
    inputs: [],
    name: "deposit",
    outputs: [],
    payable: true,
    stateMutability: "payable",
    type: "function",
  },
  {
    constant: true,
    inputs: [
      {
        name: "",
        type: "address",
      },
      {
        name: "",
        type: "address",
      },
    ],
    name: "allowance",
    outputs: [
      {
        name: "",
        type: "uint256",
      },
    ],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
  {
    payable: true,
    stateMutability: "payable",
    type: "fallback",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        name: "src",
        type: "address",
      },
      {
        indexed: true,
        name: "guy",
        type: "address",
      },
      {
        indexed: false,
        name: "wad",
        type: "uint256",
      },
    ],
    name: "Approval",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        name: "src",
        type: "address",
      },
      {
        indexed: true,
        name: "dst",
        type: "address",
      },
      {
        indexed: false,
        name: "wad",
        type: "uint256",
      },
    ],
    name: "Transfer",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        name: "dst",
        type: "address",
      },
      {
        indexed: false,
        name: "wad",
        type: "uint256",
      },
    ],
    name: "Deposit",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        name: "src",
        type: "address",
      },
      {
        indexed: false,
        name: "wad",
        type: "uint256",
      },
    ],
    name: "Withdrawal",
    type: "event",
  },
];

// ----- config parameter -------
const tokenAddress = "0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6";
const contractAddress = "";

const guyAddress = "0x5FbE86e8Cf95bA7E8D0d229F630aE67f552664cb";
const reawAddress = "0x47a546d3352Fa4596C95B7CFE66fa8383c0A1ffF";

// ----- constructor parameter -----
const params = {
  summoner: "0x47a546d3352Fa4596C95B7CFE66fa8383c0A1ffF",
  depositToken: tokenAddress, //Ethereum token address in GOERLI
  periodDuration: 60,
  votingPeriodLength: 3,
  gracePeriodLength: 3,
  proposalDeposit: 10,
  dilutionBound: 2,
};

// ----- start function -----
const test = async () => {
  // token
  const Token = new Contract(
    "0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6",
    tokenAbi,
    signer
  );

  //   contract
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
  console.log("boii");

  await boii.deployed();
  console.log("Greeter deployed to:", boii.address);
  console.log(await boii.proposalCount());

  // ------------ submitJoinProposal --------------
  submitJoinProposalNormal(Token, boii);
};

// 0.1 ---------------------------------
const submitJoinProposalNormal = async (Token, boii) => {
  const app = await Token.approve(boii.address, 1000000000000000);

  await app.wait();

  const submitJoinTx = await boii.submitJoinProposal(
    "0x5FbE86e8Cf95bA7E8D0d229F630aE67f552664cb", //applicant
    10, //sharesRequest
    1000000000000000, //tributeOffered (weii)
    "capybaraDetails" //details (IPFSHash)
  );

  await submitJoinTx.wait();

  assert.ok(await boii.proposals(0));
};
// 0.2
const submitJoinProposalNoMember = async (Token, boii) => {
  const app = await Token.approve(boii.address, 1000000000000000);

  await app.wait();

  const submitJoinTx = await boii.submitJoinProposal(
    "0x5FbE86e8Cf95bA7E8D0d229F630aE67f552664cb", //applicant
    10, //sharesRequest
    1000000000000000, //tributeOffered (weii)
    "capybaraDetails" //details (IPFSHash)
  );

  await submitJoinTx.wait();

  assert.ok(await boii.proposals(0));
};

// 1.1 ---------------------------------
const submitProjectProposalNormal = async (Token, boii) => {
  const app = await Token.approve(boii.address, 1000000000000000);

  await app.wait();

  const submitProjectTx = await boii.submitProjectProposal(
    "0x5FbE86e8Cf95bA7E8D0d229F630aE67f552664cb", //applicant
    1000000000000000, //tributeOffered (weii)
    [1000000000000000, 1000000000000000], //paymentRequested (weii)
    "capybaraDetails" //details (IPFSHash)
  );

  await submitProjectTx.wait();

  assert.ok(await boii.proposals(1));
};

// 1.2
const submitProjectProposalNoApplicant = async (Token, boii) => {
  const app = await Token.approve(boii.address, 1000000000000000);

  await app.wait();

  const submitProjectTx = await boii.submitProjectProposal(
    0, //applicant
    1000000000000000, //tributeOffered (weii)
    [1000000000000000, 1000000000000000], //paymentRequested (weii)
    "capybaraDetails" //details (IPFSHash)
  );

  await submitProjectTx.wait();

  assert.ok(await boii.proposals(2));
};

// 1.3
const submitProjectProposalReserve = async (Token, boii) => {
  const app = await Token.approve(boii.address, 1000000000000000);

  await app.wait();

  const submitProjectTx = await boii.submitProjectProposal(
    "0xdead", //applicant
    1000000000000000, //tributeOffered (weii)
    [1000000000000000, 1000000000000000], //paymentRequested (weii)
    "capybaraDetails" //details (IPFSHash)
  );

  await submitProjectTx.wait();

  assert.ok(await boii.proposals(2));
};

// 2.1 ---------------------------------
const submitGuildKickProposalNormal = async (Token, boii) => {
  const app = await Token.approve(boii.address, 1000000000000000);

  await app.wait();

  const submitGuildKickProposalTx = await boii.submitGuildKickProposal(
    params.summoner, //memberToKick
    "capybaraDetails" //details (IPFSHash)
  );

  await submitGuildKickProposalTx.wait();

  assert.ok(await boii.proposals(0));
};

// 2.2
const submitGuildKickProposalNoShare = async (Token, boii) => {
  const app = await Token.approve(boii.address, 1000000000000000);

  await app.wait();

  const submitGuildKickProposalTx = await boii.submitGuildKickProposal(
    guyAddress, //memberToKick
    "capybaraDetails" //details (IPFSHash)
  );

  await submitGuildKickProposalTx.wait();

  assert.ok(await boii.proposals(0));
};

// 3.1 ---------------------------------
const sponsorProposalNormal = async (Token, boii) => {
  const app = await Token.approve(boii.address, 1000000000000000);

  await app.wait();

  const sponsorProposalTx = await boii.sponsorProposal(
    0 //proposalIs
  );

  await sponsorProposalTx.wait();

  assert.ok(await boii.proposals(1));
};

// 3.2
const sponsorProposalNonMember = async (Token, boii) => {
  const app = await Token.approve(boii.address, 1000000000000000);

  await app.wait();

  const sponsorProposalTx = await boii.sponsorProposal(
    0 //proposalIs
  );

  await sponsorProposalTx.wait();

  assert.ok(await boii.proposals(1));
};

// 3.3
const sponsorProposalInvalidId = async (Token, boii) => {
  const app = await Token.approve(boii.address, 1000000000000000);

  await app.wait();

  const sponsorProposalTx = await boii.sponsorProposal(
    99999 //proposalIs
  );

  await sponsorProposalTx.wait();

  assert.ok(await boii.proposals(1));
};

// 4.1 ---------------------------------
const submitVoteNormal = async (Token, boii) => {
  const submitVoteTx = await boii.submitVote(
    0, //proposalIs
    1
  );

  await submitVoteTx.wait();

  assert.ok(await boii.proposals(0));
};

// 4.2
const submitVoteNonMember = async (Token, boii) => {
  const submitVoteTx = await boii.submitVote(
    0, //proposalIs
    1
  );

  await submitVoteTx.wait();

  assert.ok(await boii.proposals(0));
};

// 4.3
const submitVoteInvalidId = async (Token, boii) => {
  const submitVoteTx = await boii.submitVote(
    999999, //proposalIs
    1
  );

  await submitVoteTx.wait();

  assert.ok(await boii.proposals(0));
};

// 4.4
const submitVoteInvalidVote = async (Token, boii) => {
  const submitVoteTx = await boii.submitVote(
    0, //proposalIs
    4
  );

  await submitVoteTx.wait();

  assert.ok(await boii.proposals(0));
};

// 5.1 ---------------------------------
const preProcessProposalNormal = async (Token, boii) => {
  const preProcessProposalTx = await boii.preProcessProposal(
    0 //proposalIs
  );

  await preProcessProposalTx.wait();

  assert.ok(await boii.proposals(0));
};

// 6.1 ---------------------------------
const processProposalNormal = async (Token, boii) => {
  const processProposalTx = await boii.processProposal(
    0 //proposalIs
  );

  await processProposalTx.wait();

  assert.ok(await boii.proposals(0));
};

// 7.1 ---------------------------------
const ragequitNormal = async (Token, boii) => {
  const processProposalTx = await boii.ragequit(
    1, //shareToBurn
    0 //proposalId
  );

  await processProposalTx.wait();

  assert.ok(await boii.proposals(0));
};

// 8.1 ---------------------------------
const cancelProposalNormal = async (Token, boii) => {
  const processProposalTx = await boii.cancelProposal(
    0 //proposalId
  );

  await processProposalTx.wait();

  assert.ok(await boii.proposals(0));
};

// 9.1 ---------------------------------
const withdrawBalanceNormal = async (Token, boii) => {
  const app = await Token.approve(boii.address, 1000000000000000);

  await app.wait();

  const submitJoinTx = await boii.submitJoinProposal(
    "0x5FbE86e8Cf95bA7E8D0d229F630aE67f552664cb", //applicant
    10, //sharesRequest
    1000000000000000, //tributeOffered (weii)
    "capybaraDetails" //details (IPFSHash)
  );

  await submitJoinTx.wait();

  assert.ok(await boii.proposals(0));
};
// ----- run function -----
test();
