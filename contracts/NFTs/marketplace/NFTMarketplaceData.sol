// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract NFTMarketplaceData {

    struct TokenRentInfo {
        uint48 rentExpiresAt;
        address renter;
        uint24 amount;
    }

    struct ProjectData {
        uint24 fee;
        bool cancelled;
        uint160 extraData;
    }

    address internal owner;
    uint24  internal maxFee;
    address internal feesWallet;
    uint24  internal minFee;
    address internal blizztStake;
    uint24  internal maxStakedTokens;
    address internal nftFactory;
    uint24  internal minStakedTokensForRent;
    address internal nftMarketplaceAdmin;
    uint24  internal minStakedTokensForSwap;
    uint24  internal rentTokensBurn;
    address internal blizztRelayer;
    
    // Mapping from rents
    mapping(address => mapping (uint256 => mapping(address => TokenRentInfo[]))) internal rentals;
    mapping(uint256 => bool) internal nonces;
    mapping(address => ProjectData) internal projects;
}
