# DSwap Token Standard Documentation

## Overview
TOKEN-DSwap is an advanced ERC20 token implementation that combines automated market maker (AMM) functionality with staking capabilities. It features a built-in  swap, liquidity pool, fee mechanism, and rewards distribution system.

## Core Components

### 1. DswapBuild Contract
The main token contract implementing ERC20 functionality with the following features:
- Built-in AMM (Automated Market Maker)
- 0.3% fee on all trades
- ETH/Token built-in liquidity pool
- Token burning mechanism
- Fee accumulation and distribution

### 2. StakeY Contract
Staking contract that enables:
- Token staking
- Dual rewards in ETH and tokens
- Time-based reward distribution
- 1-hour cooldown between reward claims

### 3. DeploymentFactory Contract
Factory contract for deploying new token instances with:
- Automated setup of token and staking contracts
- Configurable initial parameters
- Fee collection mechanism
- Ownership management

## Key Features

### Automated Market Making
- Constant product formula (x * y = k)
- Dynamic pricing based on reserve ratios
- Slippage protection
- Minimum trade amounts

### Fee Structure
- 0.3% fee on all trades (30 basis points)
- Fees split between:
  - Token staking rewards
  - ETH staking rewards
  - Protocol maintenance

### Liquidity Management
- Initial liquidity provided at deployment
- Basis value mechanism for price stability
- Reserve tracking for both ETH and tokens
- Anti-manipulation safeguards

### Staking Mechanism
- Flexible staking periods
- Dual reward system (ETH + Tokens)
- Pro-rata reward distribution
- Anti-gaming measures

## Technical Specifications

### Token Parameters
- ERC20 compliant
- Burnable token functionality
- Configurable initial supply
- Developer allocation percentage
- Custom token icon support (IPFS)

### AMM Parameters
- Constant product formula
- Price impact calculations
- Reserve ratio maintenance
- Minimum liquidity requirements

### Anti-Manipulation
- Reserve ratio monitoring
- Minimum liquidity requirements
- Slippage protection
- Reentrancy guards

### Price Stability
- Basis value mechanism
- Dynamic pricing algorithm
- Reserve balance checks
- Fee accumulation system

## Best Practices

### Trading
- Include slippage protection
- Monitor gas costs
- Check price impact
- Verify reserves

### Staking
- Monitor reward rates
- Track cooldown periods
- Verify reward calculations
- Check stake amounts

## Integration Guide

### Contract Deployment
1. Deploy using DeploymentFactory
2. Configure initial parameters:
   - Token name and symbol
   - Initial supply
   - Developer allocation
   - Basis value (minimal reserve ratio)
   - Token icon IPFS hash

### Mainnet Deployments

