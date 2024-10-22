// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../interfaces/IUniswapV2Router.sol";
import "../interfaces/ISushiSwapRouter.sol";

library PriceLib {
    function checkPriceDisparity(
        address uniswapRouter,
        address sushiswapRouter,
        address tokenIn,
        address tokenOut,
        uint256 amount
    ) internal view returns (bool, uint256) {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        uint256 uniswapPrice = IUniswapV2Router(uniswapRouter)
            .getAmountsOut(amount, path)[1];
        uint256 sushiswapPrice = ISushiSwapRouter(sushiswapRouter)
            .getAmountsOut(amount, path)[1];

        if (uniswapPrice > sushiswapPrice) {
            return (true, uniswapPrice - sushiswapPrice);
        } else if (sushiswapPrice > uniswapPrice) {
            return (true, sushiswapPrice - uniswapPrice);
        }

        return (false, 0);
    }
}