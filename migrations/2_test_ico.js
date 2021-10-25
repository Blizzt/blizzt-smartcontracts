const BlizztToken = artifacts.require("./BlizztToken.sol");
const BlizztICO = artifacts.require("./BlizztICO.sol");
const BlizztFarm = artifacts.require("./BlizztFarm.sol");
const USDTToken = artifacts.require("./USDTToken.sol");
const WETHToken = artifacts.require("./WETHToken.sol");
const WBTCToken = artifacts.require("./WBTCToken.sol");
const Uniswap = artifacts.require("./Uniswap.sol");

async function doDeploy(deployer, network, accounts) {

    let usdtToken = await USDTToken.deployed();
    console.log('USDTToken deployed:', usdtToken.address);

    let wethToken = await WETHToken.deployed();
    console.log('WETHToken deployed:', wethToken.address);

    let wbtcToken = await WBTCToken.deployed();
    console.log('WBTCToken deployed:', wbtcToken.address);

    let blizztToken = await BlizztToken.deployed();
    console.log('BlizztToken deployed:', blizztToken.address);

    let blizztFarm = await BlizztFarm.deployed();
    console.log('BlizztFarm deployed:', blizztFarm.address);

    let blizztICO = await BlizztICO.deployed();
    console.log('BlizztICO deployed:', blizztICO.address);

    let usdt = usdtToken.address;
    let wbtc = wbtcToken.address;

    // Create the uniswap test pools
    let uniswapRouter = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D';
    await deployer.deploy(Uniswap, uniswapRouter);
    let uniswap = await Uniswap.deployed();
    console.log('Uniswap deployed:', uniswap.address);

    await wbtcToken.approve(uniswap.address, web3.utils.toWei('10000000'));
    await uniswap.createPool(wbtc, { value: web3.utils.toWei('20') });
    await usdtToken.approve(uniswap.address, web3.utils.toWei('10000000'));
    await uniswap.createPool(usdt, { value: web3.utils.toWei('20') });
    console.log('Pools deployed');
    
    // Buy all the ICO
    await usdtToken.transfer(accounts[1], web3.utils.toWei('100000'));
    await wbtcToken.transfer(accounts[3], web3.utils.toWei('1'));

    await blizztToken.transfer(blizztICO.address, web3.utils.toWei('150000000'));

    try {
        await usdtToken.approve(blizztICO.address, web3.utils.toWei('100000'), {from: accounts[1]});
        await blizztICO.buy(web3.utils.toWei('6000'), usdt, {from: accounts[1]});
        console.log('TRANSFER 1 FINISHED');
    } catch(e) {
        console.log(e);
    }

    try {
        await blizztICO.buy(web3.utils.toWei('50'), '0x0000000000000000000000000000000000000000', {from: accounts[2], value: web3.utils.toWei('50')});
        console.log('TRANSFER 2 FINISHED');
    } catch(e) {
        console.log(e);
    }

    try {
        await wbtcToken.approve(blizztICO.address, web3.utils.toWei('1'), {from: accounts[3]});
        await blizztICO.buy(web3.utils.toWei('0.3'), wbtc, {from: accounts[3]});
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
    const balance2 = await web3.eth.getBalance(accounts[2]);
    console.log('BALANCE 2: ', web3.utils.fromWei(balance2));

    const tokens3 = await blizztICO.getUserBoughtTokens(accounts[3]);
    console.log('TOKENS BOUGHT3: ', web3.utils.fromWei(tokens3));
    const balance3 = await wbtcToken.balanceOf(accounts[3]);
    console.log('BALANCE 3: ', web3.utils.fromWei(balance3));

    // TODO. How to automatize this action?
    await blizztToken.transfer(blizztFarm.address, web3.utils.toWei('20000000'));
    const farmBalance = await blizztToken.balanceOf(blizztFarm.address);
    console.log('FARM BALANCE: ', web3.utils.fromWei(farmBalance));

    const x = await blizztICO.listTokenInUniswapAndStake();
    console.log(x.logs[0].args.maticOnUniswap.toString());
    console.log(x.logs[0].args.maticUSD.toString());
    console.log(x.logs[0].args.usdUniswapInMATICs.toString());
    console.log(x.logs[0].args.tokensOnUniswap.toString());
    console.log('TOKEN LISTED IN UNISWAP');

    const deposited1 = await blizztFarm.deposited(accounts[1]);
    console.log('DEPOSITED 1: ', web3.utils.fromWei(deposited1));
    const deposited2 = await blizztFarm.deposited(accounts[2]);
    console.log('DEPOSITED 2: ', web3.utils.fromWei(deposited2));
    const deposited3 = await blizztFarm.deposited(accounts[3]);
    console.log('DEPOSITED 3: ', web3.utils.fromWei(deposited3));


    const pending1 = await blizztFarm.pending(accounts[0]);
    console.log('PEDING REWARDS 1: ', web3.utils.fromWei(pending1));
    const pending2 = await blizztFarm.pending(accounts[1]);
    console.log('PEDING REWARDS 2: ', web3.utils.fromWei(pending2));
    const pending3 = await blizztFarm.pending(accounts[2]);
    console.log('PEDING REWARDS 3: ', web3.utils.fromWei(pending3));
}

module.exports = function(deployer, network, accounts) {
    deployer.then(async () => {
        await doDeploy(deployer, network, accounts);
    });
};