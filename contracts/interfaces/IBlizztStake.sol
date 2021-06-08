// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

interface IBlizztStake {
    function balanceOf(address account) external view returns(uint256);
}
