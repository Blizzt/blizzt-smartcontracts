// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../interfaces/IBlizztToken.sol";
import "../interfaces/IBlizztStake.sol";

contract BlizztStake is IBlizztStake {

    address immutable private blizztToken;
    address private owner;
    address private nftMarketplace;
    mapping(address => uint256) private balances;

    event BlizztTokenStaked(address indexed _user, uint indexed _amount);
    event Withdraw(address indexed _user, uint indexed _amount);

    constructor(address _blizztToken) {
        blizztToken = _blizztToken;
        owner = msg.sender;
    }

    function setMarketplace(address _nftMarketplace) external {
        require(owner == msg.sender, "OnlyOwner");
        nftMarketplace = _nftMarketplace;
    }

    function stake(uint256 _amount) external {
        IBlizztToken(blizztToken).transferFrom(msg.sender, address(this), _amount);
        balances[msg.sender] += _amount;

        emit BlizztTokenStaked(msg.sender, _amount);
    }

    function balanceOf(address account) external view override returns(uint256) {
        return balances[account];
    }

    function withdraw() external {
        uint256 balance = balances[msg.sender];
        require(balance <= IBlizztToken(blizztToken).balanceOf(address(this)), "NotEnoughBalance");
        
        delete balances[msg.sender];
        IBlizztToken(blizztToken).transfer(msg.sender, balance);

        emit Withdraw(msg.sender, balance);
    }

    function burn(address _user, uint256 _amount) external override {
        require(msg.sender == nftMarketplace, "OnlyMarketplace");
        if (_amount > 0) {
            balances[_user] -= _amount;
            IBlizztToken(blizztToken).burn(_amount);
        }
    }
}