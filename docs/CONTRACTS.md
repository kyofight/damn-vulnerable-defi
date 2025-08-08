# Contracts Reference

This document summarizes all public and external functions of the contracts in `contracts/`, with brief descriptions and usage examples drawn from the tests under `test/`.

Note: Role modifiers and access control (e.g., `onlyOwner`, `onlyRoles`, etc.) are included where relevant.

---

## Common Tokens

### `DamnValuableToken` (`contracts/DamnValuableToken.sol`)
- ERC20 token with 18 decimals. Mints `type(uint256).max` to deployer at construction.
- Constructor: `constructor() ERC20("DamnValuableToken", "DVT", 18)`

Example:
```solidity
DamnValuableToken token = await (await ethers.getContractFactory('DamnValuableToken')).deploy();
```

### `DamnValuableTokenSnapshot` (`contracts/DamnValuableTokenSnapshot.sol`)
- ERC20 Snapshot token used for governance snapshots.
- Constructor: `constructor(uint256 initialSupply)` mints `initialSupply` to deployer.
- `function snapshot() public returns (uint256 lastSnapshotId)`
- `function getBalanceAtLastSnapshot(address account) external view returns (uint256)`
- `function getTotalSupplyAtLastSnapshot() external view returns (uint256)`

Example (from Selfie):
```solidity
await token.snapshot();
uint256 bal = await token.getBalanceAtLastSnapshot(addr);
```

### `DamnValuableNFT` (`contracts/DamnValuableNFT.sol`)
- ERC721 + burnable, role-based minting.
- Roles: `MINTER_ROLE`
- `function safeMint(address to) public onlyRoles(MINTER_ROLE) returns (uint256 tokenId)`

Example (marketplace mints): see `FreeRiderNFTMarketplace` constructor.

---

## Unstoppable (ERC4626 + Flash Loans)

### `UnstoppableVault` (`contracts/unstoppable/UnstoppableVault.sol`)
- ERC4626 vault + IERC3156 flash lender with optional fee and a grace period.
- Events: `FeeRecipientUpdated(address newFeeRecipient)`
- Errors: `InvalidAmount`, `InvalidBalance`, `CallbackFailed`, `UnsupportedCurrency`
- Constants: `FEE_FACTOR`, `GRACE_PERIOD`
- `function maxFlashLoan(address _token) public view returns (uint256)`
- `function flashFee(address _token, uint256 _amount) public view returns (uint256)`
- `function flashLoan(IERC3156FlashBorrower receiver, address _token, uint256 amount, bytes calldata data) external returns (bool)`
- `function setFeeRecipient(address _feeRecipient) external onlyOwner`
- `function totalAssets() public view override returns (uint256)`

Usage (test):
```solidity
receiver = await (await ethers.getContractFactory('ReceiverUnstoppable', someUser)).deploy(vault.address);
await receiver.executeFlashLoan(100e18);
```

### `ReceiverUnstoppable` (`contracts/unstoppable/ReceiverUnstoppable.sol`)
- Ownable flash loan receiver.
- `function onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata) external returns (bytes32)`
- `function executeFlashLoan(uint256 amount) external onlyOwner`

---

## Truster (Arbitrary call during flash loan)

### `TrusterLenderPool` (`contracts/truster/TrusterLenderPool.sol`)
- Errors: `RepayFailed`
- `function flashLoan(uint256 amount, address borrower, address target, bytes calldata data) external nonReentrant returns (bool)`

Usage (test):
```solidity
const calldata = token.interface.encodeFunctionData('approve', [player.address, TOKENS_IN_POOL]);
await pool.connect(player).flashLoan(TOKENS_IN_POOL, pool.address, token.address, calldata);
```

---

## Naive Receiver (Fixed-fee flash loans in ETH)

