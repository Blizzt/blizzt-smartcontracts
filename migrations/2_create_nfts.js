const NFTCollectionFactory = artifacts.require("./NFTCollectionFactory.sol");
const NFTCollection = artifacts.require("./NFTCollection.sol");
const NFTMarketplace = artifacts.require("./NFTMarketplace");
const DummyUSDT = artifacts.require("./DummyUSDT");

async function doDeploy(deployer, network, accounts) {
    let eta = Math.floor(Date.now() / 1000) + 10;
    let expirationDate = Math.floor(Date.now() / 1000) + 86400;
    let nftMarketplace = await NFTMarketplace.deployed();
    let nftFactory = await NFTCollectionFactory.deployed();
    console.log("NFT Factory deployed to:", nftFactory.address);

    let dummyUSDT = await DummyUSDT.deployed();

    let tx2 = await nftFactory.createNFTCollectionWithFirstItem("ipfs://", 10, 15, "QmaozNR7DZHQK1ZcU9p7QdrshMvXqWK6gpu5rmrkPdT3L4");
    console.log(tx2.logs[0].args.tokenAddress);

    //let sellParams = web3.eth.abi.encodeParameters(['address','uint256','uint24','uint256','address','bool','uint256'], [tx2.logs[0].args.tokenAddress, 1, 10, web3.utils.toWei('1000'), dummyUSDT.address, false, 123456789]);
    //let signature = await web3.eth.accounts.sign(sellParams, '12305200869b442bc4de1c126328b1cb2b6b275b32ad474bd7a1b0d3f24418b3');

    //console.log('sell', sellParams);
    //console.log('signature', signature);

    // Qmb4atcgbbN5v4CDJ8nz5QG5L2pgwSTLd3raDrnyhLjnUH
    // QmaozNR7DZHQK1ZcU9p7QdrshMvXqWK6gpu5rmrkPdT3L4

    let tx = await nftFactory.createNFTCollection("ipfs://");
    console.log("Gas consumed create NFT: ", tx.receipt.gasUsed);
    let tokenAddress = tx.logs[0].args.tokenAddress;
    let token = await NFTCollection.at(tokenAddress);
    console.log('Nueva colección NFT creada: ', tokenAddress);
    let mintCost = await token.mint(accounts[0], 1, 40, "Qmb4atcgbbN5v4CDJ8nz5QG5L2pgwSTLd3raDrnyhLjnUH");
    console.log("Gas consumed minting a new NFT: ", mintCost.receipt.gasUsed);
    mintCost = await token.mint(accounts[0], 2, 20, "QmaozNR7DZHQK1ZcU9p7QdrshMvXqWK6gpu5rmrkPdT3L4");
    console.log("Gas consumed minting a new NFT: ", mintCost.receipt.gasUsed);
    mintCost = await token.mint(accounts[0], 3, 5, "Qmb4atcgbbN5v4CDJ8nz5QG5L2pgwSTLd3raDrnyhLjnUH");
    console.log("Gas consumed minting a new NFT: ", mintCost.receipt.gasUsed);
    let balance1 = await token.balanceOf(accounts[0], 1);
    console.log('BALANCE ID 1 ACCOUNT 0 SHOULD BE 10 --> ', balance1.toString());
    await token.safeTransferFrom(accounts[0], accounts[1], 1, 2, "0x00");
    let balance2 = await token.balanceOf(accounts[1], 1);
    console.log('BALANCE ID 1 ACCOUNT 1 SHOULD BE 2 ---> ', balance2.toString());
    await token.safeTransferFrom(accounts[0], accounts[1], 1, 2, "0x00");
    await token.safeTransferFrom(accounts[0], accounts[2], 1, 3, "0x00");
    await token.safeTransferFrom(accounts[0], accounts[1], 2, 4, "0x00");
    await token.safeTransferFrom(accounts[0], accounts[2], 2, 5, "0x00");
    
    await dummyUSDT.transfer(accounts[2], web3.utils.toWei('100000'));
    await dummyUSDT.transfer(accounts[3], web3.utils.toWei('100000'));
    await dummyUSDT.approve(nftMarketplace.address, web3.utils.toWei('20000'), {from: accounts[2]});
    await dummyUSDT.approve(nftMarketplace.address, web3.utils.toWei('20000'), {from: accounts[3]});

    balance1 = await token.balanceOf(accounts[3], 10);
    console.log('ACCOUNT3, Balance item 10 --> ', balance1.toString());

    let mintParams = web3.eth.abi.encodeParameters(['address','uint256','uint24','uint256','address','string','uint256'], [token.address, 10, 5, web3.utils.toWei('1'), dummyUSDT.address, "QmaozNR7DZHQK1ZcU9p7QdrshMvXqWK6gpu5rmrkPdT3L4", expirationDate]);
    let signature = await web3.eth.accounts.sign(mintParams, '12305200869b442bc4de1c126328b1cb2b6b275b32ad474bd7a1b0d3f24418b3');
    let mintLen = (mintParams.length / 2) - 1;
    let mintParamsLen = web3.utils.asciiToHex(mintLen.toString());

    let minting = await nftMarketplace.mintERC1155(mintParams, mintParamsLen, signature.signature, { from: accounts[3] });
    console.log("Gas consumed minting gasless a new NFT: ", minting.receipt.gasUsed);
    balance1 = await token.balanceOf(accounts[3], 10);
    console.log('ACCOUNT3, Balance item 10 --> ', balance1.toString());

    //let signParams = web3.eth.abi.encodeParameters(['address','uint256[]','uint256[]','uint256','address'], [token.address, [1,2,3], [4,5,2], web3.utils.toWei('1'), dummyUSDT.address]);
    let signParams = web3.eth.abi.encodeParameters(['address','uint256','uint256','uint256','address','uint256'], [token.address, 1, 4, web3.utils.toWei('1'), dummyUSDT.address, expirationDate]);
    signature = await web3.eth.accounts.sign(signParams, '12305200869b442bc4de1c126328b1cb2b6b275b32ad474bd7a1b0d3f24418b3');

    balance1 = await token.balanceOf(accounts[0], 1);
    balance2 = await token.balanceOf(accounts[0], 2);
    let balance3 = await token.balanceOf(accounts[0], 3);
    console.log('BALANCE ID 1 ACCOUNT 0 BEFORE RENT --> ', balance1.toString());
    console.log('BALANCE ID 2 ACCOUNT 0 BEFORE RENT --> ', balance2.toString());
    console.log('BALANCE ID 3 ACCOUNT 0 BEFORE RENT --> ', balance3.toString());
    balance1 = await token.balanceOf(accounts[2], 1);
    console.log('BALANCE ID 1 ACCOUNT 2 BEFORE RENT --> ', balance1.toString());

    let len = (signParams.length / 2) - 1;
    let paramsLen = web3.utils.asciiToHex(len.toString());
    console.log('len5', paramsLen);

    //let renting = await nftMarketplace.rentMultipleERC1155(signParams, paramsLen, 5, signature, { from: accounts[2] });
    let renting = await nftMarketplace.rentERC1155(signParams, paramsLen, 1, 5, signature.signature, { from: accounts[2] });
    console.log('gas consumed renting: ', renting.receipt.gasUsed);

    balance1 = await token.balanceOf(accounts[0], 1);
    balance2 = await token.balanceOf(accounts[0], 2);
    balance3 = await token.balanceOf(accounts[0], 3);
    console.log('BALANCE ID 1 ACCOUNT 0 AFTER RENT --> ', balance1.toString());
    console.log('BALANCE ID 2 ACCOUNT 0 AFTER RENT --> ', balance2.toString());
    console.log('BALANCE ID 3 ACCOUNT 0 AFTER RENT --> ', balance3.toString());
    balance1 = await token.balanceOf(accounts[2], 1);
    console.log('BALANCE ID 1 ACCOUNT 2 AFTER RENT --> ', balance1.toString());

    console.log('WAITING FOR 6 SECONDS');
    await new Promise(r => setTimeout(r, 6 * 1000));

    let recover = await nftMarketplace.returnRentedERC1155(token.address, [1], [1], accounts[0], accounts[2]);
    console.log('gas consumed recovering: ', recover.receipt.gasUsed);

    balance1 = await token.balanceOf(accounts[0], 1);
    balance2 = await token.balanceOf(accounts[0], 2);
    balance3 = await token.balanceOf(accounts[0], 3);
    console.log('BALANCE ID 1 ACCOUNT 0 AFTER RECOVER --> ', balance1.toString());
    console.log('BALANCE ID 2 ACCOUNT 0 AFTER RECOVER --> ', balance2.toString());
    console.log('BALANCE ID 3 ACCOUNT 0 AFTER RECOVER --> ', balance3.toString());
    balance1 = await token.balanceOf(accounts[2], 1);
    console.log('BALANCE ID 1 ACCOUNT 2 AFTER RECOVER --> ', balance1.toString());

    let metadatas = await token.uris([1,2,3]);
    console.log(metadatas);

    //recover = await nftMarketplace.returnRentedERC1155(token.address, [1], [4], accounts[0]);
    //console.log('gas consumed recovering: ', recover.receipt.gasUsed);
/*
    let messageSellSign = "SELL. " + token.address.toLowerCase() + ". tokenId: 1. amount: 4. price: " + web3.utils.toWei('1') + ". erc20payment: " + dummyUSDT.address.toLowerCase() + ". nonce: 0. packed: 1";
    console.log('MESSAGE SM:', messageSellSign);
    let messageSell = await nftMarketplace.prepareMessageForSellERC1155(token.address, 1, 4, web3.utils.toWei('1'), dummyUSDT.address, 0, true);
    console.log('SM MESSAGE:', messageSell.toString());

    let sig = await web3.eth.accounts.sign(messageSell, '12305200869b442bc4de1c126328b1cb2b6b275b32ad474bd7a1b0d3f24418b3').signature;
    console.log('SIGNATURE: ', sig);

    balance1 = await token.balanceOf(accounts[0], 1);
    console.log('BALANCE ID 1 ACCOUNT 0 BEFORE SELLING --> ', balance1.toString());
    balance2 = await token.balanceOf(accounts[2], 1);
    console.log('BALANCE ID 1 ACCOUNT 2 BEFORE SELLING --> ', balance2.toString());
    await nftMarketplace.sellERC1155(token.address, 1, 4, web3.utils.toWei('1'), dummyUSDT.address, 0, true, 4, sig, { from: accounts[2] });
    balance1 = await token.balanceOf(accounts[0], 1);
    console.log('BALANCE ID 1 ACCOUNT 0 AFTER SELLING --> ', balance1.toString());
    balance2 = await token.balanceOf(accounts[2], 1);
    console.log('BALANCE ID 1 ACCOUNT 2 AFTER SELLING --> ', balance2.toString());
    
    let messageSwapSign = "SWAP. from: " + token.address.toLowerCase() + ". tokenId: 2. amount: 2. to: " + token.address.toLowerCase() + ". tokenId: 1. amount: 1. nonce: 0";
    console.log('MESSAGE SM:', messageSwapSign);
    let messageSwap = await nftMarketplace.prepareMessageForSwapERC1155(token.address, 2, 2, token.address, 1, 1, 0);
    console.log('SM MESSAGE:', messageSwap.toString());

    balance1 = await token.balanceOf(accounts[0], 2);
    console.log('BALANCE ID 2 ACCOUNT 0 BEFORE SWAP --> ', balance1.toString());
    balance2 = await token.balanceOf(accounts[2], 1);
    console.log('BALANCE ID 1 ACCOUNT 2 BEFORE SWAP --> ', balance2.toString());

    let xx = await web3.eth.accounts.sign(messageSwap, '12305200869b442bc4de1c126328b1cb2b6b275b32ad474bd7a1b0d3f24418b3').signature;
    console.log('SIGNATURE: ', xx);
    let owner1 = await nftMarketplace.getOwnerOfSwap(token.address, 2, 2, token.address, 1, 1, 0, xx);
    console.log('SWAP OWNER: ', owner1.toString());
    let res = await nftMarketplace.swapERC1155(token.address, 2, 2, token.address, 1, 1, 0, xx, { from: accounts[2] });
    console.log('RES SWAP', res);
*/
}

module.exports = function(deployer, network, accounts) {
    deployer.then(async () => {
        await doDeploy(deployer, network, accounts);
    });
};