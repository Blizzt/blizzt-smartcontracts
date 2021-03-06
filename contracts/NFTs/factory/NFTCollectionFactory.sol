// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../interfaces/INFTCollectionFactory.sol";
import "../../interfaces/INFTMarketplace.sol";
import "../../interfaces/INFTCollection.sol";
import "../../interfaces/INFTMultiCollection.sol";
import "../../interfaces/IBlizztStake.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract NFTCollectionFactory is INFTCollectionFactory {

    address public  nftCollectionTemplate;
    address public  nftMultiCollectionTemplate;
    address private nftMarketplace;
    address public  blizztStake;
    uint256 public  premiumRequired;
    address public  owner;

    event NFTCollectionCreated(address indexed owner, address indexed tokenAddress);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(owner == msg.sender, "OnlyOwner");
        _;
    }

    constructor (address _nftCollectionTemplate, address _nftMultiCollectionTemplate, address _nftMarketplace, address _blizztStake, uint256 _premiumRequired) {
        nftCollectionTemplate = _nftCollectionTemplate;
        nftMultiCollectionTemplate = _nftMultiCollectionTemplate;
        nftMarketplace = _nftMarketplace;
        blizztStake = _blizztStake;
        premiumRequired = _premiumRequired;
        owner = msg.sender;
    }

    function updateFactoryRequirements(address _nftCollectionTemplate, address _nftMultiCollectionTemplate, address _blizztStake, uint256 _premiumRequired) external onlyOwner {
        nftCollectionTemplate = _nftCollectionTemplate;
        nftMultiCollectionTemplate = _nftMultiCollectionTemplate;
        blizztStake = _blizztStake;
        premiumRequired = _premiumRequired;
    }

    function updateMarketplace(address _nftMarketplace) external onlyOwner {
        nftMarketplace = _nftMarketplace;
    }

    function getMarketplace() external view override returns (address) {
        return nftMarketplace;
    }

    function createNFTCollection(string memory _uri) external {
        _createNFTCollection(_uri, msg.sender);
    }

    function createNFTMultiCollection(string memory _uri) external {
        _createNFTMultiCollection(_uri, msg.sender);
    }

    function createNFTCollectionWithFirstItem(string memory _uri, uint256 _id, uint256 _amount, string memory _metadata) external {
        address nft = _createNFTCollection(_uri, address(this));
        INFTCollection(nft).mint(msg.sender, _id, _amount, _metadata);
        INFTCollection(nft).transferOwnership(msg.sender);
    }

    function createNFTMultiCollectionWithFirstItem(string memory _uri, uint256 _id, uint256 _amount, string[] memory _metadata) external {
        address nft = _createNFTMultiCollection(_uri, address(this));
        INFTMultiCollection(nft).mint(msg.sender, _id, _amount, _metadata);
        INFTMultiCollection(nft).transferOwnership(msg.sender);
    }

    function createNFTFullCollection(string memory _uri, uint256[] memory _ids, uint256[] memory _amounts, address[] memory _owners) external {
        require(_ids.length == _owners.length, "WrongArrays");
        require(_ids.length == _amounts.length, "WrongArrays");
        require(IBlizztStake(blizztStake).balanceOf(msg.sender) >= premiumRequired, "NoEnoughTokensPremium");

        address nft = Clones.clone(nftCollectionTemplate);
        INFTCollection(nft).initialize(address(this), address(this), _uri);
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
        INFTCollection(nft).initialize(address(this), _owner, _uri);

        emit NFTCollectionCreated(msg.sender, nft);

        return nft;
    }

    function _createNFTMultiCollection(string memory _uri, address _owner) internal returns(address) {
        // Check if the sender has the minimum token required
        require(IBlizztStake(blizztStake).balanceOf(msg.sender) >= premiumRequired, "NoEnoughTokensStaked");

        address nft = Clones.clone(nftMultiCollectionTemplate);
        INFTMultiCollection(nft).initialize(address(this), _owner, _uri);

        emit NFTCollectionCreated(msg.sender, nft);

        return nft;
    }
}
