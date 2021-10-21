// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DummyLP is ERC20 {

    constructor(uint256 initialSupply) ERC20("DummyLP", "DLP") {  
        _mint(msg.sender, initialSupply);
    }
}