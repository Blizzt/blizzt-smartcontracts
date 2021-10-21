// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/// @title Blizzt NFT Marketplace
/// @author Jorge Gomes - <jorge@smartrights.io>

import "./NFTMarketplaceData.sol";
import "../../interfaces/INFTMarketplaceAdmin.sol";

contract NFTMarketplace is NFTMarketplaceData {

    /**
     * @notice Constructor
     * @param _blizztRelayer            -->
     * @param _blizztStake              --> 
     * @param _feesWallet               --> 
     * @param _minFee                   --> 
     * @param _maxFee                   --> 
     * @param _maxStakedTokens          --> 
     * @param _minStakedTokensForRent   --> 
     * @param _minStakedTokensForSwap   --> 
     * @param _rentTokensBurn           --> 
     */
    constructor (address _blizztRelayer, address _blizztStake, address _feesWallet, address _nftMarketplaceAdmin, uint24 _minFee, uint24 _maxFee, uint24 _maxStakedTokens, 
                 uint24 _minStakedTokensForRent, uint24 _minStakedTokensForSwap, uint24 _rentTokensBurn) {
        owner = msg.sender;
        blizztRelayer = _blizztRelayer;
        feesWallet = _feesWallet;
        blizztStake = _blizztStake;
        nftMarketplaceAdmin = _nftMarketplaceAdmin;
        minFee = _minFee;
        maxFee = _maxFee;
        maxStakedTokens = _maxStakedTokens;
        minStakedTokensForRent = _minStakedTokensForRent;
        minStakedTokensForSwap = _minStakedTokensForSwap;
        rentTokensBurn = _rentTokensBurn;
    }

    function _delegate() internal {
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

    fallback () external payable {
        _delegate();
    }

    receive () external payable {
        _delegate();
    }
}