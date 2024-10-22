// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@aave/core-v3/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";
import "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/ISushiSwapRouter.sol";
import "./libraries/PriceLib.sol";
import "./libraries/MEVProtection.sol";
import "./libraries/PathFinder.sol";
import "./libraries/RiskManagement.sol";
import "./libraries/Analytics.sol";

/// @title Flash Loan Arbitrage with Enhanced Protection
/// @notice Executes arbitrage opportunities using flash loans with MEV protection
/// @dev Uses Chainlink price feeds for additional price verification
contract FlashLoanArbitrage is FlashLoanSimpleReceiverBase, ReentrancyGuard, Pausable {
    using MEVProtection for *;
    using PathFinder for *;
    using RiskManagement for *;
    using Analytics for *;

    // Immutable state variables for gas optimization
    address private immutable owner;
    uint256 private immutable COOL_DOWN_PERIOD;
    
    // DEX Routers
    address[] public supportedRouters;
    mapping(address => bool) public isRouterSupported;
    
    // Risk Management
    mapping(address => bool) public tokenBlacklist;
    RiskManagement.RiskParams public riskParams;
    MEVProtection.MEVParams public mevParams;
    
    // Analytics tracking
    Analytics.TradingStats public tradingStats;
    mapping(address => uint256) public tokenVolumes;
    uint256 public lastTradeTimestamp;
    
    // Price feeds
    mapping(address => address) public priceFeeds;
    uint256 private constant PRICE_FEED_TIMEOUT = 3600; // 1 hour
    
    // Custom errors for gas optimization
    error Unauthorized();
    error InvalidRouter();
    error CooldownPeriod();
    error PriceFeedTimeout();
    error ExcessiveSlippage();
    error InvalidProfit();

    // Events
    event ArbitrageExecuted(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 profit,
        uint256 gasUsed,
        uint256 timestamp,
        address[] path
    );

    event ArbitrageFailed(
        address indexed tokenIn,
        string reason,
        uint256 gasUsed,
        uint256 timestamp
    );

    event RiskParamsUpdated(
        uint256 maxTradeSize,
        uint256 minLiquidity,
        uint256 maxPriceImpact
    );

    event PriceFeedUpdated(
        address indexed token,
        address indexed priceFeed
    );

    constructor(
        address _addressProvider,
        address[] memory _routers,
        address[] memory _intermediaryTokens,
        RiskManagement.RiskParams memory _riskParams,
        MEVProtection.MEVParams memory _mevParams
    ) FlashLoanSimpleReceiverBase(IPoolAddressesProvider(_addressProvider)) {
        owner = msg.sender;
        COOL_DOWN_PERIOD = 2 minutes;
        
        // Initialize routers
        for (uint i = 0; i < _routers.length; i++) {
            supportedRouters.push(_routers[i]);
            isRouterSupported[_routers[i]] = true;
        }
        
        riskParams = _riskParams;
        mevParams = _mevParams;
        
        // Initialize analytics
        tradingStats = Analytics.TradingStats({
            totalTrades: 0,
            successfulTrades: 0,
            failedTrades: 0,
            totalProfit: 0,
            totalGasUsed: 0,
            lastTradeTimestamp: 0
        });
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier checkCooldown() {
        if (block.timestamp - lastTradeTimestamp < COOL_DOWN_PERIOD) 
            revert CooldownPeriod();
        _;
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external override nonReentrant whenNotPaused returns (bool) {
        uint256 startGas = gasleft();
        
        try {
            PathFinder.PathInfo memory bestPath = abi.decode(params, (PathFinder.PathInfo));
            
            // Verify price feed
            if (priceFeeds[asset] != address(0)) {
                require(
                    _verifyPriceFeed(asset, bestPath.expectedOutput),
                    "Price feed verification failed"
                );
            }
            
            // MEV Protection checks
            require(
                MEVProtection.checkMEVProtection(
                    bestPath.expectedOutput,
                    IUniswapV2Router(bestPath.router).getAmountsOut(amount, bestPath.path)[1],
                    block.timestamp,
                    mevParams
                ),
                "MEV protection triggered"
            );
            
            // Execute trade
            IERC20(asset).approve(bestPath.router, amount);
            
            uint256[] memory amounts = IUniswapV2Router(bestPath.router)
                .swapExactTokensForTokens(
                    amount,
                    bestPath.expectedOutput * (10000 - mevParams.maxPriceImpact) / 10000,
                    bestPath.path,
                    address(this),
                    block.timestamp
                );
                
            // Update analytics
            uint256 profit = amounts[amounts.length - 1] - (amount + premium);
            _updateAnalytics(true, profit, startGas - gasleft(), asset);
            
            // Repay flash loan
            IERC20(asset).approve(address(POOL), amount + premium);
            
            emit ArbitrageExecuted(
                asset,
                bestPath.path[bestPath.path.length - 1],
                profit,
                startGas - gasleft(),
                block.timestamp,
                bestPath.path
            );
            
            return true;
        } catch (bytes memory reason) {
            _updateAnalytics(false, 0, startGas - gasleft(), asset);
            emit ArbitrageFailed(asset, string(reason), startGas - gasleft(), block.timestamp);
            return false;
        }
    }

    function _verifyPriceFeed(address token, uint256 expectedPrice) internal view returns (bool) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeeds[token]);
        (, int256 price, , uint256 updatedAt, ) = priceFeed.latestRoundData();
        
        if (block.timestamp - updatedAt > PRICE_FEED_TIMEOUT) revert PriceFeedTimeout();
        
        uint256 chainlinkPrice = uint256(price);
        uint256 deviation = expectedPrice > chainlinkPrice ? 
            expectedPrice - chainlinkPrice : chainlinkPrice - expectedPrice;
            
        return deviation <= (chainlinkPrice * riskParams.maxPriceImpact) / 10000;
    }

    function _updateAnalytics(
        bool success,
        uint256 profit,
        uint256 gasUsed,
        address token
    ) internal {
        tradingStats.totalTrades++;
        if (success) {
            tradingStats.successfulTrades++;
            tradingStats.totalProfit += profit;
        } else {
            tradingStats.failedTrades++;
        }
        tradingStats.totalGasUsed += gasUsed;
        tradingStats.lastTradeTimestamp = block.timestamp;
        
        tokenVolumes[token] += profit;
    }

    // Configuration functions
    function setPriceFeed(address token, address feed) external onlyOwner {
        priceFeeds[token] = feed;
        emit PriceFeedUpdated(token, feed);
    }

    function updateRiskParams(RiskManagement.RiskParams memory _riskParams) external onlyOwner {
        riskParams = _riskParams;
        emit RiskParamsUpdated(
            _riskParams.maxTradeSize,
            _riskParams.minLiquidity,
            _riskParams.maxPriceImpact
        );
    }

    // Emergency functions
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function withdraw(address token) external onlyOwner {
        IERC20(token).transfer(owner, IERC20(token).balanceOf(address(this)));
    }
    
    receive() external payable {}
}