// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '../../interfaces/INFTCollection.sol';
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import '../../interfaces/INFTMarketplace.sol';
import '../../interfaces/IBlizztStake.sol';

contract DepositVesting {
    address private owner;
    mapping(address => bool) private cancelled;

    constructor() {
        owner = msg.sender;
    }

    function withdraw(address _token, address _user, uint256 _amount) external {
        require(msg.sender == owner, "BadOwner");

        if (_token == address(0)) {
            payable(address(this)).transfer(_amount);
        } else {
            IERC20 erc20 = IERC20(_token);
            erc20.transfer(_user, _amount);
        }
    }

    function reedemNFT(bytes calldata _params, bytes calldata _messageLength, uint256 _amountNFTs, bytes calldata _signature) external {
        address _ownerOf = _decodeSignature(_params, _messageLength, _signature);
        require(msg.sender != _ownerOf, "NoOwnerAllowed");
        (address _erc1155, uint256 _tokenId, uint24 _amount, uint256 _price, address _erc20payment, bool _packed, ) = abi.decode(_params,(address,uint256,uint24,uint256,address,bool,uint256));
        require(cancelled[_erc1155] == true, "NotCancelled");
        require(IERC1155(_erc1155).balanceOf(msg.sender, _tokenId) >= _amount, "BadOwner");
        if (_packed) require(_amount == _amountNFTs, "MustBuyAll");
        _price = _price * _amountNFTs;

        uint256 fee = _price / 100;
        if (_erc20payment == address(0)) {
            payable(msg.sender).transfer(_price - fee);
        } else {
            IERC20(_erc20payment).transfer(msg.sender, _price - fee);
        }

        IERC1155(_erc1155).safeTransferFrom(msg.sender, _ownerOf, _tokenId, _amountNFTs, "");
    }

    /**
     * @notice Decode the signature of a message
     * @param _message        --> 
     * @param _messageLength  --> 
     * @param _signature      --> 
     * @return Returns the message signer
     */
    function _decodeSignature(bytes memory _message, bytes memory _messageLength, bytes memory _signature) internal pure returns (address) {
        bytes32 messageHash = keccak256(abi.encodePacked(hex"19457468657265756d205369676e6564204d6573736167653a0a", _messageLength, _message));
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(_signature, 0x20))
            s := mload(add(_signature, 0x40))
            v := byte(0, mload(add(_signature, 0x60)))
        }
        return ecrecover(messageHash, v, r, s);
    }
}