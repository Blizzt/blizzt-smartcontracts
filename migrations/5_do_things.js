const BlizztToken = artifacts.require("./BlizztToken.sol");
const NFTCollection = artifacts.require("./NFTCollection.sol");
const NFTEvolveCollection = artifacts.require("./NFTEvolveCollection.sol");
const NFTMarketplace = artifacts.require("./NFTMarketplace");
const BlizztStake = artifacts.require("./BlizztStake");
const NFTMarketplaceAdmin = artifacts.require("./NFTMarketplaceAdmin");
const NFTMarketplaceProxy = artifacts.require("./NFTMarketplaceProxy");
const NFTCollectionFactory = artifacts.require("./NFTCollectionFactory.sol");
const NFTEvolveCollectionFactory = artifacts.require("./NFTEvolveCollectionFactory.sol");
const BlizztRelayer = artifacts.require("./BlizztRelayer.sol");
const BlizztICO = artifacts.require("./BlizztICO.sol");
const VestingContract = artifacts.require("./VestingContract.sol");
const DAI = artifacts.require("./DAI.sol");
const USDT = artifacts.require("./USDT.sol");
const USDC = artifacts.require("./USDC.sol");

async function doDeploy(deployer, network, accounts) {

    // Deploy the BlizztToken ERC20
    let blizztToken = await BlizztToken.deployed();
    console.log('BlizztToken deployed:', blizztToken.address);

    // Deploy the Vesting Contract
    let vestingContract = await VestingContract.deployed();
    console.log('VestingContract deployed:', vestingContract.address);

    // Deploy dummy contracts for testing
    let daiToken = await DAI.deployed();
    console.log('DAI deployed:', daiToken.address);

    let usdtToken = await USDT.deployed();
    console.log('USDT deployed:', usdtToken.address);

    let usdcToken = await USDC.deployed();
    console.log('USDC deployed:', usdcToken.address);

    let dai = daiToken.address
    let usdt = usdtToken.address;
    let usdc = usdcToken.address;
    
    let blizztICO = await BlizztICO.deployed();
    console.log('BlizztICO deployed:', blizztICO.address);

    await daiToken.transfer(accounts[1], web3.utils.toWei('100000'));
    await usdtToken.transfer(accounts[2], web3.utils.toWei('100000'));
    await usdcToken.transfer(accounts[3], web3.utils.toWei('100000'));

    try {
        await daiToken.approve(blizztICO.address, web3.utils.toWei('6000'), {from: accounts[1]});
        const txICO = await blizztICO.buy(web3.utils.toWei('6000'), dai, {from: accounts[1]});
        console.log(txICO.logs[0].args.usdETH.toString());
        console.log(txICO.logs[0].args.paidUSD.toString());
        console.log(txICO.logs[0].args.paidTokens.toString());
        console.log(txICO.logs[0].args.availableTokens.toString());
        console.log(txICO.logs[0].args.lastTokens);
        console.log(txICO.logs[0].args.amountToPay.toString());
    } catch(e) {
        console.log(e);
    }

    try {
        await usdtToken.approve(blizztICO.address, web3.utils.toWei('6000'), {from: accounts[2]});
        const txICO2 = await blizztICO.buy(web3.utils.toWei('6000'), usdt, {from: accounts[2]});
        console.log(txICO2.logs[0].args.usdETH.toString());
        console.log(txICO2.logs[0].args.paidUSD.toString());
        console.log(txICO2.logs[0].args.paidTokens.toString());
        console.log(txICO2.logs[0].args.availableTokens.toString());
        console.log(txICO2.logs[0].args.lastTokens);
        console.log(txICO2.logs[0].args.amountToPay.toString());
    } catch(e) {
        console.log(e);
    }

    try {
        await usdcToken.approve(blizztICO.address, web3.utils.toWei('6000'), {from: accounts[3]});
        const txICO3 = await blizztICO.buy(web3.utils.toWei('6000'), usdc, {from: accounts[3]});
        console.log(txICO3.logs[0].args.usdETH.toString());
        console.log(txICO3.logs[0].args.paidUSD.toString());
        console.log(txICO3.logs[0].args.paidTokens.toString());
        console.log(txICO3.logs[0].args.availableTokens.toString());
        console.log(txICO3.logs[0].args.lastTokens);
        console.log(txICO3.logs[0].args.amountToPay.toString());
    } catch(e) {
        console.log(e);
    }
    const tokens1 = await blizztICO.getUserBoughtTokens(accounts[1]);
    console.log('TOKENS BOUGHT1: ', web3.utils.fromWei(tokens1));
    const balance1 = await daiToken.balanceOf(accounts[1]);
    console.log('BALANCE 1: ', web3.utils.fromWei(balance1));

    const tokens2 = await blizztICO.getUserBoughtTokens(accounts[2]);
    console.log('TOKENS BOUGHT2: ', web3.utils.fromWei(tokens2));
    const balance2 = await usdtToken.balanceOf(accounts[2]);
    console.log('BALANCE 2: ', web3.utils.fromWei(balance2));

    const tokens3 = await blizztICO.getUserBoughtTokens(accounts[3]);
    console.log('TOKENS BOUGHT3: ', web3.utils.fromWei(tokens3));
    const balance3 = await usdcToken.balanceOf(accounts[3]);
    console.log('BALANCE 3: ', web3.utils.fromWei(balance3));

    await blizztToken.transfer(blizztICO.address, web3.utils.toWei('200000000'));

    console.log('UNISWAP LISTING');
    const txUniswap = await blizztICO.listTokenInUniswapAndStake();
    console.log(txUniswap.logs);

    // Deploy the Stake contract
    let blizztStake = await BlizztStake.deployed();
    console.log('BlizztStake deployed:', blizztStake.address);

    // Deploy Blizzt relayer
    let blizztRelayer = await BlizztRelayer.deployed();
    console.log('BlizztRelayer deployed:', blizztRelayer.address);

    // Deploy the marketplace admin
    let nftMarketplaceAdmin = await NFTMarketplaceAdmin.deployed();
    console.log('NFTMarketplaceAdmin deployed:', nftMarketplaceAdmin.address);

    // Deploy the marketplace proxy contract
    let nftMarketplaceProxy = await NFTMarketplaceProxy.deployed();
    console.log('NFTMarketplaceProxy deployed:', nftMarketplaceProxy.address);

    // Deploy the marketplace contract
    let nftMarketplace = await NFTMarketplace.deployed();
    console.log("NFT Marketplace deployed to:", nftMarketplace.address);

    let nftCollectionTemplate = await NFTCollection.deployed();
    console.log("NFTCollection Template deployed to:", nftCollectionTemplate.address);

    let nftEvolveMultiCollectionTemplate = await NFTEvolveCollection.deployed();
    console.log("NFTEvolveCollection Template deployed to:", nftEvolveMultiCollectionTemplate.address);

    let nftFactory = await NFTCollectionFactory.deployed();
    console.log("NFT Factory deployed to:", nftFactory.address);

    let nftEvolveMultiFactory = await NFTEvolveCollectionFactory.deployed();
    console.log("NFTEvolveCollectionFactory deployed to:", nftEvolveMultiFactory.address);
}

module.exports = function(deployer, network, accounts) {
    deployer.then(async () => {
        await doDeploy(deployer, network, accounts);
    });
};