// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface INFTMarketplace {

    function getUserRentedItems(address _ownerOf, address _erc1155, uint256 _tokenId) external view returns(uint256 amount);
    function getDepositVesting() external view returns (address);
}