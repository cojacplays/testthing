// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../interfaces/IUniswapV2Router.sol";

library PathFinder {
    struct PathInfo {
        address[] path;
        uint256 expectedOutput;
        address router;
    }

    function findBestPath(
        address[] memory routers,
        address tokenIn,
        address tokenOut,
        address[] memory intermediaryTokens,
        uint256 amount
    ) internal view returns (PathInfo memory) {
        PathInfo memory bestPath;
        uint256 bestOutput = 0;

        // Check direct path
        for (uint i = 0; i < routers.length; i++) {
            address[] memory directPath = new address[](2);
            directPath[0] = tokenIn;
            directPath[1] = tokenOut;

            uint256 output = IUniswapV2Router(routers[i])
                .getAmountsOut(amount, directPath)[1];

            if (output > bestOutput) {
                bestOutput = output;
                bestPath.path = directPath;
                bestPath.router = routers[i];
                bestPath.expectedOutput = output;
            }
        }

        // Check paths with one intermediate token
        for (uint i = 0; i < intermediaryTokens.length; i++) {
            for (uint j = 0; j < routers.length; j++) {
                address[] memory path = new address[](3);
                path[0] = tokenIn;
                path[1] = intermediaryTokens[i];
                path[2] = tokenOut;

                uint256[] memory amounts = IUniswapV2Router(routers[j])
                    .getAmountsOut(amount, path);
                uint256 output = amounts[amounts.length - 1];

                if (output > bestOutput) {
                    bestOutput = output;
                    bestPath.path = path;
                    bestPath.router = routers[j];
                    bestPath.expectedOutput = output;
                }
            }
        }

        return bestPath;
    }
}