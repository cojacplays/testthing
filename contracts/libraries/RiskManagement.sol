// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

library RiskManagement {
    struct RiskParams {
        uint256 maxTradeSize;
        uint256 minLiquidity;
        uint256 maxPriceImpact;
        uint256 circuitBreakerThreshold;
    }

    error ExcessiveTradeSize();
    error InsufficientLiquidity();
    error CircuitBreakerTriggered();
    error BlacklistedToken();

    function enforceRiskLimits(
        uint256 tradeSize,
        uint256 poolLiquidity,
        uint256 priceImpact,
        address token,
        mapping(address => bool) storage blacklist,
        RiskParams memory params
    ) internal view {
        // Check trade size
        if (tradeSize > params.maxTradeSize) {
            revert ExcessiveTradeSize();
        }

        // Check liquidity
        if (poolLiquidity < params.minLiquidity) {
            revert InsufficientLiquidity();
        }

        // Check price impact
        if (priceImpact > params.maxPriceImpact) {
            revert CircuitBreakerTriggered();
        }

        // Check blacklist
        if (blacklist[token]) {
            revert BlacklistedToken();
        }
    }
}