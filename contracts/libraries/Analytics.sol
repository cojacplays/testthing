// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

library Analytics {
    struct TradingStats {
        uint256 totalTrades;
        uint256 successfulTrades;
        uint256 failedTrades;
        uint256 totalProfit;
        uint256 totalGasUsed;
        uint256 lastTradeTimestamp;
    }

    function calculateSuccessRate(TradingStats memory stats) internal pure returns (uint256) {
        if (stats.totalTrades == 0) return 0;
        return (stats.successfulTrades * 10000) / stats.totalTrades;
    }

    function calculateAverageProfit(TradingStats memory stats) internal pure returns (uint256) {
        if (stats.successfulTrades == 0) return 0;
        return stats.totalProfit / stats.successfulTrades;
    }

    function calculateAverageGasUsed(TradingStats memory stats) internal pure returns (uint256) {
        if (stats.totalTrades == 0) return 0;
        return stats.totalGasUsed / stats.totalTrades;
    }
}