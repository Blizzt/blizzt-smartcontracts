const BlizztToken = artifacts.require("./BlizztToken.sol");
const NFTCollectionFactory = artifacts.require("./NFTCollectionFactory.sol");
const NFTCollection = artifacts.require("./NFTCollection.sol");
const DummyUSDT = artifacts.require("./DummyUSDT.sol");
const NFTMarketplace = artifacts.require("./NFTMarketplace");
const BlizztStaking = artifacts.require("./BlizztStaking");

async function doDeploy(deployer, network, accounts) {
    let delay = 3;

    await deployer.deploy(DummyUSDT, web3.utils.toWei('200000000'));
    let dummyUSDT = await DummyUSDT.deployed();
    console.log('DummyUSDT deployed:', dummyUSDT.address);

    await deployer.deploy(BlizztToken);
    let blizztToken = await BlizztToken.deployed();
    console.log('BlizztToken deployed:', blizztToken.address);

    await deployer.deploy(BlizztStaking, blizztToken.address);
    let blizztStaking = await BlizztStaking.deployed();
    console.log('BlizztStaking deployed:', blizztStaking.address);

    await deployer.deploy(NFTMarketplace, blizztToken.address, [225, 200, 175, 150, 125, 100], [10000, 50000, 100000, 200000, 500000, 1000000]);
    let nftMarketplace = await NFTMarketplace.deployed();
    console.log("NFT Marketplace deployed to:", nftMarketplace.address);

    await deployer.deploy(NFTCollection);
    let nftCollectionTemplate = await NFTCollection.deployed();
    console.log("NFTCollection Template deployed to:", nftCollectionTemplate.address);

    await deployer.deploy(NFTCollectionFactory, nftCollectionTemplate.address, nftMarketplace.address, blizztToken.address, blizztStaking.address, 0);
    let nftFactory = await NFTCollectionFactory.deployed();
    console.log("NFT Factory deployed to:", nftFactory.address);
}

module.exports = function(deployer, network, accounts) {
    deployer.then(async () => {
        await doDeploy(deployer, network, accounts);
    });
};