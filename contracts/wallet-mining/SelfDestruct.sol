// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract SelfDestruct is UUPSUpgradeable {
    function terminate(address receiver) external payable {
        selfdestruct(payable(receiver));
    }
    function _authorizeUpgrade(address imp) internal override {}
}