import { expect, assert } from "chai";
import hre from "hardhat";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { mine, time } from "@nomicfoundation/hardhat-network-helpers";
import { DeckOfCards } from "../typechain-types";

describe("DeckOfCards", function () {
  let deployerAccount: SignerWithAddress;
  let deckOfCards: DeckOfCards;

  beforeEach(async function () {
    deckOfCards = await hre.ethers.deployContract(
      "DeckOfCards",
      [],
      deployerAccount,
    );
    await deckOfCards.waitForDeployment();
  });

  // it should get a random number
  it("should get a random number", async function () {
    const randomNumber = await deckOfCards.requestRandomWords();
    console.log({ randomNumber });
    assert.isNumber(randomNumber);
  });
});
