// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

interface INFTMarketplace {

    struct TokenRentInfo {
        uint48 rentExpiresAt;
        address renter;
        uint24 amount;
    }

    function mintERC1155(bytes memory _params, bytes memory _messageLength, bytes memory _signature) external payable;

    function rentERC1155(bytes memory _params, bytes memory _messageLength, uint256 _totalAmount, uint256 _seconds, bytes memory signature) external payable;
    function rentMultipleERC1155(bytes memory _params, bytes memory _messageLength, uint256 _amount, uint256 _seconds, bytes memory signature) external payable;
    function returnRentedERC1155(address _erc1155, uint256[] memory _tokenIds, uint256[] memory _amounts, address _owner, address _renter) external;

    function sellERC1155(bytes memory _params, bytes memory _messageLength, uint256 _amountBuy, bytes memory signature) external payable;
    function sellMultipleERC1155(bytes memory _params, bytes memory _messageLength, bytes memory signature) external payable;

    function swapERC1155(bytes memory _params, bytes memory _messageLength, bytes memory signature) external;
    function swapMultipleERC1155(bytes memory _params, bytes memory _messageLength, bytes memory _signature) external;

    function rentedOf(address _account, uint256 _id) external view returns (TokenRentInfo[] memory);
    function getUserRentedItems(address _ownerOf, uint256 _tokenId) external view returns(uint256 amount);
}