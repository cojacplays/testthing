// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

library MEVProtection {
    uint256 private constant BLOCK_TIME_THRESHOLD = 2; // blocks
    uint256 private constant PRICE_IMPACT_THRESHOLD = 200; // 2%

    struct MEVParams {
        uint256 maxGasPrice;
        uint256 minTimestamp;
        uint256 maxPriceImpact;
    }

    function checkMEVProtection(
        uint256 expectedPrice,
        uint256 actualPrice,
        uint256 blockTimestamp,
        MEVParams memory params
    ) internal view returns (bool) {
        // Check if transaction is being sandwiched
        if (_isPriceManipulated(expectedPrice, actualPrice, params.maxPriceImpact)) {
            return false;
        }

        // Check if we're being backrun
        if (blockTimestamp < params.minTimestamp) {
            return false;
        }

        // Check if gas price is too high (potential frontrunning)
        if (tx.gasprice > params.maxGasPrice) {
            return false;
        }

        return true;
    }

    function _isPriceManipulated(
        uint256 expectedPrice,
        uint256 actualPrice,
        uint256 maxPriceImpact
    ) private pure returns (bool) {
        if (expectedPrice > actualPrice) {
            uint256 priceDiff = expectedPrice - actualPrice;
            return (priceDiff * 10000) / expectedPrice > maxPriceImpact;
        } else {
            uint256 priceDiff = actualPrice - expectedPrice;
            return (priceDiff * 10000) / expectedPrice > maxPriceImpact;
        }
    }
}