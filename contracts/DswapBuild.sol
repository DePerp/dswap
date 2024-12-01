// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

/**
 * @title Dswap Building
 * @notice This contract implements a burnable ERC20 token with AMM functionalities and a 0.3% fee on swaps.
 */
contract DswapBuild is ERC20, ERC20Burnable, ReentrancyGuard {
    uint256 public INITIAL_SUPPLY;
    uint256 public ethReserve;
    uint256 public tokenReserve;
    uint256 public basisValue;

    uint256 private constant BPS = 10000; // bps
    uint256 public DEV_SUPPLY_PERCENT;
    uint256 private constant COMMISSION_FEE = 30; // Basis points (0.3%)
    uint224 constant Q112 = 2 ** 112;

    address public stake; // Address to receive fees
    uint256 public accumulatedFeesInToken; // Accumulated fees in the token
    uint256 public accumulatedFeesInETH; // Accumulated fees in ETH
    uint256 public lastClaimTime;
    uint256 public claimCooldown = 1 days; // claim to stake cooldown period of 1 day

    string public tokenIconIPFS; // New state variable for token icon IPFS hash

    event TokensPurchased(address indexed buyer, uint256 ethAmount, uint256 tokenAmount);
    event TokensSold(address indexed seller, uint256 tokenAmount, uint256 ethAmount);
    event ReservesUpdated(uint256 newEthReserve, uint256 newTokenReserve);
    event FeesWithdrawn(address indexed recipient, uint256 tokenAmount, uint256 ethAmount);
    event FeeAccumulated(uint256 tokenFeeAmount, uint256 ethFeeAmount); // Updated event for accumulated fees

    /**
     * @notice Constructor to initialize the token, mint initial supplies, and set the fee recipient.
     * @param _stake Address to receive fees
     * @param _name Name of the token
     * @param _symbol Symbol of the token
     * @param _initialSupply Initial total supply of the token
     * @param _devSupplyPercent Percentage of initial supply for dev (0-100)
     * @param _basisValue Base virtual reserve value for determining the initial valuation
     * @param _tokenIconIPFS IPFS hash of the token icon
     */
    constructor(
        address _stake,
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply,
        uint256 _devSupplyPercent,
        uint256 _basisValue,
        string memory _tokenIconIPFS
    ) ERC20(_name, _symbol) {
        require(_stake != address(0), 'Invalid stake address');
        require(_devSupplyPercent <= 100, 'Dev supply percent must be <= 100');
        require(_basisValue > 0, 'Basis value must be greater than 0');

        stake = _stake;
        INITIAL_SUPPLY = _initialSupply;
        DEV_SUPPLY_PERCENT = _devSupplyPercent * 100; // Convert to basis points
        basisValue = _basisValue;
        tokenIconIPFS = _tokenIconIPFS; // Set the token icon IPFS hash

        uint256 devInitialShare = (INITIAL_SUPPLY * DEV_SUPPLY_PERCENT) / BPS;
        uint256 remainingSupply = INITIAL_SUPPLY - devInitialShare;

        _mint(address(this), remainingSupply);
        _mint(msg.sender, devInitialShare);

        tokenReserve = remainingSupply;
        ethReserve = basisValue;
        emit ReservesUpdated(ethReserve, tokenReserve);
    }

    /**
     * @notice Buys tokens with ETH.
     * @param minTokenAmount The minimum amount of tokens expected to avoid slippage.
     */
    function buyTokens(uint256 minTokenAmount) external payable nonReentrant {
        // Ensure that some ETH is sent with the transaction
        require(msg.value > 0, 'You need to send some ETH');
        uint256 ethAmount = msg.value;

        // Retrieve current ETH and token reserves
        (uint256 currentEthReserve, uint256 currentTokenReserve) = getReserves();

        // Ensure there are tokens available in reserve for purchase
        require(currentTokenReserve > 0, 'Reserve is low');

        // Calculate the transaction fee as a percentage of the ETH amount
        uint256 fee = (ethAmount * COMMISSION_FEE) / BPS;

        // Calculate the amount of ETH remaining after the fee
        uint256 amountAfterFee = ethAmount - fee;

        // Determine how many tokens are equivalent to the ETH amount after fee
        uint256 tokenAmount = getSwapAmount(amountAfterFee, currentEthReserve, currentTokenReserve);

        // Ensure the amount of tokens is not less than the minimum expected
        require(tokenAmount >= minTokenAmount, 'Slippage limit exceeded');

        // Ensure there are enough tokens in the reserve to fulfill the purchase
        require(tokenAmount <= currentTokenReserve, 'Not enough tokens in reserve');

        // Update the reserves with the ETH amount after the fee
        ethReserve += amountAfterFee;
        tokenReserve -= tokenAmount;

        // Transfer the calculated amount of tokens to the buyer
        _transfer(address(this), msg.sender, tokenAmount);

        // Accumulate the fee in ETH
        accumulatedFeesInETH += fee;

        // Emit an event for the token purchase
        emit TokensPurchased(msg.sender, ethAmount, tokenAmount);

        // Emit an event to indicate updated reserves
        emit ReservesUpdated(ethReserve, tokenReserve);

        // Emit an event for the accumulated fee
        emit FeeAccumulated(0, fee);
    }

    /**
     * @notice Sells tokens for ETH.
     * @param tokenAmount The amount of tokens to sell.
     * @param minEthAmount The minimum amount of ETH expected to avoid slippage.
     */
    function sellTokens(uint256 tokenAmount, uint256 minEthAmount) external nonReentrant {
        // Ensure the token amount to sell is greater than zero
        require(tokenAmount > 0, 'You need to sell some tokens');

        // Ensure the sender has enough tokens to sell
        require(balanceOf(msg.sender) >= tokenAmount, 'Not enough tokens');

        // Retrieve the current reserves of ETH and tokens
        (uint256 currentEthReserve, uint256 currentTokenReserve) = getReserves();

        // Ensure the ETH reserve is above the minimum required basis value
        require(currentEthReserve > basisValue, 'Reserve is below the minimum basis value');

        // Calculate the amount of ETH to be returned for the specified token amount
        uint256 ethAmount = getSwapAmount(tokenAmount, currentTokenReserve, currentEthReserve);

        // Ensure the calculated ETH amount meets the minimum amount specified by the user
        require(ethAmount >= minEthAmount, 'Slippage limit exceeded');

        // Ensure the contract has enough ETH to fulfill the swap request
        require(address(this).balance >= ethAmount, 'Not enough ETH in reserve');

        // Calculate the commission fee in tokens
        uint256 fee = (tokenAmount * COMMISSION_FEE) / BPS;

        // Calculate the amount of tokens after deducting the fee
        uint256 amountAfterFee = tokenAmount - fee;

        // Update the ETH reserve before making transfers and burning tokens
        ethReserve -= ethAmount;

        // Set the current token reserve to ensure it matches the latest state
        tokenReserve = currentTokenReserve;

        // Transfer the calculated fee amount to the staking contract
        _transfer(msg.sender, stake, fee);

        // Accumulate the fee in tokens
        accumulatedFeesInToken += fee;

        // Burn the remaining tokens after the fee has been deducted
        _burn(msg.sender, amountAfterFee);

        // Transfer the ETH amount to the user
        (bool success, ) = msg.sender.call{value: ethAmount}('');

        // Ensure the ETH transfer was successful
        require(success, 'ETH transfer failed');

        // Emit an event to log the sale of tokens
        emit TokensSold(msg.sender, tokenAmount, ethAmount);

        // Emit an event to log the updated reserves
        emit ReservesUpdated(ethReserve, currentTokenReserve);

        // Emit an event to log the accumulated fees
        emit FeeAccumulated(fee, 0);
    }

    /**
     * @notice Calculates the amount of output tokens/ETH for a given input amount.
     * @param inputAmount The amount of input tokens/ETH.
     * @param inputReserve The current reserve of the input asset.
     * @param outputReserve The current reserve of the output asset.
     * @return amount of output.
     */
    function getSwapAmount(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) internal pure returns (uint256) {
        // Ensure that reserves are non-zero to avoid division by zero
        require(inputReserve > 0, 'Input reserve is zero');
        require(outputReserve > 0, 'Output reserve is zero');

        // Convert inputAmount to fixed-point representation to maintain precision
        uint256 scaledInputAmount = inputAmount * Q112;

        // Compute the numerator and denominator for the swap amount calculation
        uint256 numerator = scaledInputAmount * outputReserve;
        uint256 denominator = inputReserve * Q112 + scaledInputAmount;

        // Perform division to get the output amount
        return numerator / denominator;
    }

    /**
     * @notice Retrieves the current price of the token in terms of ETH.
     * @return scaledPrice Current price of the token in ETH, scaled by 10^18 for precision.
     */
    function getCurrentPrice() public view returns (uint256) {
        // Ensure that the token reserve is non-zero to avoid division by zero
        require(tokenReserve > 0, 'Token reserve is zero');

        // Optionally, check if ETH reserve is non-zero, although this is less critical if the token reserve is positive
        require(ethReserve > 0, 'ETH reserve is zero');

        // Calculate the price of the token in ETH, scaled by 10^18 for precision
        uint256 price = (ethReserve * 10 ** 18) / tokenReserve;

        return price;
    }

    /**
     * @notice Retrieves the current reserves.
     * @return currentEthReserve The current ETH reserve.
     * @return currentTokenReserve current token reserve.
     */
    function getReserves() public view returns (uint256 currentEthReserve, uint256 currentTokenReserve) {
        return (ethReserve, tokenReserve);
    }

    /**
     * @notice Retrieves the current reserves.
     * @return tokenReserve current token reserve.
     */
    function getTokenReserve() external view returns (uint256) {
        return tokenReserve;
    }

    /**
     * @notice Retrieves the current reserves.
     * @return ethReserve The current ETH reserve.
     */
    function getEthReserve() external view returns (uint256) {
        return ethReserve;
    }

    /**
     * @notice Retrieves the current accumulated fees in tokens.
     * @return accumulatedFeesInToken The current accumulated fees in tokens.
     */
    function getAccumulatedFeesInToken() external view returns (uint256) {
        return accumulatedFeesInToken;
    }

    /**
     * @notice Retrieves the current accumulated fees in ETH.
     * @return accumulatedFeesInETH The current accumulated fees in ETH.
     */
    function getAccumulatedFeesInETH() external view returns (uint256) {
        return accumulatedFeesInETH;
    }

    /**
     * @notice Estimates the amount of tokens for a given amount of ETH.
     * @param ethAmount The amount of ETH.
     * @return tokenAmount estimated amount of tokens.
     */
    function getEstimatedTokensForETH(uint256 ethAmount) external view returns (uint256) {
        require(ethAmount > 0, 'ETH amount must be greater than zero');

        (uint256 currentEthReserve, uint256 currentTokenReserve) = getReserves();

        uint256 tokenAmount = getSwapAmount(ethAmount, currentEthReserve, currentTokenReserve);

        return tokenAmount;
    }

    /**
     * @notice Estimates the amount of ETH for a given amount of tokens.
     * @param tokenAmount The amount of tokens.
     * @return ethAmount estimated amount of ETH.
     */
    function getEstimatedETHForTokens(uint256 tokenAmount) external view returns (uint256) {
        require(tokenAmount > 0, 'Token amount must be greater than zero');

        (uint256 currentEthReserve, uint256 currentTokenReserve) = getReserves();

        uint256 ethAmount = getSwapAmount(tokenAmount, currentTokenReserve, currentEthReserve);

        return ethAmount;
    }

    /**
     * @notice Claim accumulated fees to the stake address in both ETH and token.
     */
    function claimFees() external nonReentrant {
        require(block.timestamp >= lastClaimTime + claimCooldown, 'Cooldown period has not passed');
        require(stake != address(0), 'Stake address not set');

        uint256 tokenAmount = accumulatedFeesInToken;
        uint256 ethAmount = accumulatedFeesInETH;

        accumulatedFeesInToken = 0;
        accumulatedFeesInETH = 0;

        lastClaimTime = block.timestamp;

        if (tokenAmount > 0) {
            _transfer(address(this), stake, tokenAmount);

            (bool success, bytes memory data) = stake.call(
                abi.encodeWithSelector(bytes4(keccak256('updateRewardTokenReserve(uint256)')), tokenAmount)
            );
            require(success && (data.length == 0 || abi.decode(data, (bool))), 'Failed to update stake token reserve');
        }

        if (ethAmount > 0) {
            (bool success, ) = payable(stake).call{value: ethAmount}('');
            require(success, 'ETH transfer failed');
        }

        emit FeesWithdrawn(stake, tokenAmount, ethAmount);
    }
}
