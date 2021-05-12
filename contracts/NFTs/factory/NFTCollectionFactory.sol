// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "../../interfaces/INFTMarketplace.sol";
import "../../interfaces/INFTCollection.sol";
import "../../interfaces/IStaking.sol";
import "../../utils/TimelockOwnable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract NFTCollectionFactory is TimelockOwnable {

    address public immutable nftCollectionTemplate;
    address public immutable nftMarketplace;
    address public immutable divanceToken;
    address public stakeToken;
    uint256 public minRequiredFree;
    uint256 public minRequiredPremium;

    event NFTCollectionCreated(address indexed owner, address indexed tokenAddress);

    constructor (address _nftCollectionTemplate, address _nftMarketplace, address _divanceToken, address _stakeToken, uint256 _minRequiredFree, uint256 _minRequiredPremium) TimelockOwnable(msg.sender) {
        nftCollectionTemplate = _nftCollectionTemplate;
        nftMarketplace = _nftMarketplace;
        divanceToken = _divanceToken;
        stakeToken = _stakeToken;
        minRequiredFree = _minRequiredFree;
        minRequiredPremium = _minRequiredPremium;
    }

    function changeFactoryRequirements(address _stakeToken, uint256 _minRequiredFree, uint256 _minRequiredPremium) external onlyOwner {
        stakeToken = _stakeToken;
        minRequiredFree = _minRequiredFree;
        minRequiredPremium = _minRequiredPremium;
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
        require(IStaking(divanceToken).balanceOf(msg.sender) >= minRequiredPremium, "NoEnoughTokensPremium");

        address nft = Clones.clone(nftCollectionTemplate);
        INFTCollection(nft).initialize(nftMarketplace, address(this), _uri);
        uint256 len = _ids.length;
        for (uint256 i=0; i<len; i++) INFTCollection(nft).mint(_owners[i], _ids[i], _amounts[i]);

        INFTCollection(nft).transferOwnership(msg.sender);
    }

    function _createNFTCollection(string memory _uri, address _owner) internal returns(address) {
        // Check if the sender has the minimum token required
        require(IERC20(divanceToken).balanceOf(msg.sender) >= minRequiredFree, "NoEnoughTokensFree");

        address nft = Clones.clone(nftCollectionTemplate);
        INFTCollection(nft).initialize(nftMarketplace, _owner, _uri);

        emit NFTCollectionCreated(msg.sender, nft);

        return nft;
    }
}
