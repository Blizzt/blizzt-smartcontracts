// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface ILiquidityPoolLocker {
    function lockLP(address _owner, address _lpToken) external;
}
