// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../../interfaces/INFTMarketplaceAdmin.sol";

contract NFTMarketplaceAdmin is INFTMarketplaceAdmin {

    address private proxy;

    function setProxy(address _proxy) external {
        proxy = _proxy;
    }

    function getProxy() external view override returns(address) {
        return proxy;
    }
}