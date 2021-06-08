const DummyUSDT = artifacts.require("./DummyUSDT.sol");
const DummyDAI = artifacts.require("./DummyDAI.sol");

async function doDeploy(deployer, network, accounts) {

    await deployer.deploy(DummyUSDT, web3.utils.toWei('20000000000'));
    let dummyUSDT = await DummyUSDT.deployed();
    console.log('DummyUSDT deployed:', dummyUSDT.address);

    await deployer.deploy(DummyDAI, web3.utils.toWei('20000000000'));
    let dummyDAI = await DummyDAI.deployed();
    console.log('DummyDAI deployed:', dummyDAI.address);
}

module.exports = function(deployer, network, accounts) {
    deployer.then(async () => {
        await doDeploy(deployer, network, accounts);
    });
};