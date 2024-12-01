const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("StakeY", function () {
  let Staking, staking, token, rewardToken, owner, addr1, addr2;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    // Deploy ERC20 token for staking
    const Token = await ethers.getContractFactory("ERC20Mock");
    token = await Token.deploy("Mock Token", "MTK", ethers.utils.parseUnits("10000"));
    await token.deployed();

    // Deploy ERC20 token for rewards
    const RewardToken = await ethers.getContractFactory("ERC20Mock");
    rewardToken = await RewardToken.deploy("Reward Token", "RWT", ethers.utils.parseUnits("10000"));
    await rewardToken.deployed();

    // Deploy Staking contract with staking token and reward token
    Staking = await ethers.getContractFactory("StakeY");
    staking = await Staking.deploy(token.address, rewardToken.address);
    await staking.deployed();

    // Mint tokens for testing
    await token.connect(owner).transfer(addr1.address, ethers.utils.parseUnits("1000"));
    await token.connect(owner).transfer(addr2.address, ethers.utils.parseUnits("1000"));

    // Approve staking contract to spend tokens
    await token.connect(addr1).approve(staking.address, ethers.utils.parseUnits("1000"));
    await token.connect(addr2).approve(staking.address, ethers.utils.parseUnits("1000"));
  });

  it("Should stake tokens correctly", async function () {
    await staking.connect(addr1).stake(ethers.utils.parseUnits("10"));
    const stake = await staking.stakes(addr1.address);
    expect(await staking.totalStaked()).to.equal(ethers.utils.parseUnits("10"));
    expect(stake.amount).to.equal(ethers.utils.parseUnits("10"));
  });

  it("Should withdraw tokens correctly", async function () {
    await staking.connect(addr1).stake(ethers.utils.parseUnits("10"));
    await staking.connect(addr1).withdraw(ethers.utils.parseUnits("5"));
    const stake = await staking.stakes(addr1.address);
    expect(await staking.totalStaked()).to.equal(ethers.utils.parseUnits("5"));
    expect(stake.amount).to.equal(ethers.utils.parseUnits("5"));
  });

  it("Should accept Ether and update contract balance", async function () {
    await owner.sendTransaction({
      to: staking.address,
      value: ethers.utils.parseUnits("1", "ether"),
    });

    const contractBalance = await staking.getContractBalance();
    expect(contractBalance.toString()).to.equal(ethers.utils.parseUnits("1", "ether").toString());
  });

  it("Should handle rewards correctly", async function () {
    // Stake tokens
    await staking.connect(addr1).stake(ethers.utils.parseUnits("100"));

    // Simulate passage of time (1 hour)
    await ethers.provider.send("evm_increaseTime", [3600]); // 1 hour
    await ethers.provider.send("evm_mine");

    // Send Ether to the contract
    await owner.sendTransaction({
      to: staking.address,
      value: ethers.utils.parseUnits("1", "ether"),
    });

    await rewardToken.transfer(staking.address, ethers.utils.parseUnits("1000"));

    // Verify the contract balance before claiming rewards
    const contractBalanceBefore = await ethers.provider.getBalance(staking.address);
    console.log("Contract Balance Before Claim: ", ethers.utils.formatEther(contractBalanceBefore));

    // Calculate the expected reward
    const expectedReward = await staking.earned(addr1.address);
    console.log("Expected Reward: ", ethers.utils.formatEther(expectedReward));

    // Ensure the contract has enough balance to pay out the rewards
    expect(contractBalanceBefore).to.be.at.least(expectedReward);

    // Attempt to claim rewards
    await staking.connect(addr1).claimRewards();

    // Verify contract balance after claiming rewards
    const contractBalanceAfter = await ethers.provider.getBalance(staking.address);
    console.log("Contract Balance After Claim: ", ethers.utils.formatEther(contractBalanceAfter));
  });
});
