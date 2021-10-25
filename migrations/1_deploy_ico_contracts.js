const BlizztToken = artifacts.require("./BlizztToken.sol");
const BlizztICO = artifacts.require("./BlizztICO.sol");
const BlizztFarm = artifacts.require("./BlizztFarm.sol");

async function doDeploy(deployer, network, accounts) {

    await deployer.deploy(BlizztToken);
    let blizztToken = await BlizztToken.deployed();
    console.log('BlizztToken deployed:', blizztToken.address);

    await deployer.deploy(BlizztFarm, blizztToken.address);
    let blizztFarm = await BlizztFarm.deployed();
    console.log('BlizztFarm deployed:', blizztFarm.address);

    let icoStartDate = 1634725518;
    let icoEndDate = 1734725518;
    let maxICOTokens = web3.utils.toWei('150000000');
    let priceICO = 150000;   // Tokens per 1$
    let uniswapRouter = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D';
  
    // Deploy the Blizzt ICO
    await deployer.deploy(BlizztICO,
        accounts[0],
        blizztToken.address,
        blizztFarm.address,
        icoStartDate,
        icoEndDate,
        maxICOTokens,
        priceICO,
        uniswapRouter
    );
    
    let blizztICO = await BlizztICO.deployed();
    console.log('BlizztICO deployed:', blizztICO.address);

    await blizztFarm.transferOwnership(blizztICO.address);
    
    // Transfer 150M tokens for the ICO
    await blizztToken.transfer(blizztICO.address, web3.utils.toWei('150000000'));
    // Transfer 50M tokens for the public sale (initial liquidity in Uniswap)
    await blizztToken.transfer(blizztICO.address, web3.utils.toWei('50000000'));
    // Transfer 15M tokens for extra farming rewards if 100% ICO was sold
    await blizztToken.transfer(blizztICO.address, web3.utils.toWei('15000000'));
}

module.exports = function(deployer, network, accounts) {
    deployer.then(async () => {
        await doDeploy(deployer, network, accounts);
    });
};