const BlizztToken = artifacts.require("./BlizztToken.sol");
const BlizztICO = artifacts.require("./BlizztICO.sol");
const BlizztFarm = artifacts.require("./BlizztFarm.sol");
const USDTToken = artifacts.require("./USDTToken.sol");
const WETHToken = artifacts.require("./WETHToken.sol");
const WBTCToken = artifacts.require("./WBTCToken.sol");

async function doDeploy(deployer, network, accounts) {

    await deployer.deploy(USDTToken);
    let usdtToken = await USDTToken.deployed();
    console.log('USDTToken deployed:', usdtToken.address);

    await deployer.deploy(WETHToken);
    let wethToken = await WETHToken.deployed();
    console.log('WETHToken deployed:', wethToken.address);

    await deployer.deploy(WBTCToken);
    let wbtcToken = await WBTCToken.deployed();
    console.log('WBTCToken deployed:', wbtcToken.address);

    await deployer.deploy(BlizztToken);
    let blizztToken = await BlizztToken.deployed();
    console.log('BlizztToken deployed:', blizztToken.address);

    await deployer.deploy(BlizztFarm, blizztToken.address);
    let blizztFarm = await BlizztFarm.deployed();
    console.log('BlizztFarm deployed:', blizztFarm.address);

    let usdt = usdtToken.address;
    let weth = wethToken.address
    let wbtc = wbtcToken.address
    let icoStartDate = 1634725518;
    let icoEndDate = 1734725518;
    let maxICOTokens = web3.utils.toWei('150000000');
    let priceICO = 10000;   // Tokens per 1$
    let uniswapRouter = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D';
  
    // Deploy the Blizzt ICO
    await deployer.deploy(BlizztICO,
        accounts[0],
        blizztToken.address,
        blizztFarm.address,
        icoStartDate,
        icoEndDate,
        usdt,
        weth,
        wbtc,
        maxICOTokens,
        priceICO,
        uniswapRouter
    );
    
    let blizztICO = await BlizztICO.deployed();
    console.log('BlizztICO deployed:', blizztICO.address);

    await blizztFarm.transferOwnership(blizztICO.address);
    
    // Transfers all the tokens
    await blizztToken.transfer(blizztICO.address, web3.utils.toWei('150000000'));   
}

module.exports = function(deployer, network, accounts) {
    deployer.then(async () => {
        await doDeploy(deployer, network, accounts);
    });
};