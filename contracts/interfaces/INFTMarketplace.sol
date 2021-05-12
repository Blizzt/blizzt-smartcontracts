// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

interface INFTMarketplace {

    function mintERC1155(bytes memory _params, bytes memory _messageLength, bytes memory _signature) external payable;

    function rentERC1155(bytes memory _params, bytes memory _messageLength, uint256 _seconds, bytes memory signature) external payable;
    function rentMultipleERC1155(bytes memory _params, bytes memory _messageLength, uint256 _seconds, bytes memory signature) external payable;
    function returnRentedERC1155(address _erc1155, uint256[] memory _tokenIds, uint256[] memory _amounts, address _owner) external;

    function sellERC1155(bytes memory _params, bytes memory _messageLength, uint256 _amountBuy, bytes memory signature) external payable;
    function sellMultipleERC1155(bytes memory _params, bytes memory _messageLength, bytes memory signature) external payable;

    function swapERC1155(bytes memory _params, bytes memory _messageLength, bytes memory signature) external;
    function swapMultipleERC1155(bytes memory _params, bytes memory _messageLength, bytes memory _signature) external;

    function rentedOf(address _account, uint256 _id) external view returns (uint256);
    function rentedOfBatch(address _accounts, uint256[] memory _ids) external view returns (uint256[] memory);
}