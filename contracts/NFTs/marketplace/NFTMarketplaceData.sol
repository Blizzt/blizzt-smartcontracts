// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract NFTMarketplaceData {

    struct TokenRentInfo {
        uint48 rentExpiresAt;
        address renter;
        uint24 amount;
    }

    address internal owner;
    uint24  internal maxFee;
    address internal feesWallet;
    uint24  internal minFee;
    address internal blizztStake;
    uint24  internal maxStakedTokens;
    address internal nftFactory;
    address internal nftMarketplaceAdmin;
    
    // Mapping from rents
    mapping(address => mapping (uint256 => mapping(address => TokenRentInfo[]))) internal rentals;
    mapping(uint256 => bool) internal nonces;
    mapping(address => bool) internal cancelledProjects;
}
