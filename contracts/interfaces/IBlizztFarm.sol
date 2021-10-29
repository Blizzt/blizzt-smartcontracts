// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IBlizztFarm {
    function initialSetup(uint256 _startBlock, uint256 _numBlocks) external;
    function add(uint256 _allocPoint, address _lpToken) external;
    function fund(uint256 _amount) external;
    function deposit(address _user, uint256 _amount) external;
    function deposited(address _user) external view returns (uint256);
}