### `NaiveReceiverLenderPool` (`contracts/naive-receiver/NaiveReceiverLenderPool.sol`)
- IERC3156-style ETH flash loans; fixed fee of 1 ETH.
- Errors: `RepayFailed`, `UnsupportedCurrency`, `CallbackFailed`
- `function maxFlashLoan(address token) external view returns (uint256)`
- `function flashFee(address token, uint256) external pure returns (uint256)`
- `function flashLoan(IERC3156FlashBorrower receiver, address token, uint256 amount, bytes calldata data) external returns (bool)`
- `receive() external payable`

### `FlashLoanReceiver` (`contracts/naive-receiver/FlashLoanReceiver.sol`)
- `function onFlashLoan(address, address token, uint256 amount, uint256 fee, bytes calldata) external returns (bytes32)`
- `receive() external payable`

Usage (drain receiver via repeated loans): see `NaiveReceiverAttacker` constructor in test.

---

## Side Entrance (Deposit/withdraw accounting)

### `SideEntranceLenderPool` (`contracts/side-entrance/SideEntranceLenderPool.sol`)
- Errors: `RepayFailed`
- Events: `Deposit(address who, uint256 amount)`, `Withdraw(address who, uint256 amount)`
- `function deposit() external payable`
- `function withdraw() external`
- `function flashLoan(uint256 amount) external`

Usage:
```solidity
const attacker = await (await ethers.getContractFactory('SideEntranceAttacker', player)).deploy(pool.address, player.address);
await attacker.flashLoan(ETHER_IN_POOL);
await attacker.transfer();
```

---

## The Rewarder (Snapshots + distribution)

### `FlashLoanerPool` (`contracts/the-rewarder/FlashLoanerPool.sol`)
- Errors: `NotEnoughTokenBalance`, `CallerIsNotContract`, `FlashLoanNotPaidBack`
- `function flashLoan(uint256 amount) external nonReentrant`

### `RewardToken` (`contracts/the-rewarder/RewardToken.sol`)
- Roles: `MINTER_ROLE`
- `function mint(address to, uint256 amount) external onlyRoles(MINTER_ROLE)`

### `AccountingToken` (`contracts/the-rewarder/AccountingToken.sol`)
- Roles: `MINTER_ROLE`, `SNAPSHOT_ROLE`, `BURNER_ROLE`
- `function mint(address to, uint256 amount) external onlyRoles(MINTER_ROLE)`
- `function burn(address from, uint256 amount) external onlyRoles(BURNER_ROLE)`
- `function snapshot() external onlyRoles(SNAPSHOT_ROLE) returns (uint256)`

### `TheRewarderPool` (`contracts/the-rewarder/TheRewarderPool.sol`)
- Constants: `REWARDS_ROUND_MIN_DURATION`, `REWARDS`
- Public state: `liquidityToken`, `accountingToken`, `rewardToken`, `roundNumber`, `lastSnapshotIdForRewards`, `lastRecordedSnapshotTimestamp`
- Errors: `InvalidDepositAmount`
- `function deposit(uint256 amount) external`
- `function withdraw(uint256 amount) external`
- `function distributeRewards() public returns (uint256 rewards)`
- `function isNewRewardsRound() public view returns (bool)`

Usage (test):
```solidity
await rewarderPool.connect(user).deposit(amount);
await rewarderPool.connect(user).distributeRewards();
```

---

## Selfie (Governance + ERC3156 flash loans)

### `ISimpleGovernance` (`contracts/selfie/ISimpleGovernance.sol`)
- Types: `GovernanceAction`
- Events: `ActionQueued`, `ActionExecuted`
- Errors: `NotEnoughVotes`, `CannotExecute`, `InvalidTarget`, `TargetMustHaveCode`, `ActionFailed`
- Key functions: `queueAction(address,uint128,bytes)`, `executeAction(uint256)`, getters.

### `SimpleGovernance` (`contracts/selfie/SimpleGovernance.sol`)
- `function queueAction(address target, uint128 value, bytes calldata data) external returns (uint256 actionId)`
- `function executeAction(uint256 actionId) external payable returns (bytes memory)`
- `function getActionDelay() external pure returns (uint256)`
- `function getGovernanceToken() external view returns (address)`
- `function getAction(uint256 actionId) external view returns (GovernanceAction memory)`
- `function getActionCounter() external view returns (uint256)`

