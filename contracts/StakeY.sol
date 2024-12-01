// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

/**
 * @title StakingY
 * @notice A smart contract for staking and reward distribution.
 * The contract allows users to stake ERC20 tokens and earn rewards in the form of ETH and ERC20 tokens.
 */
contract StakeY is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public stakingToken; // The ERC20 token used for staking
    IERC20 public rewardToken; // The ERC20 token used for rewards

    uint256 public totalStaked; // Total amount of tokens staked
    uint256 public lastUpdateTime; // Last time rewards were updated
    uint256 public rewardPerTokenStored; // Stored reward per token
    uint256 public rewardTokenPerTokenStored; // Stored reward token per token

    uint256 public rewardTokenReserve; // Reserve of reward tokens
    uint256 public ethReserve; // Reserve of ETH for rewards

    struct Stake {
        uint256 amount; // Amount of tokens staked by the user
        uint256 rewardPerTokenPaid; // Reward per token paid to the user
        uint256 rewards; // Total rewards earned by the user
    }

    mapping(address => Stake) public stakes; // Mapping of user addresses to their stakes
    mapping(address => uint256) public userRewardTokenPerTokenPaid; // Reward token per token paid to each user
    mapping(address => uint256) public userRewardTokenRewards; // Reward token rewards earned by each user
    mapping(address => uint256) public lastRewardClaim; // Cooldown 1 hour

    event Staked(address indexed user, uint256 amount); // Event emitted when tokens are staked
    event Withdrawn(address indexed user, uint256 amount); // Event emitted when tokens are withdrawn
    event RewardPaid(address indexed user, uint256 reward); // Event emitted when rewards are paid
    event FundsReceived(address indexed sender, uint256 amount); // Event emitted when ETH is received
    event RewardsClaimed(address indexed user, uint256 reward); // Event emitted when rewards are claimed
    event RewardCalculated(address indexed user, uint256 rewardCalculated); // Event emitted when rewards are calculated
    event StakingTokenChanged(address indexed newToken); // Event emitted when the staking token is changed
    event RewardTokenChanged(address indexed newToken); // Event emitted when the reward token is changed
    event RewardTokenReserveUpdated(uint256 newReserve); // Event emitted when the reward token reserve is updated
    event EthReserveUpdated(uint256 newReserve); // Event emitted when the ETH reserve is updated

    /**
     * @notice Constructor to initialize the contract with staking and reward tokens.
     * @param _stakingToken The ERC20 token used for staking.
     * @param _rewardToken The ERC20 token used for rewards.
     */
    constructor(IERC20 _stakingToken, IERC20 _rewardToken) {
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        lastUpdateTime = block.timestamp;
    }

    /**
     * @notice Stake a specified amount of tokens.
     * @param amount The amount of tokens to stake.
     */
    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, 'Cannot stake 0');
        require(amount <= stakingToken.balanceOf(msg.sender), 'Insufficient balance for staking');

        _updateReward(msg.sender);

        totalStaked += amount;
        stakes[msg.sender].amount += amount;
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount);
    }

    /**
     * @notice Withdraw a specified amount of staked tokens.
     * @param amount The amount of tokens to withdraw.
     */
    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, 'Cannot withdraw 0');
        require(stakes[msg.sender].amount >= amount, 'Insufficient balance');

        _updateReward(msg.sender);

        totalStaked -= amount;
        stakes[msg.sender].amount -= amount;
        stakingToken.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @notice Claim rewards in ETH and reward tokens.
     */
    function claimRewards() external nonReentrant {
        require(block.timestamp > lastRewardClaim[msg.sender] + 1 hours, "Too frequent claims");
        lastRewardClaim[msg.sender] = block.timestamp;
        _updateReward(msg.sender);

        uint256 reward = stakes[msg.sender].rewards;
        uint256 rewardTokenAmount = userRewardTokenRewards[msg.sender];

        require(reward > 0 || rewardTokenAmount > 0, 'No rewards available');
        require(address(this).balance >= reward, 'Insufficient ETH balance');
        require(rewardTokenReserve >= rewardTokenAmount, 'Insufficient token reserve');

        // Reset rewards after checking balance
        stakes[msg.sender].rewards = 0;
        userRewardTokenRewards[msg.sender] = 0;

        if (reward > 0) {
            ethReserve -= reward; // Update ETH reserve
            (bool success, ) = msg.sender.call{value: reward}('');
            require(success, 'ETH transfer failed');
        }

        if (rewardTokenAmount > 0) {
            rewardTokenReserve -= rewardTokenAmount;
            rewardToken.safeTransfer(msg.sender, rewardTokenAmount);
        }

        emit RewardPaid(msg.sender, reward);
        emit RewardsClaimed(msg.sender, reward);
    }

    /**
     * @notice Update reward calculations for a user.
     * @param user The address of the user.
     */
    function _updateReward(address user) internal {
        if (totalStaked > 0) {
            uint256 newRewardPerToken = _rewardPerToken();
            rewardPerTokenStored = newRewardPerToken;

            uint256 newRewardTokenPerToken = _rewardTokenPerToken();
            rewardTokenPerTokenStored = newRewardTokenPerToken;

            lastUpdateTime = block.timestamp;
        }

        if (user != address(0)) {
            Stake storage userStake = stakes[user];
            userStake.rewards = _earned(user);
            userRewardTokenRewards[user] = _earnedInToken(user);

            userStake.rewardPerTokenPaid = rewardPerTokenStored;
            userRewardTokenPerTokenPaid[user] = rewardTokenPerTokenStored;

            emit RewardCalculated(user, userStake.rewards);
        }
    }

    /**
     * @notice Calculate the reward per token.
     * @return The reward per token.
     */
    function _rewardPerToken() internal view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }

        uint256 availableReward = ethReserve; // Use ethReserve instead of contract balance
        uint256 rewardRate = (availableReward * 1e18) / totalStaked;

        return rewardPerTokenStored + ((rewardRate * (block.timestamp - lastUpdateTime)) / 1e18);
    }

    /**
     * @notice Calculate the reward token per token.
     * @return The reward token per token.
     */
    function _rewardTokenPerToken() internal view returns (uint256) {
        if (totalStaked == 0) {
            return rewardTokenPerTokenStored;
        }

        uint256 availableRewardToken = rewardTokenReserve;
        uint256 rewardTokenRate = (availableRewardToken * 1e18) / totalStaked;

        return rewardTokenPerTokenStored + ((rewardTokenRate * (block.timestamp - lastUpdateTime)) / 1e18);
    }

    /**
     * @notice Calculate the total rewards earned by a user in ETH.
     * @param user The address of the user.
     * @return The total rewards earned by the user.
     */
    function _earned(address user) internal view returns (uint256) {
        return
            ((stakes[user].amount * (_rewardPerToken() - stakes[user].rewardPerTokenPaid)) / 1e18) +
            stakes[user].rewards;
    }

    /**
     * @notice Calculate the total rewards earned by a user in reward tokens.
     * @param user The address of the user.
     * @return The total rewards earned by the user in reward tokens.
     */
    function _earnedInToken(address user) internal view returns (uint256) {
        return
            ((stakes[user].amount * (_rewardTokenPerToken() - userRewardTokenPerTokenPaid[user])) / 1e18) +
            userRewardTokenRewards[user];
    }

    /**
     * @notice Get the balance of ETH in the contract.
     * @return The balance of ETH in the contract.
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice Get the total rewards earned by a user in ETH.
     * @param user The address of the user.
     * @return The total rewards earned by the user.
     */
    function earned(address user) external view returns (uint256) {
        return _earned(user);
    }

    /**
     * @notice Get the total rewards earned by a user in reward tokens.
     * @param user The address of the user.
     * @return The total rewards earned by the user in reward tokens.
     */
    function earnedInToken(address user) external view returns (uint256) {
        return _earnedInToken(user);
    }

    /**
     * @notice Get the reward per token.
     * @return The reward per token.
     */
    function rewardPerToken() external view returns (uint256) {
        return _rewardPerToken();
    }

    /**
     * @notice Get the reward token per token.
     * @return The reward token per token.
     */
    function rewardTokenPerToken() external view returns (uint256) {
        return _rewardTokenPerToken();
    }

    /**
     * @notice Get the current reward token reserve.
     * @return The current reward token reserve.
     */
    function getRewardTokenReserve() external view returns (uint256) {
        return rewardTokenReserve;
    }

    /**
     * @notice Receive ETH transfers.
     */
    receive() external payable {
        _updateEthReserve(); // Use internal function
    }

    /**
     * @notice Update the reward token reserve.
     * @param amount The amount to add to the reserve.
     */
    function updateRewardTokenReserve(uint256 amount) external {
        require(amount > 0, 'Amount must be greater than 0');
        rewardTokenReserve += amount;
        emit RewardTokenReserveUpdated(rewardTokenReserve);
    }

    /**
     * @notice Update the staking token.
     * @param _stakingToken The new staking token.
     */
    function updateStakingToken(IERC20 _stakingToken) external onlyOwner {
        stakingToken = _stakingToken;
        emit StakingTokenChanged(address(_stakingToken));
    }

    /**
     * @notice Update the reward token.
     * @param _rewardToken The new reward token.
     */
    function updateRewardToken(IERC20 _rewardToken) external onlyOwner {
        rewardToken = _rewardToken;
        emit RewardTokenChanged(address(_rewardToken));
    }

    /**
     * @notice Update the ETH reserve.
     */
    function updateEthReserve() external payable {
        require(msg.value > 0, 'Amount must be greater than 0');
        ethReserve += msg.value;
        emit EthReserveUpdated(ethReserve);
    }

    /**
     * @notice Internal function to update the ETH reserve when the contract receives ETH.
     * This function is called in the receive() function to track incoming ETH.
     */
    function _updateEthReserve() internal {
        ethReserve += msg.value;
        emit EthReserveUpdated(ethReserve);
    }

    /**
     * @notice Renounce ownership of the contract.
     */
    function renounceOwnership() public override onlyOwner {
        super.renounceOwnership();
    }


    /**
     * @notice Get the amount of tokens staked by a user.
     * @param user The address of the user.
     * @return The amount of tokens staked by the user.
     */
    function getStakedAmount(address user) external view returns (uint256) {
        return stakes[user].amount;
    }
}
