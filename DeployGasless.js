const NFTCollectionFactory = artifacts.require("./NFTCollectionFactory.sol");
const NFTCollection = artifacts.require("./NFTCollection.sol");
const DummyUSDT = artifacts.require("./DummyUSDT.sol");
const NFTMarketplace = artifacts.require("./NFTMarketplace.sol");

async function doDeploy(deployer, network, accounts) {
    let mintAbi = {
        'inputs': [
          {
            'internalType': 'address',
            'name': '_erc1155',
            'type': 'address'
          },
          {
            'internalType': 'uint256',
            'name': '_tokenId',
            'type': 'uint256'
          },
          {
            'internalType': 'uint24',
            'name': '_amount',
            'type': 'uint24'
          },
          {
            'internalType': 'uint256',
            'name': '_price',
            'type': 'uint256'
          },
          {
            'internalType': 'address',
            'name': '_erc20payment',
            'type': 'address'
          },
          {
            'internalType': 'string',
            'name': '_metadata',
            'type': 'string'
          },
          {
            'internalType': 'uint256',
            'name': 'expirationDate',
            'type': 'uint256'
          }
        ],
        'name': '_mintERC1155',
        'outputs': [],
        'stateMutability': 'payable',
        'type': 'function',
        'payable': true
      };
    
    let rentAbi = {
        'inputs': [
            {
            'internalType': 'address',
            'name': '_erc1155',
            'type': 'address'
            },
            {
            'internalType': 'uint256',
            'name': '_tokenId',
            'type': 'uint256'
            },
            {
            'internalType': 'uint24',
            'name': '_amount',
            'type': 'uint24'
            },
            {
            'internalType': 'uint256',
            'name': '_price',
            'type': 'uint256'
            },
            {
            'internalType': 'address',
            'name': '_erc20payment',
            'type': 'address'
            },
            {
            'internalType': 'uint256',
            'name': '_expirationDate',
            'type': 'uint256'
            }
        ],
        'name': '_rentERC1155',
        'outputs': [],
        'stateMutability': 'payable',
        'type': 'function',
        'payable': true
    }

    let eta = Math.floor(Date.now() / 1000) + 10;
    let expirationDate = Math.floor(Date.now() / 1000) + 86400;

    let dummyUSDT = await DummyUSDT.deployed();
    let nftMarketplace = await NFTMarketplace.deployed();
    let nftFactory = await NFTCollectionFactory.deployed();
    console.log("NFT Factory deployed to:", nftFactory.address);

    // Qmb4atcgbbN5v4CDJ8nz5QG5L2pgwSTLd3raDrnyhLjnUH
    // QmaozNR7DZHQK1ZcU9p7QdrshMvXqWK6gpu5rmrkPdT3L4

    let tx = await nftFactory.createNFTRentToken("https://api.divance.com/erc1155/");
    console.log("Gas consumed create NFT: ", tx.receipt.gasUsed);
    let tokenAddress = tx.logs[0].args.tokenAddress;
    let token = await NFTCollection.at(tokenAddress);
    console.log('Nueva colección NFT creada: ', tokenAddress);
    let mintCost = await token.mint(accounts[0], 1, 40, "Qmb4atcgbbN5v4CDJ8nz5QG5L2pgwSTLd3raDrnyhLjnUH");
    console.log("Gas consumed minting a new NFT: ", mintCost.receipt.gasUsed);
    mintCost = await token.mint(accounts[0], 2, 20, "Qmb4atcgbbN5v4CDJ8nz5QG5L2pgwSTLd3raDrnyhLjnUH");
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


    let mintParams = web3.eth.abi.encodeFunctionCall(mintAbi, [token.address, 10, 5, web3.utils.toWei('1'), dummyUSDT.address, "QmaozNR7DZHQK1ZcU9p7QdrshMvXqWK6gpu5rmrkPdT3L4", expirationDate]);
    let signature = await web3.eth.accounts.sign(mintParams, 'c1086153296cee41b779a7bad9118b82511665392dc0520f37ecf347801360ba');
    let len = (mintParams.length / 2) - 1;
    let paramsLen = web3.utils.asciiToHex(len.toString());
    let minting = await nftMarketplace.metaTxMintERC1155(mintParams, paramsLen, signature.signature, { from: accounts[3] });
    console.log("Gas consumed minting gasless a new NFT: ", minting.receipt.gasUsed);
    balance1 = await token.balanceOf(accounts[3], 10);
    console.log('ACCOUNT3, Balance item 10 --> ', balance1.toString());

    //let signParams = web3.eth.abi.encodeParameters(['address','uint256[]','uint256[]','uint256','address'], [token.address, [1,2,3], [4,5,2], web3.utils.toWei('1'), dummyUSDT.address]);
    //let signParams = web3.eth.abi.encodeParameters(['address','uint256','uint256','uint256','address','uint256'], [token.address, 1, 4, web3.utils.toWei('1'), dummyUSDT.address, expirationDate]);
    //signature = await web3.eth.accounts.sign(signParams, 'c1086153296cee41b779a7bad9118b82511665392dc0520f37ecf347801360ba');

    balance1 = await token.balanceOf(accounts[0], 1);
    balance2 = await token.balanceOf(accounts[0], 2);
    let balance3 = await token.balanceOf(accounts[0], 3);
    console.log('BALANCE ID 1 ACCOUNT 0 BEFORE RENT --> ', balance1.toString());
    console.log('BALANCE ID 2 ACCOUNT 0 BEFORE RENT --> ', balance2.toString());
    console.log('BALANCE ID 3 ACCOUNT 0 BEFORE RENT --> ', balance3.toString());

    let rentParams = web3.eth.abi.encodeFunctionCall(rentAbi, [token.address, 1, 4, web3.utils.toWei('1'), dummyUSDT.address, expirationDate]);
    signature = await web3.eth.accounts.sign(rentParams, 'c1086153296cee41b779a7bad9118b82511665392dc0520f37ecf347801360ba');

    len = (rentParams.length / 2) - 1;
    paramsLen = web3.utils.asciiToHex(len.toString());
    let renting = await nftMarketplace.metaTxRentERC1155(rentParams, paramsLen, signature.signature, 5, { from: accounts[2] });

    //let renting = await nftMarketplace.rentMultipleERC1155(signParams, paramsLen, 5, signature, { from: accounts[2] });
    //let renting = await nftMarketplace.rentERC1155(signParams, paramsLen, 5, signature.signature, { from: accounts[2] });
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

    let recover = await nftMarketplace.returnRentedERC1155(token.address, [1], [4], accounts[0]);
    console.log('gas consumed recovering: ', recover.receipt.gasUsed);

    balance1 = await token.balanceOf(accounts[0], 1);
    balance2 = await token.balanceOf(accounts[0], 2);
    balance3 = await token.balanceOf(accounts[0], 3);
    console.log('BALANCE ID 1 ACCOUNT 0 AFTER RECOVER --> ', balance1.toString());
    console.log('BALANCE ID 2 ACCOUNT 0 AFTER RECOVER --> ', balance2.toString());
    console.log('BALANCE ID 3 ACCOUNT 0 AFTER RECOVER --> ', balance3.toString());

    //recover = await nftMarketplace.returnRentedERC1155(token.address, [1], [4], accounts[0]);
    //console.log('gas consumed recovering: ', recover.receipt.gasUsed);

    /*
    let messageSellSign = "SELL. " + token.address.toLowerCase() + ". tokenId: 1. amount: 4. price: " + web3.utils.toWei('1') + ". erc20payment: " + dummyUSDT.address.toLowerCase() + ". nonce: 0. packed: 1";
    console.log('MESSAGE SM:', messageSellSign);
    let messageSell = await nftMarketplace.prepareMessageForSellERC1155(token.address, 1, 4, web3.utils.toWei('1'), dummyUSDT.address, 0, true);
    console.log('SM MESSAGE:', messageSell.toString());

    let sig = await web3.eth.accounts.sign(messageSell, '30dcc26622d9dce83bda28831cb95f10bb155841032d84a7fdefedcd4eefeffd').signature;
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

    let xx = await web3.eth.accounts.sign(messageSwap, '30dcc26622d9dce83bda28831cb95f10bb155841032d84a7fdefedcd4eefeffd').signature;
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