### `SelfiePool` (`contracts/selfie/SelfiePool.sol`)
- IERC3156 flash lender over an ERC20Snapshot token.
- Errors: `RepayFailed`, `CallerNotGovernance`, `UnsupportedCurrency`, `CallbackFailed`
- Events: `FundsDrained(address receiver, uint256 amount)`
- `function maxFlashLoan(address _token) external view returns (uint256)`
- `function flashFee(address _token, uint256) external view returns (uint256)`
- `function flashLoan(IERC3156FlashBorrower _receiver, address _token, uint256 _amount, bytes calldata _data) external nonReentrant returns (bool)`
- `function emergencyExit(address receiver) external onlyGovernance`

Usage (test):
```solidity
await pool.flashLoan(attacker.address, token.address, TOKENS_IN_POOL, '0x');
await governance.executeAction(actionId);
```

---

## Compromised (Oracle + Exchange)

### `TrustfulOracle` (`contracts/compromised/TrustfulOracle.sol`)
- Roles: `TRUSTED_SOURCE_ROLE`, `INITIALIZER_ROLE`
- Events: `UpdatedPrice(address source, string symbol, uint256 oldPrice, uint256 newPrice)`
- Errors: `NotEnoughSources`
- `function setupInitialPrices(address[] calldata sources, string[] calldata symbols, uint256[] calldata prices) external onlyRole(INITIALIZER_ROLE)`
- `function postPrice(string calldata symbol, uint256 newPrice) external onlyRole(TRUSTED_SOURCE_ROLE)`
- `function getMedianPrice(string calldata symbol) external view returns (uint256)`
- `function getAllPricesForSymbol(string memory symbol) public view returns (uint256[] memory)`
- `function getPriceBySource(string memory symbol, address source) public view returns (uint256)`

### `TrustfulOracleInitializer` (`contracts/compromised/TrustfulOracleInitializer.sol`)
- Constructor deploys `TrustfulOracle` and initializes prices.
- Event: `NewTrustfulOracle(address oracleAddress)`

### `Exchange` (`contracts/compromised/Exchange.sol`)
- Events: `TokenBought(address buyer, uint256 tokenId, uint256 price)`, `TokenSold(address seller, uint256 tokenId, uint256 price)`
- Errors: `InvalidPayment`, `SellerNotOwner`, `TransferNotApproved`, `NotEnoughFunds`
- `function buyOne() external payable nonReentrant returns (uint256 id)`
- `function sellOne(uint256 id) external nonReentrant`

Usage (test):
```solidity
await oracle.connect(source).postPrice('DVNFT', newPrice);
const id = await exchange.connect(buyer).buyOne({ value: price });
await nft.connect(buyer).approve(exchange.address, id);
await exchange.connect(buyer).sellOne(id);
```

---

## Puppet (v1, v2, v3 lending pools)

### `PuppetPool` (`contracts/puppet/PuppetPool.sol`)
- Errors: `NotEnoughCollateral`, `TransferFailed`
- Events: `Borrowed(address account, address recipient, uint256 depositRequired, uint256 borrowAmount)`
- `function borrow(uint256 amount, address recipient) external payable nonReentrant`
- `function calculateDepositRequired(uint256 amount) public view returns (uint256)`

### `PuppetV2Pool` (`contracts/puppet-v2/PuppetV2Pool.sol`)
- `function borrow(uint256 borrowAmount) external`
- `function calculateDepositOfWETHRequired(uint256 tokenAmount) public view returns (uint256)`

### `PuppetV3Pool` (`contracts/puppet-v3/PuppetV3Pool.sol`)
- Events: `Borrowed(address borrower, uint256 depositAmount, uint256 borrowAmount)`
- `function borrow(uint256 borrowAmount) external`
- `function calculateDepositOfWETHRequired(uint256 amount) public view returns (uint256)`

Usage (v1 example):
```solidity
await uniswapExchange.addLiquidity(...);
await lendingPool.borrow{ value: requiredEth }(amount, recipient);
```

