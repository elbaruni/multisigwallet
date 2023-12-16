// test/multiSigWallet.test.js
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MultiSigWallet", function () {
  let MultiSigWallet;
  let multiSigWallet;
  let owner;
  let director1;
  let director2;
  let nonDirector;
  let receiver;

  beforeEach(async function () {
    [owner, director1, director2, nonDirector, receiver] =
      await ethers.getSigners();

    MultiSigWallet = await ethers.getContractFactory("MultiSigWallet");

    multiSigWallet = await MultiSigWallet.deploy(
      [director1.address, director2.address],

      "Test MultiSigWallet",
      "100000000000000000000",
      receiver.address
    );

    await multiSigWallet.deployed();
  });

  it("should create a proposal and execute it", async function () {
    // Make a proposal
    await multiSigWallet
      .connect(director1)
      .makeProposal(receiver.address, "New Proposal", "15000000000000000000"); // Example USD value

    const proposalId = await multiSigWallet.nextProposalId();

    const proposalBefore = await multiSigWallet.proposals(proposalId);

    expect(proposalBefore.status).to.equal(0); // Pending

    // Execute the proposal (by the other director)
    await multiSigWallet.connect(director2).executeAction(0, true);

    const proposalAfter = await multiSigWallet.proposals(0);

    expect(proposalAfter.status).to.equal(1); // Accepted
    expect(proposalAfter.executor).to.equal(director2.address);

    // Check if the state variables are updated
    expect(await multiSigWallet.name()).to.equal("New Proposal");
    expect(await multiSigWallet.receiverWallet()).to.equal(receiver.address);
    expect(await multiSigWallet.usdValue()).to.equal("15000000000000000000"); // Example USD value
  });

  it("should not allow non-director to make a proposal", async function () {
    await expect(
      multiSigWallet
        .connect(nonDirector)
        .makeProposal(receiver.address, "Invalid Proposal", 5000)
    ).to.be.revertedWith("Not authorized");
  });

  it("should not allow the creator to execute the proposal", async function () {
    // Make a proposal
    const proposalId = await multiSigWallet.nextProposalId();
    await multiSigWallet
      .connect(director1)
      .makeProposal(receiver.address, "New Proposal", 10000); // Example USD value

    // Attempt to execute the proposal (by the creator)
    await expect(
      multiSigWallet.connect(director1).executeAction(proposalId, true)
    ).to.be.revertedWith("proposal creator can not execute the action");
  });

  it("should allow non-director to execute the proposal", async function () {
    // Make a proposal
    const proposalId = await multiSigWallet.nextProposalId();
    await multiSigWallet
      .connect(director1)
      .makeProposal(receiver.address, "New Proposal", 10000); // Example USD value

    // Execute the proposal (by the non director)
    await expect(
      multiSigWallet.connect(nonDirector).executeAction(proposalId, true)
    ).to.be.revertedWith("Not authorized");
  });

  it("should transfer funds", async function () {
    const initialBalanceReceiverBefore = await receiver.getBalance();

    const amount = ethers.utils.parseEther("1");
    await director1.sendTransaction({
      to: multiSigWallet.address,
      value: amount,
    });

    // Transfer funds
    await multiSigWallet.connect(director1).transferFunds();

    const initialBalanceReceiverAfter = await receiver.getBalance();

    // Ensure that the receiver's balance increased by the transferred amount
    expect(initialBalanceReceiverAfter).to.equal(
      initialBalanceReceiverBefore.add(amount)
    );
  });

  it("should check ETH balance vs USD", async function () {
    const amount = ethers.utils.parseEther("1");
    await director1.sendTransaction({
      to: multiSigWallet.address,
      value: amount,
    });

    // Check if the initial ETH balance is greater than or equal to the specified USD value
    const initialCheck = await multiSigWallet.checkEthBalanceVsUSD();

    expect(initialCheck).to.equal(true);

    await multiSigWallet.connect(director1).transferFunds();

    // Check again after the transfer
    const finalCheck = await multiSigWallet.checkEthBalanceVsUSD();
    expect(finalCheck).to.equal(false);
  });
});
