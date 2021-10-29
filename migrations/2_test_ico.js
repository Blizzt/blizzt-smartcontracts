const BlizztToken = artifacts.require("./BlizztToken.sol");
const BlizztICO = artifacts.require("./BlizztICO.sol");
const BlizztFarm = artifacts.require("./BlizztFarm.sol");

async function doDeploy(deployer, network, accounts) {

    let blizztToken = await BlizztToken.deployed();
    console.log('BlizztToken deployed:', blizztToken.address);

    let blizztFarm = await BlizztFarm.deployed();
    console.log('BlizztFarm deployed:', blizztFarm.address);

    let blizztICO = await BlizztICO.deployed();
    console.log('BlizztICO deployed:', blizztICO.address);
   
    try {
        const balanceUser1Before = await web3.eth.getBalance(accounts[0]);
        console.log('USER 1 BALANCE BEFORE TRANSFER: ', web3.utils.fromWei(balanceUser1Before.toString(), 'ether'));
        await blizztICO.buy({from: accounts[0], value: web3.utils.toWei('2')});
        console.log('TRANSFER 1 FINISHED');
        const balanceUser1After = await web3.eth.getBalance(accounts[0]);
        console.log('USER 1 BALANCE AFTER TRANSFER: ', web3.utils.fromWei(balanceUser1After.toString(), 'ether'));
        const balanceUser2Before = await web3.eth.getBalance(accounts[1]);
        console.log('USER 2 BALANCE BEFORE TRANSFER: ', web3.utils.fromWei(balanceUser2Before.toString(), 'ether'));
        await blizztICO.buy({from: accounts[1], value: web3.utils.toWei('1')});
        console.log('TRANSFER 2 FINISHED');
        await blizztICO.buy({from: accounts[2], value: web3.utils.toWei('1')});
        console.log('TRANSFER 3 FINISHED');
    } catch(e) {
        console.log(e);
    }

    const tokens1 = await blizztICO.getUserBoughtTokens(accounts[0]);
    console.log('TOKENS BOUGHT1: ', web3.utils.fromWei(tokens1));
    const tokens2 = await blizztICO.getUserBoughtTokens(accounts[1]);
    console.log('TOKENS BOUGHT2: ', web3.utils.fromWei(tokens2));
    const tokens3 = await blizztICO.getUserBoughtTokens(accounts[2]);
    console.log('TOKENS BOUGHT3: ', web3.utils.fromWei(tokens3));

    const farmBalance = await blizztToken.balanceOf(blizztFarm.address);
    console.log('FARM BALANCE: ', web3.utils.fromWei(farmBalance));

    await blizztICO.listTokenInUniswapAndStake();
    console.log('TOKEN LISTED IN UNISWAP');

    const deposited1 = await blizztFarm.deposited(accounts[0]);
    console.log('DEPOSITED 1: ', web3.utils.fromWei(deposited1));
    const deposited2 = await blizztFarm.deposited(accounts[1]);
    console.log('DEPOSITED 2: ', web3.utils.fromWei(deposited2));
    const deposited3 = await blizztFarm.deposited(accounts[2]);
    console.log('DEPOSITED 3: ', web3.utils.fromWei(deposited3));


    const pending1 = await blizztFarm.pending(accounts[0]);
    console.log('PEDING REWARDS 1: ', web3.utils.fromWei(pending1));
    const pending2 = await blizztFarm.pending(accounts[1]);
    console.log('PEDING REWARDS 2: ', web3.utils.fromWei(pending2));
    const pending3 = await blizztFarm.pending(accounts[2]);
    console.log('PEDING REWARDS 3: ', web3.utils.fromWei(pending3));

    const contractBalance = await blizztToken.balanceOf(blizztICO.address);
    console.log('CONTRACT BALANCE: ', web3.utils.fromWei(contractBalance));
}

module.exports = function(deployer, network, accounts) {
    deployer.then(async () => {
        await doDeploy(deployer, network, accounts);
    });
};