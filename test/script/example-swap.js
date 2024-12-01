const { ethers } = require("ethers");
const DswapBuildAbi = require("./DswapBuildAbi");

class TokenSwap {
    constructor(tokenAddress, provider, wallet) {
        this.tokenAddress = tokenAddress;
        this.provider = provider;
        this.wallet = wallet;
        
        this.erc20Abi = [
            "function balanceOf(address) view returns (uint256)",
            "function approve(address spender, uint256 amount) returns (bool)",
            "function allowance(address owner, address spender) view returns (uint256)"
        ];

        // Initialize contracts with imported ABI
        this.tokenContract = new ethers.Contract(tokenAddress, [...this.erc20Abi, ...DswapBuildAbi], wallet);
    }

    // Helper function to format amounts for logging
    async _formatAmount(amount, decimals = 18) {
        return ethers.utils.formatUnits(amount, decimals);
    }

    // Get current token price in ETH
    async getTokenPrice() {
        const price = await this.tokenContract.getCurrentPrice();
        return this._formatAmount(price);
    }

    // Get token balance for an address
    async getTokenBalance(address) {
        const balance = await this.tokenContract.balanceOf(address);
        return this._formatAmount(balance);
    }

    // Buy tokens with ETH
    async buyTokens(ethAmount, slippagePercent = 5) {
        try {
            const ethAmountWei = ethers.utils.parseEther(ethAmount.toString());
            
            // Get estimated tokens with slippage protection
            const estimatedTokens = await this.tokenContract.getEstimatedTokensForETH(ethAmountWei);
            const minTokens = estimatedTokens.mul(100 - slippagePercent).div(100);

            // Execute buy transaction
            const tx = await this.tokenContract.buyTokens(minTokens, { 
                value: ethAmountWei,
                gasLimit: 300000
            });

            const receipt = await tx.wait();
            
            return {
                success: true,
                hash: receipt.transactionHash,
                ethAmount,
                estimatedTokens: await this._formatAmount(estimatedTokens)
            };
        } catch (error) {
            return {
                success: false,
                error: error.message
            };
        }
    }

    // Sell tokens for ETH
    async sellTokens(tokenAmount, slippagePercent = 5) {
        try {
            const tokenAmountWei = ethers.utils.parseEther(tokenAmount.toString());
            
            // Get estimated ETH with slippage protection
            const estimatedEth = await this.tokenContract.getEstimatedETHForTokens(tokenAmountWei);
            const minEthAmount = estimatedEth.mul(100 - slippagePercent).div(100);

            // Execute sell transaction
            const tx = await this.tokenContract.sellTokens(tokenAmountWei, minEthAmount, {
                gasLimit: 300000 // Safe gas limit
            });

            const receipt = await tx.wait();

            return {
                success: true,
                hash: receipt.transactionHash,
                tokenAmount,
                estimatedEth: await this._formatAmount(estimatedEth)
            };
        } catch (error) {
            return {
                success: false,
                error: error.message
            };
        }
    }

    // Get price impact for a trade
    async getPriceImpact(ethAmount) {
        const ethAmountWei = ethers.utils.parseEther(ethAmount.toString());
        const currentPrice = await this.tokenContract.getCurrentPrice();
        const estimatedTokens = await this.tokenContract.getEstimatedTokensForETH(ethAmountWei);
        
        const expectedPrice = ethAmountWei.mul(ethers.constants.WeiPerEther).div(estimatedTokens);
        const priceImpact = currentPrice.sub(expectedPrice).mul(100).div(currentPrice);
        
        return this._formatAmount(priceImpact);
    }
}

module.exports = TokenSwap;
