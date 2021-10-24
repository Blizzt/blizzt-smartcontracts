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
const DAI = artifacts.require("./DAI.sol");
const USDT = artifacts.require("./USDT.sol");
const USDC = artifacts.require("./USDC.sol");
const BlizztFarm = artifacts.require("./BlizztFarm.sol");

async function doDeploy(deployer, network, accounts) {
    // Deploy the BlizztToken ERC20
    await deployer.deploy(BlizztToken);
    let blizztToken = await BlizztToken.deployed();
    console.log('BlizztToken deployed:', blizztToken.address);

    await deployer.deploy(BlizztFarm);
    let blizztFarm = await BlizztFarm.deployed();
    console.log('BlizztFarm deployed:', blizztFarm.address);

    // Deploy dummy contracts for testing
    await deployer.deploy(DAI);
    let daiToken = await DAI.deployed();
    console.log('DAI deployed:', daiToken.address);

    await deployer.deploy(USDT);
    let usdtToken = await USDT.deployed();
    console.log('USDT deployed:', usdtToken.address);

    await deployer.deploy(USDC);
    let usdcToken = await USDC.deployed();
    console.log('USDC deployed:', usdcToken.address);

    let dai = daiToken.address
    let usdt = usdtToken.address;
    let usdc = usdcToken.address;
    //let usdt = '0xdAC17F958D2ee523a2206206994597C13D831ec7';
    //let usdc = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48';
    let icoStartDate = 1634725518;
    let icoEndDate = 1734725518;
    let maxICOTokens = web3.utils.toWei('150000000');
    let priceICO = 10000;
    let uniswapRouter = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D';

    // Deploy the Blizzt ICO
    await deployer.deploy(BlizztICO,
        accounts[0],
        blizztToken.address,
        icoStartDate,
        icoEndDate,
        dai,
        usdt,
        usdc,
        maxICOTokens,
        priceICO,
        uniswapRouter);
    
    let blizztICO = await BlizztICO.deployed();
    console.log('BlizztICO deployed:', blizztICO.address);

    // Deploy the Stake contract
    await deployer.deploy(BlizztStake, blizztToken.address);
    let blizztStake = await BlizztStake.deployed();
    console.log('BlizztStake deployed:', blizztStake.address);

    // Deploy Blizzt relayer
    await deployer.deploy(BlizztRelayer);
    let blizztRelayer = await BlizztRelayer.deployed();
    console.log('BlizztRelayer deployed:', blizztRelayer.address);

    // Deploy the marketplace admin
    await deployer.deploy(NFTMarketplaceAdmin);
    let nftMarketplaceAdmin = await NFTMarketplaceAdmin.deployed();
    console.log('NFTMarketplaceAdmin deployed:', nftMarketplaceAdmin.address);

    // Deploy the marketplace proxy contract
    await deployer.deploy(NFTMarketplaceProxy);
    let nftMarketplaceProxy = await NFTMarketplaceProxy.deployed();
    console.log('NFTMarketplaceProxy deployed:', nftMarketplaceProxy.address);

    await nftMarketplaceAdmin.setProxy(nftMarketplaceProxy.address);

    // Deploy the marketplace contract
    await deployer.deploy(NFTMarketplace, blizztRelayer.address, blizztStake.address, accounts[1], nftMarketplaceAdmin.address, 100, 250, 1000000, 0, 0, 0);
    let nftMarketplace = await NFTMarketplace.deployed();
    console.log("NFT Marketplace deployed to:", nftMarketplace.address);

    await blizztStake.setMarketplace(nftMarketplace.address);

    await deployer.deploy(NFTCollection);
    let nftCollectionTemplate = await NFTCollection.deployed();
    console.log("NFTCollection Template deployed to:", nftCollectionTemplate.address);

    await deployer.deploy(NFTEvolveCollection);
    let nftEvolveMultiCollectionTemplate = await NFTEvolveCollection.deployed();
    console.log("NFTEvolveCollection Template deployed to:", nftEvolveMultiCollectionTemplate.address);

    await deployer.deploy(NFTCollectionFactory, nftCollectionTemplate.address, nftMarketplace.address, blizztStake.address, 0);
    let nftFactory = await NFTCollectionFactory.deployed();
    console.log("NFT Factory deployed to:", nftFactory.address);

    await deployer.deploy(NFTEvolveCollectionFactory, nftEvolveMultiCollectionTemplate.address, nftMarketplace.address, blizztStake.address, 0);
    let nftEvolveMultiFactory = await NFTEvolveCollectionFactory.deployed();
    console.log("NFTEvolveCollectionFactory deployed to:", nftEvolveMultiFactory.address);
}

module.exports = function(deployer, network, accounts) {
    deployer.then(async () => {
        await doDeploy(deployer, network, accounts);
    });
};