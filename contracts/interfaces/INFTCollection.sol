// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface INFTCollection {
    
    function initialize(address _nftMarketplace, address _newOwner, string memory uri_) external;
    function mint(address _account, uint256 _id, uint256 _amount, string memory _metadata) external;
    function mint(address _account, uint256 _id, uint256 _amount) external;
    function safeTransferForRent(address from, address to, uint256 id, uint256 amount) external;
    function transferOwnership(address newOwner) external;
}
