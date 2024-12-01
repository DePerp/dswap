const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DswapBuild", function () {
    let Dswap;
    let dswap;
    let owner;
    let addr1;
    let addr2;
    let stakeAddress;

    beforeEach(async function () {
        Dswap = await ethers.getContractFactory("DswapBuild");
        [owner, addr1, addr2] = await ethers.getSigners();

        // Generate a random address or use a specific one
        stakeAddress = ethers.Wallet.createRandom().address;

        // Deploy contract with all required parameters
        const name = "Dswap Token";
        const symbol = "DSWAP";
        const initialSupply = ethers.utils.parseEther("1000000");
        const devSupplyPercent = 10; // 10%
        const basisValue = ethers.utils.parseEther("100"); // Initial ETH reserve
        const tokenIconIPFS = "QmYourIPFSHash"; // Replace with actual IPFS hash

        dswap = await Dswap.deploy(
            stakeAddress,
            name,
            symbol,
            initialSupply,
            devSupplyPercent,
            basisValue,
            tokenIconIPFS
        );
        await dswap.deployed();
    });

    it("Should deploy with the correct initial supply", async function () {
        const totalSupply = await dswap.totalSupply();
        const ownerBalance = await dswap.balanceOf(owner.address);
        const contractBalance = await dswap.balanceOf(dswap.address);

        console.log("Initial Deployment Details:");
        console.log("Total Supply:", ethers.utils.formatEther(totalSupply));
        console.log("Owner Balance:", ethers.utils.formatEther(ownerBalance));
        console.log("Contract Balance:", ethers.utils.formatEther(contractBalance));

        expect(totalSupply).to.equal(ethers.utils.parseEther("1000000"));
        expect(ownerBalance).to.be.above(0);
        expect(contractBalance).to.equal(ethers.utils.parseEther("900000")); // Initial tokens in the contract
    });

    it("Should allow buying tokens with ETH and deduct the correct fee", async function () {
        const buyAmount = ethers.utils.parseEther("1"); // 1 ETH
        const feePercent = ethers.BigNumber.from("30"); // 0.3%
        const feeScale = ethers.BigNumber.from("10000"); // Scale for fee calculation
    
        // Calculate fee and net amount
        const feeAmount = buyAmount.mul(feePercent).div(feeScale);
        const netAmount = buyAmount.sub(feeAmount);
    
        // Calculate minTokenAmount
        const minTokenAmount = await dswap.getEstimatedTokensForETH(netAmount);
    
        // Initial balances
        const initialTokenBalance = await dswap.balanceOf(owner.address);
        const initialEthBalance = await ethers.provider.getBalance(owner.address);
        const initialStakeBalance = await ethers.provider.getBalance(stakeAddress);
    
        // Buy tokens
        await dswap.connect(owner).buyTokens(minTokenAmount, { value: buyAmount });

        // Log the current price after purchase
        const currentTokenPriceAfterPurchase = await dswap.getCurrentPrice();
        console.log("Token Price after Purchase:", ethers.utils.formatEther(currentTokenPriceAfterPurchase));
    
        // Final balances
        const newTokenBalance = await dswap.balanceOf(owner.address);
        const newEthBalance = await ethers.provider.getBalance(owner.address);
        const newStakeBalance = await ethers.provider.getBalance(stakeAddress);
    
        // Calculate differences
        const tokenBalanceDifference = newTokenBalance.sub(initialTokenBalance);
        const ethSpentOnBuy = initialEthBalance.sub(newEthBalance); // ETH spent (including fee)
        const feeAccumulated = await dswap.getAccumulatedFeesInETH(); // Check accumulated fees
    
        console.log("Initial ETH Balance:", ethers.utils.formatEther(initialEthBalance));
        console.log("New ETH Balance:", ethers.utils.formatEther(newEthBalance));
        console.log("Fee Amount:", ethers.utils.formatEther(feeAmount));
        console.log("ETH Spent (should be buyAmount):", ethers.utils.formatEther(ethSpentOnBuy));
        console.log("Accumulated Fee in ETH (should match feeAmount):", ethers.utils.formatEther(feeAccumulated));
        console.log("New Token Balance:", ethers.utils.formatEther(newTokenBalance));
        console.log("Token Balance Difference (should be around minTokenAmount):", ethers.utils.formatEther(tokenBalanceDifference));
    
        // Assertions
        expect(tokenBalanceDifference).to.be.within(
            minTokenAmount.mul(95).div(100), // 5% slippage tolerance
            minTokenAmount.mul(105).div(100)
        ); // Check token amount received
        expect(ethSpentOnBuy).to.be.closeTo(buyAmount, ethers.utils.parseEther("0.0001")); // Check total ETH spent
        expect(feeAccumulated).to.be.closeTo(feeAmount, ethers.utils.parseEther("0.0001")); // Check fee accumulation
    });

    it("Should allow selling tokens for ETH and accumulate the correct fee in tokens", async function () {
        const buyAmount = ethers.utils.parseEther("1"); // 1 ETH
        const feePercent = ethers.BigNumber.from("30"); // 0.3% fee
        const feeScale = ethers.BigNumber.from("10000"); // Scale for fee calculation
    
        // Calculate fee on ETH and tokens
        const feeAmountETH = buyAmount.mul(feePercent).div(feeScale);
        const netAmountETH = buyAmount.sub(feeAmountETH);
    
        // Get estimated tokens for the given ETH
        const minTokenAmount = await dswap.getEstimatedTokensForETH(netAmountETH);
    
        // Buy tokens first
        await dswap.connect(owner).buyTokens(minTokenAmount, { value: buyAmount });
    
        // Calculate the amount of tokens to sell
        const tokenAmountToSell = minTokenAmount.div(2); // Selling half of the bought tokens
        const minEthAmount = await dswap.getEstimatedETHForTokens(tokenAmountToSell);
    
        // Initial balances before selling
        const initialTokenBalance = await dswap.balanceOf(owner.address);
        const initialEthBalance = await ethers.provider.getBalance(owner.address);
        const initialStakeBalance = await ethers.provider.getBalance(stakeAddress);
    
        // Initial accumulated fee in tokens
        const initialAccumulatedFeesInToken = await dswap.accumulatedFeesInToken();
    
        // Sell tokens
        await dswap.connect(owner).sellTokens(tokenAmountToSell, minEthAmount);

        // Log the current price after sale
        const currentTokenPriceAfterSale = await dswap.getCurrentPrice();
        console.log("Token Price after Sale:", ethers.utils.formatEther(currentTokenPriceAfterSale));
    
        // Final balances after selling
        const newTokenBalance = await dswap.balanceOf(owner.address);
        const newEthBalance = await ethers.provider.getBalance(owner.address);
        const newStakeBalance = await ethers.provider.getBalance(stakeAddress);
    
        // Final accumulated fee in tokens
        const newAccumulatedFeesInToken = await dswap.accumulatedFeesInToken();
    
        // Calculate expected fee in tokens
        const expectedFeeInTokens = tokenAmountToSell.mul(feePercent).div(feeScale);
    
        // Convert all balances to BigNumber for comparison
        const tokenBalanceDifference = initialTokenBalance.sub(newTokenBalance);
        const ethBalanceDifference = newEthBalance.sub(initialEthBalance);
    
        console.log("Selling Tokens:");
        console.log("Initial Token Balance:", ethers.utils.formatEther(initialTokenBalance));
        console.log("Initial ETH Balance:", ethers.utils.formatEther(initialEthBalance));
        console.log("Initial Stake Balance:", ethers.utils.formatEther(initialStakeBalance));
    
        console.log("Post Sale Details:");
        console.log("New Token Balance:", ethers.utils.formatEther(newTokenBalance));
        console.log("New ETH Balance:", ethers.utils.formatEther(newEthBalance));
        console.log("New Stake Balance:", ethers.utils.formatEther(newStakeBalance));
        console.log("Initial Accumulated Fee in Tokens:", ethers.utils.formatEther(initialAccumulatedFeesInToken));
        console.log("New Accumulated Fee in Tokens:", ethers.utils.formatEther(newAccumulatedFeesInToken));
    
        // Assertions
        expect(tokenBalanceDifference).to.equal(tokenAmountToSell); // Tokens should decrease
        expect(ethBalanceDifference).to.be.within(
            minEthAmount.sub(ethers.utils.parseEther("0.0001")), // Small buffer
            minEthAmount.add(ethers.utils.parseEther("0.0001"))  // Small buffer
        ); // Check ETH amount received
        expect(newAccumulatedFeesInToken.sub(initialAccumulatedFeesInToken)).to.equal(expectedFeeInTokens); // Verify fee in tokens
    });

    it("Should allow claiming fees after cooldown period", async function () {
        const buyAmount = ethers.utils.parseEther("1"); // 1 ETH
        const feePercent = ethers.BigNumber.from("30"); // 0.3%
        const feeScale = ethers.BigNumber.from("10000"); // Scale for fee calculation
    
        // Calculate fee on ETH
        const feeAmountETH = buyAmount.mul(feePercent).div(feeScale);
    
        // Buy tokens first
        await dswap.connect(owner).buyTokens(0, { value: buyAmount });

        // Log the current price after purchase
        const currentTokenPriceAfterPurchase = await dswap.getCurrentPrice();
        console.log("Token Price after Purchase:", ethers.utils.formatEther(currentTokenPriceAfterPurchase));
    
        // Advance time by cooldown period
        await ethers.provider.send("evm_increaseTime", [86400]); // 1 day
        await ethers.provider.send("evm_mine"); // Mine a block to update the time

        // Claim fees
        await expect(dswap.connect(owner).claimFees()).to.emit(dswap, "FeesWithdrawn").withArgs(stakeAddress, ethers.utils.parseEther("0"), feeAmountETH);
    });

    it("Should enforce claim cooldown", async function () {
        // Assume an initial cooldown period of 1 day
        const cooldownPeriod = await dswap.claimCooldown();
        
        // Claim fees for the first time
        await dswap.connect(owner).claimFees();
    
        // Attempt to claim fees again before cooldown period has passed
        await expect(dswap.connect(owner).claimFees()).to.be.revertedWith('Cooldown period has not passed');
    
        // Advance time to just after the cooldown period
        await network.provider.send("evm_increaseTime", [cooldownPeriod.toNumber() + 1]);
        await network.provider.send("evm_mine"); // Mine a new block to apply the increased time
    
        // Claim fees again after cooldown period
        await dswap.connect(owner).claimFees();
    });
    

    it("Should accumulate fees correctly", async function () {
        const buyAmount = ethers.utils.parseEther("1"); // 1 ETH
        const feePercent = ethers.BigNumber.from("30"); // 0.3%
        const feeScale = ethers.BigNumber.from("10000"); // Scale for fee calculation
    
        // Calculate fee on ETH
        const feeAmountETH = buyAmount.mul(feePercent).div(feeScale);
    
        // Buy tokens first
        await dswap.connect(owner).buyTokens(0, { value: buyAmount });

        // Log the current price after purchase
        const currentTokenPriceAfterPurchase = await dswap.getCurrentPrice();
        console.log("Token Price after Purchase:", ethers.utils.formatEther(currentTokenPriceAfterPurchase));
    
        // Check accumulated fees
        const accumulatedFeesInETH = await dswap.getAccumulatedFeesInETH();
        expect(accumulatedFeesInETH).to.equal(feeAmountETH);
    
        // Claim fees
        await ethers.provider.send("evm_increaseTime", [86400]); // Advance time by 1 day
        await ethers.provider.send("evm_mine"); // Mine a block to update the time
        await dswap.connect(owner).claimFees();
    
        // Check fees after claiming
        const accumulatedFeesInETHAfterClaim = await dswap.getAccumulatedFeesInETH();
        expect(accumulatedFeesInETHAfterClaim).to.equal(0);
    });
});


