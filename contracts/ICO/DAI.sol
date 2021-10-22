// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract DAI is ERC20 {
    constructor() ERC20("DAI", "DAI") {
        _mint(msg.sender, 1000000000 * 10**18);
    }

    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }
}
