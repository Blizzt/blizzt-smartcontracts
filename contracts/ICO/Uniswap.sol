// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../interfaces/IERC20.sol";
import "../interfaces/IUniswapV2Router02.sol";

contract Uniswap {

    IUniswapV2Router02 immutable private uniswapRouter;

    constructor(address _uniswapRouter) {
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
    }

    function createPool(address _token) external payable {
        
        uint256 maticOnUniswap = msg.value;
        uint256 tokensOnUniswap = maticOnUniswap * 10000;

        IERC20(_token).transferFrom(msg.sender, address(this), tokensOnUniswap);
        IERC20(_token).approve(address(uniswapRouter), tokensOnUniswap);
      
        uniswapRouter.addLiquidityETH{value: maticOnUniswap}(
            _token,
            tokensOnUniswap,
            0,
            0,
            msg.sender,
            block.timestamp
        );
    }

    function getPoolAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts) {
        return uniswapRouter.getAmountsOut(amountIn, path);
    }

    function getPoolAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts) {
        return uniswapRouter.getAmountsIn(amountOut, path);
    }
}