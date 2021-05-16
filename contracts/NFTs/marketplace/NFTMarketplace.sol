// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import '../../interfaces/INFTCollection.sol';
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import '../../interfaces/INFTMarketplace.sol';

contract NFTMarketplace is INFTMarketplace {

    address private owner;
    address private blizztToken;
    address private nftFactory;
    uint24 private fee;
    uint24 private tokensHalfFee;
    uint24 private tokensNoFee;

    // Mapping from rents
    mapping (uint256 => mapping(address => TokenRentInfo[])) private _rents;

    event TokenRented(address indexed _owner, address indexed _renter, address indexed _erc1155, uint256 _tokenId, uint256 _amount, uint256 _rentedUntil, uint256 _paid, address _erc20payment);
    event TokensRented(address indexed _owner, address indexed _renter, address indexed _erc1155, uint256[] _tokenId, uint256[] _amount, uint256 _rentedUntil, uint256 _paid, address _erc20payment);
    event TokensReturned(address indexed _erc1155, uint256[] _tokenIds, uint256[] _amounts, address indexed _owner);
    event TokenSold(address indexed _buyer, address indexed _seller, address indexed _erc1155, uint256 _tokenId, uint256 _amount, uint256 _price, address _erc20payment);
    event TokensSold(address indexed _buyer, address indexed _seller, address indexed _erc1155, uint256[] _tokenIds, uint256[] _amounts, uint256 _price, address _erc20payment);
    event TokenSwapped(address _fromWallet, address indexed _fromERC1155, uint256 _fromTokenId, uint256 _fromAmount, address _toWallet, address indexed _toERC1155, uint256 _toTokenId, uint256 _toAmount);
    event TokensSwapped(address _fromWallet, address indexed _fromERC1155, uint256[] _fromTokenIds, uint256[] _fromAmounts, address _toWallet, address _toERC1155, uint256[] _toTokenIds, uint256[] _toAmounts);

    modifier onlyOwner() {
        require(owner == msg.sender, "NoOwner");
        _;
    }

    /**
     * @notice Constructor
     * @param _blizztToken     --> 
     * @param _fee              --> 
     * @param _tokensHalfFee    --> 
     * @param _tokensNoFee      --> 
     */
    constructor (address _blizztToken, uint16 _fee, uint24 _tokensHalfFee, uint24 _tokensNoFee) {
        owner = msg.sender;
        blizztToken = _blizztToken;
        fee = _fee;
        tokensHalfFee = _tokensHalfFee;
        tokensNoFee = _tokensNoFee;
    }

    /** 
     * @notice Change the marketplace fees
     * @param _fee              --> 
     * @param _tokensHalfFee    --> 
     * @param _tokensNoFee      --> 
     */
    function changeFee(uint16 _fee, uint24 _tokensHalfFee, uint24 _tokensNoFee) external onlyOwner {
        fee = _fee;
        tokensHalfFee = _tokensHalfFee;
        tokensNoFee = _tokensNoFee;
    }

    /** 
     * @notice Mint a new ERC1155 using a previous signed message
     * @param _params         --> 
     * @param _messageLength  --> 
     * @param _signature      --> 
     */
    function mintERC1155(bytes memory _params, bytes memory _messageLength, bytes memory _signature) external override payable {
        address ownerOf = _decodeSignature(_params, _messageLength, _signature);
        (address _erc1155, uint256 _tokenId, uint24 _amount, uint256 _price, address _erc20payment, string memory _metadata, uint256 expirationDate) = abi.decode(_params,(address,uint256,uint24,uint256,address,string,uint256));
        require(expirationDate >= block.timestamp, "Expirated");

        INFTCollection(_erc1155).mint(msg.sender, _tokenId, _amount, _metadata);
        if (_price > 0) {
            if (_erc20payment == address(0)) {
                require(_price == msg.value, "BadETH");
                payable(ownerOf).transfer(_price);
            } else {
                IERC20(_erc20payment).transferFrom(msg.sender, ownerOf, _price);
            }
        }
    }

    /** 
     * @notice Rents an ERC1155 token using a previous signed message
     * @param _params         --> 
     * @param _messageLength  --> 
     * @param _seconds        -->
     * @param _signature      --> 
     */
    function rentERC1155(bytes memory _params, bytes memory _messageLength, uint256 _amount, uint256 _seconds, bytes memory _signature) external override payable {
        address ownerOf = _decodeSignature(_params, _messageLength, _signature);
        (address _erc1155, uint256 _tokenId, uint24 _totalAmount, uint256 _price, address _erc20payment, uint256 _expirationDate) = abi.decode(_params,(address,uint256,uint24,uint256,address,uint256));
        require(_expirationDate >= block.timestamp, "Expirated");
        require(IERC1155(_erc1155).balanceOf(ownerOf, _tokenId) >= _amount, "BadOwner");
        require(_getUserRentedItems(ownerOf, _tokenId) + _amount < _totalAmount, "MaxItemsRented");

        _rentERC1155(ownerOf, _erc1155, _tokenId, _amount, _seconds);
        if (_erc20payment == address(0)) {
            require(msg.value >= (_amount * _price * _seconds), "BadETH");
            payable(ownerOf).transfer(msg.value);
        } else {
            IERC20(_erc20payment).transferFrom(msg.sender, ownerOf, msg.value);
        }

        // TODO. How to charge a fee for the platform??????

        emit TokenRented(ownerOf, msg.sender, _erc1155, _tokenId, _amount, block.timestamp + (_seconds * 1 seconds), _price * _seconds, _erc20payment);
    }

    /** 
     * @notice Rents a package of ERC1155 tokens using a previous signed message
     * @param _params         --> 
     * @param _messageLength  --> 
     * @param _seconds        -->
     * @param _signature      --> 
     */
    function rentMultipleERC1155(bytes memory _params, bytes memory _messageLength, uint256 _amount, uint256 _seconds, bytes memory _signature) external override payable {
        address ownerOf = _decodeSignature(_params, _messageLength, _signature);
        (address _erc1155, uint256[] memory _tokenIds, uint256[] memory _amounts, uint256 _price, address _erc20payment, uint256 _expirationDate) = abi.decode(_params,(address,uint256[],uint256[],uint256,address,uint256));
        require(_expirationDate >= block.timestamp, "Expirated");
        for (uint i=0; i<_tokenIds.length; i++) require(IERC1155(_erc1155).balanceOf(ownerOf, _tokenIds[i]) >= _amounts[i], "BadOwner");

        // TODO. Que pasa si la misma persona alquila 2 copias del mismo NFT en dos momentos o a dos personas diferentes???????? Pensar el caso
        for (uint i=0; i< _tokenIds.length; i++) _rentERC1155(ownerOf, _erc1155, _tokenIds[i], _amounts[i], _seconds);
  
        if (_erc20payment == address(0)) {
            require(msg.value >= (_amount * _price * _seconds), "BadETH");
            payable(ownerOf).transfer(msg.value);
        } else {
            IERC20(_erc20payment).transferFrom(msg.sender, ownerOf, msg.value);
        }

        // TODO. How to charge a fee for the platform??????

        emit TokensRented(ownerOf, msg.sender, _erc1155, _tokenIds, _amounts, block.timestamp + (_seconds * 1 seconds), _price * _seconds, _erc20payment);
    }

    /**
     * @notice Returns ERC1155 tokens previously rented
     * @param _erc1155    --> 
     * @param _tokenIds   --> 
     * @param _amounts    --> 
     * @param _owner      --> 
     */
    function returnRentedERC1155(address _erc1155, uint256[] memory _tokenIds, uint256[] memory _amounts, address _owner, address _renter) external override {
        for (uint i=0; i<_tokenIds.length; i++) {
            TokenRentInfo[] storage rentInfo = _rents[_tokenIds[i]][_owner];
            for (uint j=0; j<rentInfo.length; j++) {
                if (rentInfo[j].renter == _renter && rentInfo[j].amount == _amounts[i] && rentInfo[j].rentExpiresAt < block.timestamp) {
                    TokenRentInfo memory tokenRent = rentInfo[j];
                    require(tokenRent.rentExpiresAt > 0, "NoRented");
                    require(tokenRent.amount > 0, "NoRented");
                    require(block.timestamp >= tokenRent.rentExpiresAt, "RentStillActive");

                    INFTCollection(_erc1155).safeTransferForRent(tokenRent.renter, _owner, _tokenIds[i], _amounts[i]);
                    if (rentInfo.length > 1) {
                        rentInfo[j] = rentInfo[rentInfo.length-1];
                        rentInfo.pop();
                    } else {
                        delete _rents[_tokenIds[i]][_owner];
                    }
                }
            }
        }

        emit TokensReturned(_erc1155, _tokenIds, _amounts, _owner);
    }

    /**
     * @notice Returns ERC1155 tokens previously rented
     * @param _params         --> 
     * @param _messageLength  --> 
     * @param _amountBuy      --> 
     * @param _signature      --> 
     */
    function sellERC1155(bytes memory _params, bytes memory _messageLength, uint256 _amountBuy, bytes memory _signature) external override payable {
        address ownerOf = _decodeSignature(_params, _messageLength, _signature);
        (address _erc1155, uint256 _tokenId, uint24 _amount, uint256 _price, address _erc20payment, bool _packed, uint256 expirationDate) = abi.decode(_params,(address,uint256,uint24,uint256,address,bool,uint256));
        require(expirationDate >= block.timestamp, "Expirated");
        require(IERC1155(_erc1155).balanceOf(ownerOf, _tokenId) >= _amount, "BadOwner");
        if (_packed) require(_amount == _amountBuy, "MustBuyAll");

        IERC1155(_erc1155).safeTransferFrom(ownerOf, msg.sender, _tokenId, _amount, "");

        if (_erc20payment == address(0)) {
            require(_price == msg.value, "BadETH");
            payable(ownerOf).transfer(_price);
        } else {
            IERC20(_erc20payment).transferFrom(msg.sender, ownerOf, _price);
        }

        // TODO. How to charge a fee for the platform??????
        
        emit TokenSold(msg.sender, ownerOf, _erc1155, _tokenId, _amountBuy, _price, _erc20payment);
    }

    /**
     * @notice Returns ERC1155 tokens previously rented
     * @param _params         --> 
     * @param _messageLength  --> 
     * @param _signature      --> 
     */
    function sellMultipleERC1155(bytes memory _params, bytes memory _messageLength, bytes memory _signature) external override payable {
        address ownerOf = _decodeSignature(_params, _messageLength, _signature);
        (address _erc1155, uint256[] memory _tokenIds, uint256[] memory _amounts, uint256 _price, address _erc20payment, uint256 expirationDate) = abi.decode(_params,(address,uint256[],uint256[],uint256,address,uint256));
        require(expirationDate >= block.timestamp, "Expirated");
        for (uint i=0; i<_tokenIds.length; i++) require(IERC1155(_erc1155).balanceOf(ownerOf, _tokenIds[i]) >= _amounts[i], "BadOwner");

        IERC1155(_erc1155).safeBatchTransferFrom(ownerOf, msg.sender, _tokenIds, _amounts, "");

        if (_erc20payment == address(0)) {
            require(_price == msg.value, "BadETH");
            payable(ownerOf).transfer(_price);
        } else {
            IERC20(_erc20payment).transferFrom(msg.sender, ownerOf, _price);
        }

        // TODO. How to charge a fee for the platform??????

        emit TokensSold(msg.sender, ownerOf, _erc1155, _tokenIds, _amounts, _price, _erc20payment);
    }

    /**
     * @notice Returns ERC1155 tokens previously rented
     * @param _params         --> 
     * @param _messageLength  --> 
     * @param _signature      --> 
     */
    function swapERC1155(bytes memory _params, bytes memory _messageLength, bytes memory _signature) external override {
        address ownerOfFrom = _decodeSignature(_params, _messageLength, _signature);
        (address _fromERC1155, uint256 _fromTokenId, uint256 _fromAmount, address _toERC1155, uint256 _toTokenId, uint256 _toAmount, uint256 expirationDate) = abi.decode(_params,(address,uint256,uint256,address,uint256,uint256,uint256));
        require(expirationDate >= block.timestamp, "Expirated");
        require(IERC1155(_fromERC1155).balanceOf(ownerOfFrom, _fromTokenId) >= _fromAmount, "BadOwner");

        IERC1155(_fromERC1155).safeTransferFrom(ownerOfFrom, msg.sender, _fromTokenId, _fromAmount, "");
        IERC1155(_toERC1155).safeTransferFrom(msg.sender, ownerOfFrom, _toTokenId, _toAmount, "");

        emit TokenSwapped(ownerOfFrom, _fromERC1155, _fromTokenId, _fromAmount, msg.sender, _toERC1155, _toTokenId, _toAmount);
    }

    /**
     * @notice Returns ERC1155 tokens previously rented
     * @param _params         --> 
     * @param _messageLength  --> 
     * @param _signature      --> 
     */
    function swapMultipleERC1155(bytes memory _params, bytes memory _messageLength, bytes memory _signature) external override {
        address ownerOfFrom = _decodeSignature(_params, _messageLength, _signature);
        (address _fromERC1155, uint256[] memory _fromTokenIds, uint256[] memory _fromAmounts, address _toERC1155, uint256[] memory _toTokenIds, uint256[] memory _toAmounts, uint256 _expirationDate) = abi.decode(_params,(address,uint256[],uint256[],address,uint256[],uint256[],uint256));
        require(_expirationDate >= block.timestamp, "Expirated");
        for (uint i=0; i<_fromTokenIds.length; i++) require(IERC1155(_fromERC1155).balanceOf(ownerOfFrom, _fromTokenIds[i]) >= _fromAmounts[i], "BadOwner");

        IERC1155(_fromERC1155).safeBatchTransferFrom(ownerOfFrom, msg.sender, _fromTokenIds, _fromAmounts, "");
        IERC1155(_toERC1155).safeBatchTransferFrom(msg.sender, ownerOfFrom, _toTokenIds, _toAmounts, "");

        emit TokensSwapped(ownerOfFrom, _fromERC1155, _fromTokenIds, _fromAmounts, msg.sender, _toERC1155, _toTokenIds, _toAmounts);
    }

    /**
     * @notice Returns the rent data of an NFT that an account has put for rent
     * @param _account  --> 
     * @param _id       --> 
     */
    function rentedOf(address _account, uint256 _id) external view override returns (TokenRentInfo[] memory) {
        require(_account != address(0), "NoZeroAddress");
        return _rents[_id][_account];
    }

    /**
     * @notice Returns the amount of an NFT that an account has put for rent
     * @param _ownerOf  --> 
     * @param _tokenId  --> 
     */
    function getUserRentedItems(address _ownerOf, uint256 _tokenId) external view override returns(uint256 amount) {
        return _getUserRentedItems(_ownerOf, _tokenId);
    }

    /**
     * @notice Internal function for rent an individual NFT
     * @param _ownerOf  --> 
     * @param _erc1155  --> 
     * @param _tokenId  --> 
     * @param _amount   --> 
     * @param _seconds  --> 
     */
    function _rentERC1155(address _ownerOf, address _erc1155, uint256 _tokenId, uint256 _amount, uint256 _seconds) internal {
        _rents[_tokenId][_ownerOf].push(TokenRentInfo({
            rentExpiresAt: uint48(block.timestamp + (_seconds * 1 seconds)),
            renter: msg.sender,
            amount: uint24(_amount)
        }));

        INFTCollection(_erc1155).safeTransferForRent(_ownerOf, msg.sender, _tokenId, _amount);
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

    function _getUserRentedItems(address _ownerOf, uint256 _tokenId) internal view returns(uint256 amount) {
        TokenRentInfo[] memory rents = _rents[_tokenId][_ownerOf];
        for (uint i=0; i<rents.length; i++) {
            amount += rents[i].amount;
        }
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0));
        owner = _newOwner;
    }
}
