// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../interfaces/IERC20.sol";
import "../interfaces/ILiquidityPoolLocker.sol";

contract LiquidityPoolLocker is ILiquidityPoolLocker {

    uint256 private releaseDate;
    address private owner;
    address private lpToken;

    function lockLP(address _owner, address _lpToken) external override {
        releaseDate = block.timestamp; // + 365 days;   // TODO.
        owner = _owner;
        lpToken = _lpToken;
    }

    function withdrawLP() external {
        require(msg.sender == owner, "OnlyOwner");
        require(block.timestamp > releaseDate, "NoEnoughTime");

        uint256 balance = IERC20(lpToken).balanceOf(address(this));
        IERC20(lpToken).transfer(owner, balance);
    }
}
