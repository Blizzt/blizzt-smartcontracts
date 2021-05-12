// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IStaking.sol";

contract BlizztStaking is IStaking {

    address immutable private blizztToken;
    mapping(address => uint256) private balances;

    constructor(address _blizztToken) {
        blizztToken = _blizztToken;
    }

    function stake(uint256 _tokens) external override {
        IERC20(blizztToken).transferFrom(msg.sender, address(this), _tokens);
        balances[msg.sender] += _tokens;
    }

    function balanceOf(address account) external view override returns(uint256) {
        return balances[account];
    }

    function withdraw() external override {

    }
}