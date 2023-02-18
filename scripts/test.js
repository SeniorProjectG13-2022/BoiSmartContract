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
// describe("Array", function () {
//   describe("#indexOf()", function () {
//     it("should return -1 when the value is not present", function () {
//       assert.equal([1, 2, 3].indexOf(4), -1);
//     });
//   });

// describe("capy", function async() {

const unitTesting = async () => {
  const Token = new Contract(
    "0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6",
    tokenAbi,
    signer
  );

  Token.balanceOf("0x5FbE86e8Cf95bA7E8D0d229F630aE67f552664cb")
    .then(async (e) => {
      const decimal = await Token.decimals();
      const res = ethers.utils.formatUnits(e, decimal);
      console.log("app", res);

      // const re = await Token.connect(signer);
      const app = await Token.approve(
        "0x47a546d3352Fa4596C95B7CFE66fa8383c0A1ffF",
        1000000000000000
      );

      const transfer = await Token.transfer(
        "0x47a546d3352Fa4596C95B7CFE66fa8383c0A1ffF",
        1000000000000000
      );

      console.log("success", transfer);

      assert.equal(res, 0.098);
    })
    .catch((err) => {
      console.log(err);
    })
    .finally(() => console.log("bbbbb"));
};

unitTesting();
//   });
// });
