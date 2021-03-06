// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IBlizztStake {
    function balanceOf(address account) external view returns(uint256);
    function burn(address _user, uint256 _amount) external;
}
