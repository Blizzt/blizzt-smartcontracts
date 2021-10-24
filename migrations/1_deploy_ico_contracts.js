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
    
    // Transfers all the tokens
    await blizztToken.transfer(blizztICO.address, web3.utils.toWei('150000000'));
   
    const wp = await blizztICO.getUSDTokenPrice(wbtc);
    console.log(web3.utils.fromWei(wp));

    // Buy all the ICO
    await usdtToken.transfer(accounts[1], web3.utils.toWei('100000'));
    await wbtcToken.transfer(accounts[2], web3.utils.toWei('100000'));
    await usdtToken.transfer(accounts[3], web3.utils.toWei('100000'));

    try {
        await usdtToken.approve(blizztICO.address, web3.utils.toWei('100000'), {from: accounts[1]});
        await blizztICO.buy(web3.utils.toWei('6000'), usdt, {from: accounts[1]});
        console.log('TRANSFER 1 FINISHED');
    } catch(e) {
        console.log(e);
    }

    try {
        await wbtcToken.approve(blizztICO.address, web3.utils.toWei('100000'), {from: accounts[2]});
        await blizztICO.buy(web3.utils.toWei('1'), wbtc, {from: accounts[2]});
        console.log('TRANSFER 2 FINISHED');
    } catch(e) {
        console.log(e);
    }

    try {
        await usdtToken.approve(blizztICO.address, web3.utils.toWei('10000'), {from: accounts[3]});
        await blizztICO.buy(web3.utils.toWei('6000'), usdt, {from: accounts[3]});
        console.log('TRANSFER 3 FINISHED');
    } catch(e) {
        console.log(e);
    }
    const tokens1 = await blizztICO.getUserBoughtTokens(accounts[1]);
    console.log('TOKENS BOUGHT1: ', web3.utils.fromWei(tokens1));
    const balance1 = await usdtToken.balanceOf(accounts[1]);
    console.log('BALANCE 1: ', web3.utils.fromWei(balance1));

    const tokens2 = await blizztICO.getUserBoughtTokens(accounts[2]);
    console.log('TOKENS BOUGHT2: ', web3.utils.fromWei(tokens2));
    const balance2 = await wbtcToken.balanceOf(accounts[2]);
    console.log('BALANCE 2: ', web3.utils.fromWei(balance2));

    const tokens3 = await blizztICO.getUserBoughtTokens(accounts[3]);
    console.log('TOKENS BOUGHT3: ', web3.utils.fromWei(tokens3));
    const balance3 = await usdtToken.balanceOf(accounts[3]);
    console.log('BALANCE 3: ', web3.utils.fromWei(balance3));

    await blizztToken.transfer(blizztICO.address, web3.utils.toWei('200000000'));
    const farmBalance = await blizztToken.balanceOf(blizztFarm.address);
    console.log('FARM BALANCE: ', web3.utils.fromWei(farmBalance));

    // Start the farm
}

module.exports = function(deployer, network, accounts) {
    deployer.then(async () => {
        await doDeploy(deployer, network, accounts);
    });
};