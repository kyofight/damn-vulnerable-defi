// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "../DamnValuableToken.sol";

contract TokenApprove {
    // delegatecall from GnosisSafe setupModules(to, data)
    function approve(DamnValuableToken token, address to, uint256 amount) external {
        token.approve(to, amount);
    }
}