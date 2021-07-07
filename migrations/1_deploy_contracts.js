const BlizztToken = artifacts.require("./BlizztToken.sol");
const NFTCollectionFactory = artifacts.require("./NFTCollectionFactory.sol");
const NFTCollection = artifacts.require("./NFTCollection.sol");
const NFTMarketplace = artifacts.require("./NFTMarketplace");
const BlizztStake = artifacts.require("./BlizztStake");
const NFTMarketplaceAdmin = artifacts.require("./NFTMarketplaceAdmin");
const NFTMarketplaceProxy = artifacts.require("./NFTMarketplaceProxy");

async function doDeploy(deployer, network, accounts) {

    // Deploy the BlizztToken ERC20
    await deployer.deploy(BlizztToken);
    let blizztToken = await BlizztToken.deployed();
    console.log('BlizztToken deployed:', blizztToken.address);

    // Deploy the Stake contract
    await deployer.deploy(BlizztStake, blizztToken.address);
    let blizztStake = await BlizztStake.deployed();
    console.log('BlizztStake deployed:', blizztStake.address);

    await deployer.deploy(NFTMarketplaceAdmin);
    let nftMarketplaceAdmin = await NFTMarketplaceAdmin.deployed();
    console.log('NFTMarketplaceAdmin deployed:', nftMarketplaceAdmin.address);

    await deployer.deploy(NFTMarketplaceProxy);
    let nftMarketplaceProxy = await NFTMarketplaceProxy.deployed();
    console.log('NFTMarketplaceProxy deployed:', nftMarketplaceProxy.address);

    await nftMarketplaceAdmin.setProxy(nftMarketplaceProxy.address);

    await deployer.deploy(NFTMarketplace, blizztStake.address, accounts[1], nftMarketplaceAdmin.address, 100, 250, 1000000, 0, 0, 0);
    let nftMarketplace = await NFTMarketplace.deployed();
    console.log("NFT Marketplace deployed to:", nftMarketplace.address);

    await blizztStake.setMarketplace(nftMarketplace.address);

    await deployer.deploy(NFTCollection);
    let nftCollectionTemplate = await NFTCollection.deployed();
    console.log("NFTCollection Template deployed to:", nftCollectionTemplate.address);

    await deployer.deploy(NFTCollectionFactory, nftCollectionTemplate.address, nftMarketplace.address, blizztStake.address, 0);
    let nftFactory = await NFTCollectionFactory.deployed();
    console.log("NFT Factory deployed to:", nftFactory.address);
}

module.exports = function(deployer, network, accounts) {
    deployer.then(async () => {
        await doDeploy(deployer, network, accounts);
    });
};