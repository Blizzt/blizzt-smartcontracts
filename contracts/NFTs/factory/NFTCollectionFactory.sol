// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "../../interfaces/INFTMarketplace.sol";
import "../../interfaces/INFTCollection.sol";
import "../../interfaces/IStaking.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract NFTCollectionFactory {

    address public immutable nftCollectionTemplate;
    address public immutable nftMarketplace;
    address public immutable blizztToken;
    address public stakeToken;
    uint256 public premiumRequired;
    address public owner;

    event NFTCollectionCreated(address indexed owner, address indexed tokenAddress);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(owner == msg.sender, "OnlyOwner");
        _;
    }

    constructor (address _nftCollectionTemplate, address _nftMarketplace, address _blizztToken, address _stakeToken, uint256 _premiumRequired) {
        nftCollectionTemplate = _nftCollectionTemplate;
        nftMarketplace = _nftMarketplace;
        blizztToken = _blizztToken;
        stakeToken = _stakeToken;
        premiumRequired = _premiumRequired;
        owner = msg.sender;
    }

    function changeFactoryRequirements(address _stakeToken, uint256 _premiumRequired) external onlyOwner {
        stakeToken = _stakeToken;
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
        require(IStaking(blizztToken).balanceOf(msg.sender) >= premiumRequired, "NoEnoughTokensPremium");

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
        require(IERC20(blizztToken).balanceOf(msg.sender) >= premiumRequired, "NoEnoughTokensFree");

        address nft = Clones.clone(nftCollectionTemplate);
        INFTCollection(nft).initialize(nftMarketplace, _owner, _uri);

        emit NFTCollectionCreated(msg.sender, nft);

        return nft;
    }
}
