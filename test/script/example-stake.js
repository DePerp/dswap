const { ethers } = require("hardhat");
const StakeYAbi = require("./StakeyAbi");

// Contract addresses should be replaced with actual deployed addresses
const STAKE_Y_ADDRESS = "YOUR_STAKEY_CONTRACT_ADDRESS";
const STAKING_TOKEN_ADDRESS = "YOUR_STAKING_TOKEN_ADDRESS";
const REWARD_TOKEN_ADDRESS = "YOUR_REWARD_TOKEN_ADDRESS";

async function main() {
    // Connect to the network and get signers
    const [deployer] = await ethers.getSigners();
    
    // Initialize contract instances
    const stakeY = new ethers.Contract(STAKE_Y_ADDRESS, StakeYAbi, deployer);
    const stakingToken = await ethers.getContractAt("IERC20", STAKING_TOKEN_ADDRESS);
    const rewardToken = await ethers.getContractAt("IERC20", REWARD_TOKEN_ADDRESS);

    // Helper function to format amounts
    const formatAmount = (amount) => ethers.utils.formatEther(amount);
    
    // Example usage functions
    async function checkBalances(address) {
        const stakedAmount = await stakeY.getStakedAmount(address);
        const earnedRewards = await stakeY.earned(address);
        const earnedTokens = await stakeY.earnedInToken(address);
        
        console.log(`
            Account: ${address}
            Staked Amount: ${formatAmount(stakedAmount)} tokens
            Earned Rewards (ETH): ${formatAmount(earnedRewards)} ETH
            Earned Tokens: ${formatAmount(earnedTokens)} tokens
        `);
    }

    async function stakeTokens(amount) {
        try {
            // Approve tokens first
            const amountWei = ethers.utils.parseEther(amount.toString());
            await stakingToken.approve(STAKE_Y_ADDRESS, amountWei);
            console.log("Approved tokens for staking");

            // Perform stake
            const stakeTx = await stakeY.stake(amountWei);
            await stakeTx.wait();
            console.log(`Successfully staked ${amount} tokens`);
        } catch (error) {
            console.error("Staking failed:", error.message);
        }
    }

    async function withdrawTokens(amount) {
        try {
            const amountWei = ethers.utils.parseEther(amount.toString());
            const withdrawTx = await stakeY.withdraw(amountWei);
            await withdrawTx.wait();
            console.log(`Successfully withdrawn ${amount} tokens`);
        } catch (error) {
            console.error("Withdrawal failed:", error.message);
        }
    }

    async function claimRewards() {
        try {
            const claimTx = await stakeY.claimRewards();
            await claimTx.wait();
            console.log("Successfully claimed rewards");
        } catch (error) {
            console.error("Claiming rewards failed:", error.message);
        }
    }

    // Example usage
    try {
        // Check initial balances
        console.log("Initial balances:");
        await checkBalances(deployer.address);

        // Stake some tokens
        await stakeTokens(100);

        // Check balances after staking
        console.log("\nBalances after staking:");
        await checkBalances(deployer.address);

        // Wait some time for rewards to accumulate
        console.log("\nWaiting for rewards to accumulate...");
        // In real scenario, time passes naturally

        // Claim rewards
        await claimRewards();

        // Check final balances
        console.log("\nFinal balances after claiming rewards:");
        await checkBalances(deployer.address);

    } catch (error) {
        console.error("Script execution failed:", error.message);
    }
}

// Execute the script
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
