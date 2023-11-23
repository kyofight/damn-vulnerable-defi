![](cover.png)

**A set of challenges to learn offensive security of smart contracts in Ethereum.**

Featuring flash loans, price oracles, governance, NFTs, lending pools, smart contract wallets, timelocks, and more!

## Play

Visit [damnvulnerabledefi.xyz](https://damnvulnerabledefi.xyz)

## Help

You may find the solutions in the `tests` and `contracts` folder.

# Hints

## 1. Unstoppable
The `totalAssets()` function is overridden to return the token balance of the vault. Therefore, transferring token to the vault may increase of the `totalAssets()` but not the `convertToShares(totalSupply)`.

## 2. Naive Receiver
The `NaiveReceiverLenderPool` takes `1 ether` per flash loan transaction from the receiver of `FlashLoanReceiver`. All we have to do is to deploy a contract to call the `flashLoan` multiple times until all of the funds are drained.

## 3. Truster
The `flashLoan` of `TrusterLenderPool` executes an arbitrary target and calldata. Just simply call the token `approve` so that the player can drain all funds from the pool.

## 4. Side Entrance
The `flashLoan` of `SideEntranceLenderPool` calls a `execute` function of the `msg.sender` (attacker contract). In the `execute` function, we can call the `deposit` function with the balance borrowed from the flash loan such that the balance check `if (address(this).balance < balanceBefore)` after the `execute` is increased.

## 5. The Rewarder
The `flashLoan` of `FlashLoanerPool` calls `msg.sender` (attacker contract) the function `receiveFlashLoan`. We can do nasty things here: call `TheRewarderPool` pool `deposit` for a snapshot of balance for reward, and then transfer the reward token to the player.

## 6. Selfie
The `flashLoan` of `SelfiePool` calls `receiver` (attacker contract) the function `onFlashLoan` which can call `governanceToken.balanceOfAt(address(this), snapshotId);` to take a snapshot with borrowed token so that it can bypass the `_hasEnoughVotes` validation for `queueAction`.

## 7. Compromised
The leaked data is about the private keys of the two oracles. Just decode them so you can manipulate the price feed of the exchange.

## 8. Puppet
Given enough initial token balance, we can manipulate the price of the exchnage pair which is used by the pool to calculate how many token can be borrowed with ETH. <br />
Note: The tricky thing here is that you need to do it in single transaction, so ERC20 `permit` function is used to grant right for attacker contract to spend token.

## 9. Puppet V2
Same as `Puppet` chanllenge, this time, it is easier as you dont need to do it in one transaction. <br />
Note: You need to call `deposit` of `WETH` to do wrapping

## 10. Free Rider
The loophole is in the function `buyMany` of `FreeRiderNFTMarketplace` that you only offer a piece of the NFT price and you can buy all of them `if (msg.value < priceToPay)`. However, the player does not have enough initial balance to even buy one NFT. You may use `flash swap` of uniswap to do borrow, buy NFT, get rewards and payback.

## 11. Backdoor
Upon Gnosis proxy creation, it executes `createProxyWithCallback` => `createProxyWithNonce` => `call(gas(), proxy, 0, add(initializer, 0x20), mload(initializer), 0, 0)`. The initilizer call executes the functions `GnosisSafe.setup` => `setupModules(to, data);` (delegatecall in the context of the caller). We can place an exploit contract with `approve` token spending so that the wallet grants the right to the player to spend. 

## 12. Climber
The `if (getOperationState(id) != OperationState.ReadyForExecution)` validation is done after the function call `targets[i].functionCallWithValue(dataElements[i], values[i]);`. We can make use of this logic error to make different functions calls in sequence to drain all of the funds.

## 13. Wallet Mining
This challenge has two exploits from two different incidents: <br />
1. Replay Attack: https://mirror.xyz/0xbuidlerdao.eth/lOE5VN-BHI0olGOXe27F0auviIuoSlnou_9t3XRJseY (An in-depth analysis of how 20 million $OP got stolen). Since the challenge mentions it is using `official Gnosis contracts`, we get the raw transaction data from etherscan and recreate the Gnosis contracts. The deposit wallet proxy is then created from the official `GnosisSafeProxyFactory` <br />
2. Uninitialized UUPS Proxy: https://medium.com/immunefi/wormhole-uninitialized-proxy-bugfix-review-90250c41a43a (Wormhole Uninitialized Proxy Bugfix Review). The implementation is `NOT initialized` and we can get the implementation contract and then execute `selfdestruct` to render the proxy useless. <br />

## 14. Puppet V3
Similar to `Puppet V2`, player can dump all the tokens to buy weth to manipulate the price for borrowing from the pool. The most important thing is the deep understanding of uniswap v3 mechanism, especially `MAX_SQRT_RATIO` https://www.youtube.com/watch?v=EV23xTgWsnY such that the ratio of the pair is skewed after a swap.

## 15. ABI Smuggling
The calldata of `execute` in `AuthorizedExecutor` can be packed the way we want (learn more here: https://docs.soliditylang.org/en/latest/abi-spec.html#use-of-dynamic-types). The player has the `withdraw` function execution permission. We can make use of this permission to bypass the check and pack `sweepFunds` after the `withdraw` in calldata.