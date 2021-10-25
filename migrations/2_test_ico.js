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
        await blizztICO.buy({from: accounts[1], value: web3.utils.toWei('80')});
        console.log('TRANSFER 1 FINISHED');
        await blizztICO.buy({from: accounts[2], value: web3.utils.toWei('80')});
        console.log('TRANSFER 2 FINISHED');
        await blizztICO.buy({from: accounts[3], value: web3.utils.toWei('80')});
        console.log('TRANSFER 3 FINISHED');
        await blizztICO.buy({from: accounts[4], value: web3.utils.toWei('80')});
        console.log('TRANSFER 4 FINISHED');
        await blizztICO.buy({from: accounts[5], value: web3.utils.toWei('80')});
        console.log('TRANSFER 5 FINISHED');
        await blizztICO.buy({from: accounts[6], value: web3.utils.toWei('80')});
        console.log('TRANSFER 6 FINISHED');
        await blizztICO.buy({from: accounts[7], value: web3.utils.toWei('80')});
        console.log('TRANSFER 7 FINISHED');
        await blizztICO.buy({from: accounts[8], value: web3.utils.toWei('80')});
        console.log('TRANSFER 8 FINISHED');
        await blizztICO.buy({from: accounts[9], value: web3.utils.toWei('80')});
        console.log('TRANSFER 9 FINISHED');

    } catch(e) {
        console.log(e);
    }

    const tokens1 = await blizztICO.getUserBoughtTokens(accounts[1]);
    console.log('TOKENS BOUGHT1: ', web3.utils.fromWei(tokens1));
    const tokens2 = await blizztICO.getUserBoughtTokens(accounts[2]);
    console.log('TOKENS BOUGHT2: ', web3.utils.fromWei(tokens2));
    const tokens3 = await blizztICO.getUserBoughtTokens(accounts[3]);
    console.log('TOKENS BOUGHT3: ', web3.utils.fromWei(tokens3));
    const tokens4 = await blizztICO.getUserBoughtTokens(accounts[4]);
    console.log('TOKENS BOUGHT4: ', web3.utils.fromWei(tokens4));
    const tokens5 = await blizztICO.getUserBoughtTokens(accounts[5]);
    console.log('TOKENS BOUGHT5: ', web3.utils.fromWei(tokens5));
    const tokens6 = await blizztICO.getUserBoughtTokens(accounts[6]);
    console.log('TOKENS BOUGHT6: ', web3.utils.fromWei(tokens6));
    const tokens7 = await blizztICO.getUserBoughtTokens(accounts[7]);
    console.log('TOKENS BOUGHT7: ', web3.utils.fromWei(tokens7));
    const tokens8 = await blizztICO.getUserBoughtTokens(accounts[8]);
    console.log('TOKENS BOUGHT8: ', web3.utils.fromWei(tokens8));
    const tokens9 = await blizztICO.getUserBoughtTokens(accounts[9]);
    console.log('TOKENS BOUGHT9: ', web3.utils.fromWei(tokens9));


    // TODO. How to automatize this action?
    await blizztToken.transfer(blizztFarm.address, web3.utils.toWei('20000000'));
    const farmBalance = await blizztToken.balanceOf(blizztFarm.address);
    console.log('FARM BALANCE: ', web3.utils.fromWei(farmBalance));

    const x = await blizztICO.listTokenInUniswapAndStake();
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

    const contractBalance = await blizztToken.balanceOf(blizztICO.address);
    console.log('CONTRACT BALANCE: ', web3.utils.fromWei(contractBalance));
}

module.exports = function(deployer, network, accounts) {
    deployer.then(async () => {
        await doDeploy(deployer, network, accounts);
    });
};