---

## Free Rider (NFT Marketplace + Flash swap)

### `FreeRiderNFTMarketplace` (`contracts/free-rider/FreeRiderNFTMarketplace.sol`)
- Events: `NFTOffered(address offerer, uint256 tokenId, uint256 price)`, `NFTBought(address buyer, uint256 tokenId, uint256 price)`
- Errors: `InvalidPricesAmount`, `InvalidTokensAmount`, `InvalidPrice`, `CallerNotOwner`, `InvalidApproval`, `TokenNotOffered`, `InsufficientPayment`
- Public state: `DamnValuableNFT public token; uint256 public offersCount;`
- `function offerMany(uint256[] calldata tokenIds, uint256[] calldata prices) external nonReentrant`
- `function buyMany(uint256[] calldata tokenIds) external payable nonReentrant`

### `FreeRiderRecovery` (`contracts/free-rider/FreeRiderRecovery.sol`)
- IERC721Receiver implementation that pays a bounty when receiving all NFTs.
- Errors: `NotEnoughFunding`, `CallerNotNFT`, `OriginNotBeneficiary`, `InvalidTokenID`, `StillNotOwningToken`
- `function onERC721Received(address, address, uint256 _tokenId, bytes memory _data) external override nonReentrant returns (bytes4)`

Usage (test):
```solidity
await marketplace.offerMany([0,1,2,3,4,5], Array(6).fill(price));
await attacker.attack(NFT_PRICE);
```

---

## Backdoor (Gnosis Safe registry)

### `WalletRegistry` (`contracts/backdoor/WalletRegistry.sol`)
- Ownable, callback registry rewarding Safe wallets created by known beneficiaries.
- Errors: `NotEnoughFunds`, `CallerNotFactory`, `FakeMasterCopy`, `InvalidInitialization`, `InvalidThreshold`, `InvalidOwnersCount`, `OwnerIsNotABeneficiary`, `InvalidFallbackManager`
- Public state: `masterCopy`, `walletFactory`, `token`, `beneficiaries`, `wallets`
- `function addBeneficiary(address beneficiary) external onlyOwner`
- `function proxyCreated(GnosisSafeProxy proxy, address singleton, bytes calldata initializer, uint256) external override`

### `TokenApprove` (`contracts/backdoor/TokenApprove.sol`)
- Helper to `delegatecall` during Safe setup.
- `function approve(DamnValuableToken token, address to, uint256 amount) external`

Usage (test):
```solidity
await (await ethers.getContractFactory('BackdoorAttacker', player)).deploy(...);
```

---

## Climber (Timelock + UUPS upgrade)

### `ClimberTimelockBase` (`contracts/climber/ClimberTimelockBase.sol`)
- Types: `OperationState`, `Operation`
- `function getOperationState(bytes32 id) public view returns (OperationState)`
- `function getOperationId(address[] calldata targets, uint256[] calldata values, bytes[] calldata dataElements, bytes32 salt) public pure returns (bytes32)`
- `receive() external payable`

### `ClimberTimelock` (`contracts/climber/ClimberTimelock.sol`)
- Roles: `ADMIN_ROLE`, `PROPOSER_ROLE`
- Errors: `InvalidTargetsCount`, `InvalidDataElementsCount`, `InvalidValuesCount`, `OperationAlreadyKnown`, `NotReadyForExecution`, `CallerNotTimelock`, `NewDelayAboveMax`
- `function schedule(address[] calldata targets, uint256[] calldata values, bytes[] calldata dataElements, bytes32 salt) external onlyRole(PROPOSER_ROLE)`
- `function execute(address[] calldata targets, uint256[] calldata values, bytes[] calldata dataElements, bytes32 salt) external payable`
- `function updateDelay(uint64 newDelay) external`

