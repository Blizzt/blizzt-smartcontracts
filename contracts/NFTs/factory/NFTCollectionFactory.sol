// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "../../interfaces/INFTMarketplace.sol";
import "../../interfaces/INFTCollection.sol";
import "../../interfaces/IBlizztStake.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract NFTCollectionFactory {

    address public immutable nftCollectionTemplate;
    address public immutable nftMarketplace;
    address public blizztStake;
    uint256 public premiumRequired;
    address public owner;

    event NFTCollectionCreated(address indexed owner, address indexed tokenAddress);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(owner == msg.sender, "OnlyOwner");
        _;
    }

    constructor (address _nftCollectionTemplate, address _nftMarketplace, address _blizztStake, uint256 _premiumRequired) {
        nftCollectionTemplate = _nftCollectionTemplate;
        nftMarketplace = _nftMarketplace;
        blizztStake = _blizztStake;
        premiumRequired = _premiumRequired;
        owner = msg.sender;
    }

    function changeFactoryRequirements(address _blizztStake, uint256 _premiumRequired) external onlyOwner {
        blizztStake = _blizztStake;
        premiumRequired = _premiumRequired;
    }

    function createNFTCollection(string memory _uri) external {
        _createNFTCollection(_uri, msg.sender);
    }

    function createNFTCollectionWithFirstItem(string memory _uri, uint256 _id, uint256 _amount, string memory _metadata) external {
        address nft = _createNFTCollection(_uri, address(this));
        INFTCollection(nft).mint(msg.sender, _id, _amount, _metadata);
        INFTCollection(nft).transferOwnership(msg.sender);
    }

    function createNFTFullCollection(string memory _uri, uint256[] memory _ids, uint256[] memory _amounts, address[] memory _owners) external {
        require(_ids.length == _owners.length, "WrongArrays");
        require(_ids.length == _amounts.length, "WrongArrays");
        require(IBlizztStake(blizztStake).balanceOf(msg.sender) >= premiumRequired, "NoEnoughTokensPremium");

        address nft = Clones.clone(nftCollectionTemplate);
        INFTCollection(nft).initialize(nftMarketplace, address(this), _uri);
        uint256 len = _ids.length;
        for (uint256 i=0; i<len; i++) INFTCollection(nft).mint(_owners[i], _ids[i], _amounts[i]);

        INFTCollection(nft).transferOwnership(msg.sender);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        owner = _newOwner;
        emit OwnershipTransferred(owner, _newOwner);
    }

    function _createNFTCollection(string memory _uri, address _owner) internal returns(address) {
        // Check if the sender has the minimum token required
        require(IBlizztStake(blizztStake).balanceOf(msg.sender) >= premiumRequired, "NoEnoughTokensStaked");

        address nft = Clones.clone(nftCollectionTemplate);
        INFTCollection(nft).initialize(nftMarketplace, _owner, _uri);

        emit NFTCollectionCreated(msg.sender, nft);

        return nft;
    }
}
