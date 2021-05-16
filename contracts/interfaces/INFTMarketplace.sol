// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

interface INFTMarketplace {

    function getUserRentedItems(address _ownerOf, uint256 _tokenId) external view returns(uint256 amount);
}