| Contract | Network | Address | Explorer | Status |
|----------|---------|----------|-----------|--------|
| DeploymentFactory | Base | `0x719CaAe0704eb116F623b3BfD7c60aCf7C49a68c` | [View on Basescan](https://basescan.org/address/0x719CaAe0704eb116F623b3BfD7c60aCf7C49a68c) | ✅ Verified |

## Trading Integration

### Buy tokens
```
await dswapContract.buyTokens(minTokenAmount, {value: ethAmount});
```
### Sell tokens
```
await dswapContract.sellTokens(tokenAmount, minEthAmount);
```
### Staking Integration
#### Stake tokens
```
await stakeYContract.stake(amount);
```
#### Claim rewards
```
await stakeYContract.claimRewards();
```
#### Withdraw stake
```
await stakeYContract.withdraw(amount);
```

## Contract ABIs and Examples

### Repository Links
- [DswapBuild ABI Example](https://github.com/yourusername/dswap/blob/main/test/script/DswapBuildAbi.js)
- [StakeY ABI Example](https://github.com/yourusername/dswap/blob/main/test/script/StakeyAbi.js)

### Integration Examples

#### DswapBuild Contract Integration
```javascript
const DswapBuildAbi = require('./DswapBuildAbi.js');

// Initialize contract
const dswapContract = new ethers.Contract(
    DSWAP_ADDRESS,
    DswapBuildAbi,
    signer
);

// Example usage
const price = await dswapContract.getCurrentPrice();
const reserves = await dswapContract.getReserves();
```

#### StakeY Contract Integration
```javascript
const StakeYAbi = require('./StakeyAbi.js');

// Initialize contract
const stakeContract = new ethers.Contract(
    STAKE_ADDRESS,
    StakeYAbi,
    signer
);

// Example usage
const stakedAmount = await stakeContract.getStakedAmount(userAddress);
const earnedRewards = await stakeContract.earned(userAddress);
```

### Full Contract Methods

#### DswapBuild Methods
```javascript
// View Functions
getCurrentPrice()
getReserves()
getTokenReserve()
getEthReserve()
getAccumulatedFeesInToken()
getAccumulatedFeesInETH()
getEstimatedTokensForETH(ethAmount)
getEstimatedETHForTokens(tokenAmount)

// State-Changing Functions
buyTokens(minTokenAmount)
sellTokens(tokenAmount, minEthAmount)
claimFees()
```

#### StakeY Methods
```javascript
// View Functions
earned(address)
earnedInToken(address)
getContractBalance()
getRewardTokenReserve()
getStakedAmount(address)
rewardPerToken()
rewardTokenPerToken()

// State-Changing Functions
stake(amount)
withdraw(amount)
claimRewards()
updateRewardToken(address)
updateRewardTokenReserve(amount)
updateStakingToken(address)
```

### Events to Monitor

#### DswapBuild Events
```javascript
TokensPurchased(address indexed buyer, uint256 ethAmount, uint256 tokenAmount)
TokensSold(address indexed seller, uint256 tokenAmount, uint256 ethAmount)
ReservesUpdated(uint256 newEthReserve, uint256 newTokenReserve)
FeesWithdrawn(address indexed recipient, uint256 tokenAmount, uint256 ethAmount)
FeeAccumulated(uint256 tokenFeeAmount, uint256 ethFeeAmount)
```

#### StakeY Events
```javascript
FundsReceived(address indexed sender, uint256 amount)
RewardCalculated(address indexed user, uint256 reward)
RewardPaid(address indexed user, uint256 reward)
RewardsClaimed(address indexed user, uint256 reward)
StakingTokenChanged(address indexed newToken)
RewardTokenChanged(address indexed newToken)
Staked(address indexed user, uint256 amount)
Withdrawn(address indexed user, uint256 amount)
```

### Example Implementation Files
- [Example Swap Implementation](https://github.com/yourusername/dswap/blob/main/test/script/example-swap.js)
- [Example Stake Implementation](https://github.com/yourusername/dswap/blob/main/test/script/example-stake.js)

# ⚠️ IMPORTANT DISCLAIMER

## Risk Warning
**USE AT YOUR OWN RISK. PLEASE READ THIS DISCLAIMER CAREFULLY.**

### Experimental Technology
DSwap protocol is experimental technology. By using this protocol, you acknowledge and agree that:

- You are using the software at your own risk
- You have sufficient knowledge and experience to evaluate the risks and merits of using this protocol
- You understand and accept all risks associated with using experimental blockchain technology

### Financial Risk
- You may lose ALL of your funds
- Past performance is not indicative of future results
- The protocol has not been audited by any third-party security firms
- Smart contracts may contain bugs or vulnerabilities
- Market volatility can lead to significant losses
- Liquidity risks may prevent you from exiting positions

### Technical Risks
- Smart contract failures could result in loss of funds
- Network congestion may prevent transactions
- Oracle failures could affect price calculations
- Frontend interfaces may experience technical issues
- Blockchain reorganizations could affect transactions

### Legal Notice
- This protocol is provided "AS IS" without warranty of any kind
- The developers assume no responsibility for losses
- This is not financial advice
- Users must comply with their local regulations
- Protocol may be unavailable in certain jurisdictions

### Security Recommendations
1. Start with small amounts to test functionality
2. Never invest more than you can afford to lose
3. Verify all transaction details before confirming
4. Keep your private keys secure
5. Be cautious of phishing attempts
6. Double-check contract addresses

### Known Limitations
- Gas costs may be high during network congestion
- Price impact on large trades
- Slippage during volatile market conditions
- Reward calculation delays
- Cooldown periods for certain operations

### No Guarantees
The protocol developers make:
- No guarantee of profits
- No guarantee of availability
- No guarantee of accuracy
- No guarantee of performance
- No guarantee against bugs or exploits

By using this protocol, you explicitly acknowledge having read this disclaimer and agree to all terms and conditions.

---

[Rest of documentation follows...]

## License
BUSL-1.1 (Business Source License 1.1)