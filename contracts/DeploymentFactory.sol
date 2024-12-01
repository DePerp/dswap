// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./DswapBuild.sol";
import "./StakeY.sol";

contract DeploymentFactory {
    address public feeRecipient;
    uint256 public feePercent;
    uint256 public deploymentCount;
    uint256 public constant BPS = 10000; // 100% in basis points

    struct TokenInfo {
        address tokenAddress;
        address stakingAddress;
        string name;
        string symbol;
        string tokenIconIPFS;
        uint256 initialSupply;
        uint256 devSupplyPercent;
        uint256 basisValue;
    }

    mapping(uint256 => TokenInfo) public deploymentInfo;

    event Deployed(uint256 indexed id, address indexed tokenAddress, address indexed stakingAddress, uint256 feeAmount);

    constructor(address _feeRecipient, uint256 _feePercent) {
        feeRecipient = _feeRecipient;
        feePercent = _feePercent;
    }

    function deploy(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply,
        uint256 _devSupplyPercent,
        uint256 _basisValue,
        string memory _tokenIconIPFS
    ) external returns (address tokenAddress, address stakingAddress) {
        // Deploy StakingY contract first
        StakeY staking = new StakeY(IERC20(address(0)), IERC20(address(0)));

        // Deploy DswapBuild token
        DswapBuild token = new DswapBuild(
            address(staking),
            _name,
            _symbol,
            _initialSupply,
            _devSupplyPercent,
            _basisValue,
            _tokenIconIPFS
        );

        uint256 factoryBalance = token.balanceOf(address(this));
        uint256 feeAmount = (factoryBalance * feePercent) / BPS;
        uint256 devFinalAmount = factoryBalance - feeAmount;
        token.transfer(msg.sender, devFinalAmount);
        token.transfer(feeRecipient, feeAmount);

        // Update staking and reward tokens in StakingY
        staking.updateStakingToken(IERC20(address(token)));
        staking.updateRewardToken(IERC20(address(token)));

        // Renounce ownership of StakingY
        staking.renounceOwnership();

        // Verify setup
        require(address(token.stake()) == address(staking), "Stake address not set correctly");
        require(address(staking.stakingToken()) == address(token), "Staking token not set correctly");
        require(address(staking.rewardToken()) == address(token), "Reward token not set correctly");
        require(staking.owner() == address(0), "Ownership not renounced");

        uint256 deploymentId = deploymentCount;
        deploymentInfo[deploymentId] = TokenInfo({
            tokenAddress: address(token),
            stakingAddress: address(staking),
            name: _name,
            symbol: _symbol,
            tokenIconIPFS: _tokenIconIPFS,
            initialSupply: _initialSupply,
            devSupplyPercent: _devSupplyPercent,
            basisValue: _basisValue
        });
        deploymentCount++;

        emit Deployed(deploymentId, address(token), address(staking), feeAmount);

        return (address(token), address(staking));
    }

    function getDeploymentInfo(uint256 _id) public view returns (TokenInfo memory) {
        require(_id < deploymentCount, "Invalid deployment ID");
        return deploymentInfo[_id];
    }

    function getDeploymentCount() public view returns (uint256) {
        return deploymentCount;
    }
}