### `ClimberVault` (`contracts/climber/ClimberVault.sol`)
- UUPS upgradeable vault with sweeper + withdrawal throttling.
- Errors: `CallerNotSweeper`, `InvalidWithdrawalAmount`, `InvalidWithdrawalTime`
- `function initialize(address admin, address proposer, address sweeper) external initializer`
- `function withdraw(address token, address recipient, uint256 amount) external onlyOwner`
- `function sweepFunds(address token) external onlySweeper`
- `function getSweeper() external view returns (address)`
- `function getLastWithdrawalTimestamp() external view returns (uint256)`

Usage: see `climber.challenge.js` for executing a scheduled batch and upgrading.

---

## ABI Smuggling (Call gate + self-authorized vault)

### `AuthorizedExecutor` (`contracts/abi-smuggling/AuthorizedExecutor.sol`)
- Events: `Initialized(address who, bytes32[] ids)`
- Errors: `NotAllowed`, `AlreadyInitialized`
- Public state: `bool public initialized; mapping(bytes32 => bool) public permissions;`
- `function setPermissions(bytes32[] memory ids) external`
- `function execute(address target, bytes calldata actionData) external nonReentrant returns (bytes memory)`
- `function getActionId(bytes4 selector, address executor, address target) public pure returns (bytes32)`

### `SelfAuthorizedVault` (`contracts/abi-smuggling/SelfAuthorizedVault.sol`)
- Errors: `TargetNotAllowed`, `CallerNotAllowed`, `InvalidWithdrawalAmount`, `WithdrawalWaitingPeriodNotEnded`
- Constants: `WITHDRAWAL_LIMIT`, `WAITING_PERIOD`
- `function withdraw(address token, address recipient, uint256 amount) external onlyThis`
- `function sweepFunds(address receiver, IERC20 token) external onlyThis`
- `function getLastWithdrawalTimestamp() external view returns (uint256)`

Usage (test): see the custom calldata construction in `abi-smuggling.challenge.js` to bypass the target gate.

---

## Wallet Mining (Gnosis Safe miner + authorizer)

### `AuthorizerUpgradeable` (`contracts/wallet-mining/AuthorizerUpgradeable.sol`)
- UUPS upgradeable authorizer with owner-managed upgrades.
- Events: `Rely(address usr, address aim)`
- `function init(address[] memory _wards, address[] memory _aims) external initializer`
- `function can(address usr, address aim) external view returns (bool)`
- `function upgradeToAndCall(address imp, bytes memory wat) external payable override`

### `SelfDestruct` (`contracts/wallet-mining/SelfDestruct.sol`)
- UUPS upgradeable implementation with a `selfdestruct` entrypoint.
- `function terminate(address receiver) external payable`

### `WalletDeployer` (`contracts/wallet-mining/WalletDeployer.sol`)
- Rewards Safe deployers; optional external authorizer gate.
- Errors: `Boom()`
- Public state: `fact`, `copy`, `pay`, `chief`, `gem`, `mom`
- `function rule(address _mom) external` — set authorizer once; only `chief`.
- `function drop(bytes memory wat) external returns (address aim)` — deploy Safe proxy and pay caller; requires authorization if `mom` set.
- `function can(address u, address a) public view returns (bool)` — forwards to `mom` via staticcall.

Usage (test): see recreating Gnosis Safe factory/master copy and exploiting uninitialized UUPS.

---

## Attacker Utility Contracts

These are provided for the challenge solutions and serve as usage examples:
- `PuppetAttacker`, `PuppetV3Attacker`
- `SideEntranceAttacker`
- `SelfieAttacker`
- `TheRewardsAttacker`
- `BackdoorAttacker`
- `FreeRiderAttacker`
- `NaiveReceiverAttacker`
- `ClimberAttacker`
- `WalletMiningAttacker`

They expose straightforward entrypoints (e.g., `attack()`, `buyAllWeth()`, `flashLoan()`) used directly in the tests.

---

## Tips for Integration

- Approvals: lending pools often require pre-approving WETH or token.
- Time-dependent logic: some scenarios require increasing EVM time (e.g., rewards round, timelock delay).
- Access control: enforce roles/ownership when calling minting or upgrade functions.
- ERC3156: receivers must return the expected magic value.