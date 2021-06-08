const BlizztToken = artifacts.require("./BlizztToken.sol");
const NFTCollectionFactory = artifacts.require("./NFTCollectionFactory.sol");
const NFTCollection = artifacts.require("./NFTCollection.sol");
const DummyUSDT = artifacts.require("./DummyUSDT.sol");
const NFTMarketplace = artifacts.require("./NFTMarketplace");
const BlizztStake = artifacts.require("./BlizztStake");

async function doDeploy(deployer, network, accounts) {
    let delay = 3;

    await deployer.deploy(DummyUSDT, web3.utils.toWei('200000000'));
    let dummyUSDT = await DummyUSDT.deployed();
    console.log('DummyUSDT deployed:', dummyUSDT.address);

    await deployer.deploy(BlizztToken);
    let blizztToken = await BlizztToken.deployed();
    console.log('BlizztToken deployed:', blizztToken.address);

    await deployer.deploy(BlizztStake, blizztToken.address);
    let blizztStake = await BlizztStake.deployed();
    console.log('blizztStake deployed:', blizztStake.address);

    await deployer.deploy(NFTMarketplace, blizztStake.address, accounts[1], 100, 250, 1000000);
    let nftMarketplace = await NFTMarketplace.deployed();
    console.log("NFT Marketplace deployed to:", nftMarketplace.address);

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