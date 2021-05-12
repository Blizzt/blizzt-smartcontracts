// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "../utils/TimelockOwnable.sol";

contract DummyContract is TimelockOwnable {

    uint private count;
   
    constructor(address _owner) TimelockOwnable(_owner) {
    }

    function setCount(uint256 _count) external onlyOwner {
        count = _count;
    }

    function tick() external {
    }

    function getCount() external view returns(uint256) {
        return count;
    }
}
