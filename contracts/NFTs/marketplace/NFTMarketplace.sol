// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @title Blizzt NFT Marketplace
/// @author Jorge Gomes - <jorge@smartrights.io>

import "./NFTMarketplaceData.sol";
import "../../interfaces/INFTMarketplaceAdmin.sol";

contract NFTMarketplace is NFTMarketplaceData {

    /**
     * @notice Constructor
     * @param _blizztStake      --> 
     * @param _feesWallet       --> 
     * @param _minFee           --> 
     * @param _maxFee           --> 
     * @param _maxStakedTokens  --> 
     */
    constructor (address _blizztStake, address _feesWallet, address _nftMarketplaceAdmin, uint24 _minFee, uint24 _maxFee, uint24 _maxStakedTokens) {
        owner = msg.sender;
        feesWallet = _feesWallet;
        blizztStake = _blizztStake;
        nftMarketplaceAdmin = _nftMarketplaceAdmin;
        minFee = _minFee;
        maxFee = _maxFee;
        maxStakedTokens = _maxStakedTokens;
    }

    fallback () external payable {
        address addr = INFTMarketplaceAdmin(nftMarketplaceAdmin).getProxy();

        assembly {
            let freememstart := mload(0x00)
            calldatacopy(freememstart, 0, calldatasize())
            let success := delegatecall(gas(), addr, freememstart, calldatasize(), freememstart, 0)
            let size := returndatasize()
            returndatacopy(freememstart, 0, size)

            switch success
            case 0 { revert(freememstart, size) }
            default { return(freememstart, size) }
        }
    }
}