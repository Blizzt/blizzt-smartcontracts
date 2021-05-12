// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

interface IStaking {

    function stake(uint256 _tokens) external;
    function balanceOf(address account) external view returns(uint256);
    function withdraw() external;
}
