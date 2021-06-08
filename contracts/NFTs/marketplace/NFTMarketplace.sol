// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import '../../interfaces/INFTCollection.sol';
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import '../../interfaces/INFTMarketplace.sol';
import '../../interfaces/IBlizztStake.sol';

contract NFTMarketplace is INFTMarketplace {

    struct TokenRentInfo {
        uint48 rentExpiresAt;
        address renter;
        uint24 amount;
    }

    address private owner;
    uint24 private maxFee;
    address private feesWallet;
    uint24 private minFee;
    address private blizztStake;
    uint24 private maxStakedTokens;
    address private nftFactory;
    
    // Mapping from rents
    mapping(address => mapping (uint256 => mapping(address => TokenRentInfo[]))) private _rents;

    event TokenRented(address indexed _owner, address indexed _renter, address indexed _erc1155, uint256 _tokenId, uint256 _amount, uint256 _rentedUntil, uint256 _paid, address _erc20payment);
    event TokensRented(address indexed _owner, address indexed _renter, address indexed _erc1155, uint256[] _tokenId, uint256[] _amount, uint256 _rentedUntil, uint256 _paid, address _erc20payment);
    event TokensReturned(address indexed _erc1155, uint256[] _tokenIds, uint256[] _amounts, address indexed _owner);
    event TokenSold(address indexed _buyer, address indexed _seller, address indexed _erc1155, uint256 _tokenId, uint256 _amount, uint256 _price, address _erc20payment);
    event TokensSold(address indexed _buyer, address indexed _seller, address indexed _erc1155, uint256[] _tokenIds, uint256[] _amounts, uint256 _price, address _erc20payment);
    event TokenSwapped(address _fromWallet, address indexed _fromERC1155, uint256 _fromTokenId, uint256 _fromAmount, address _toWallet, address indexed _toERC1155, uint256 _toTokenId, uint256 _toAmount);
    event TokensSwapped(address _fromWallet, address indexed _fromERC1155, uint256[] _fromTokenIds, uint256[] _fromAmounts, address _toWallet, address _toERC1155, uint256[] _toTokenIds, uint256[] _toAmounts);
    event WithdrawFees(address indexed _wallet, uint256 _balance);

    modifier onlyOwner() {
        require(owner == msg.sender, "NoOwner");
        _;
    }

    /**
     * @notice Constructor
     * @param _blizztStake      --> 
     * @param _feesWallet       --> 
     * @param _minFee           --> 
     * @param _maxFee           --> 
     * @param _maxStakedTokens  --> 
     */
    constructor (address _blizztStake, address _feesWallet, uint24 _minFee, uint24 _maxFee, uint24 _maxStakedTokens) {
        owner = msg.sender;
        feesWallet = _feesWallet;
        blizztStake = _blizztStake;
        minFee = _minFee;
        maxFee = _maxFee;
        maxStakedTokens = _maxStakedTokens;
    }

    /** 
     * @notice Mint a new ERC1155 using a previous signed message
     * @param _params         --> 
     * @param _messageLength  --> 
     * @param _signature      --> 
     */
    function mintERC1155(bytes memory _params, bytes memory _messageLength, bytes memory _signature) external payable {
        address ownerOf = _decodeSignature(_params, _messageLength, _signature);
        (address _erc1155, uint256 _tokenId, uint24 _amount, uint256 _price, address _erc20payment, string memory _metadata, uint256 expirationDate) = abi.decode(_params,(address,uint256,uint24,uint256,address,string,uint256));
        require(expirationDate >= block.timestamp, "Expirated");

        INFTCollection(_erc1155).mint(msg.sender, _tokenId, _amount, _metadata);
        if (_price > 0) {
            uint256 fee = _price * _getFee() / 10000;
            uint256 adjustedPrice = _price - fee;
            if (_erc20payment == address(0)) {
                require(_price == msg.value, "BadETH");
                payable(ownerOf).transfer(adjustedPrice);
            } else {
                IERC20(_erc20payment).transferFrom(msg.sender, ownerOf, adjustedPrice);
                if (fee > 0) IERC20(_erc20payment).transferFrom(msg.sender, address(this), fee);
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
    function rentERC1155(bytes memory _params, bytes memory _messageLength, uint256 _amount, uint256 _seconds, bytes memory _signature) external payable {
        address ownerOf = _decodeSignature(_params, _messageLength, _signature);
        (address _erc1155, uint256 _tokenId, uint24 _totalAmount, uint256 _price, address _erc20payment, uint256 _expirationDate) = abi.decode(_params,(address,uint256,uint24,uint256,address,uint256));
        require(_expirationDate >= block.timestamp, "Expirated");
        require(IERC1155(_erc1155).balanceOf(ownerOf, _tokenId) >= _amount, "BadOwner");
        require(_getUserRentedItems(ownerOf, _erc1155, _tokenId) + _amount <= _totalAmount, "MaxItemsRented");
        uint256 rentValue = _amount * _price * _seconds;

        _rentERC1155(ownerOf, _erc1155, _tokenId, _amount, _seconds);
        _pay(ownerOf, rentValue, _erc20payment);

        emit TokenRented(ownerOf, msg.sender, _erc1155, _tokenId, _amount, block.timestamp + (_seconds * 1 seconds), rentValue, _erc20payment);
    }

    /** 
     * @notice Rents a package of ERC1155 tokens using a previous signed message
     * @param _params         --> 
     * @param _messageLength  --> 
     * @param _seconds        -->
     * @param _signature      --> 
     */
    function rentMultipleERC1155(bytes memory _params, bytes memory _messageLength, uint256 _amount, uint256 _seconds, bytes memory _signature) external payable {
        address ownerOf = _decodeSignature(_params, _messageLength, _signature);
        (address _erc1155, uint256[] memory _tokenIds, uint256[] memory _amounts, uint256 _price, address _erc20payment, uint256 _expirationDate) = abi.decode(_params,(address,uint256[],uint256[],uint256,address,uint256));
        require(_expirationDate >= block.timestamp, "Expirated");
        for (uint i=0; i<_tokenIds.length; i++) require(IERC1155(_erc1155).balanceOf(ownerOf, _tokenIds[i]) >= _amounts[i], "BadOwner");
        uint256 rentValue = _amount * _price * _seconds;

        // TODO. Que pasa si la misma persona alquila 2 copias del mismo NFT en dos momentos o a dos personas diferentes???????? Pensar el caso
        for (uint i=0; i< _tokenIds.length; i++) _rentERC1155(ownerOf, _erc1155, _tokenIds[i], _amounts[i], _seconds);
        _pay(ownerOf, rentValue, _erc20payment);

        emit TokensRented(ownerOf, msg.sender, _erc1155, _tokenIds, _amounts, block.timestamp + (_seconds * 1 seconds), rentValue, _erc20payment);
    }

    /**
     * @notice Returns ERC1155 tokens previously rented
     * @param _erc1155    --> 
     * @param _tokenIds   --> 
     * @param _amounts    --> 
     * @param _owner      --> 
     */
    function returnRentedERC1155(address _erc1155, uint256[] memory _tokenIds, uint256[] memory _amounts, address _owner, address _renter) external {
        for (uint i=0; i<_tokenIds.length; i++) {
            TokenRentInfo[] storage rentInfo = _rents[_erc1155][_tokenIds[i]][_owner];
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
                        delete _rents[_erc1155][_tokenIds[i]][_owner];
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
    function sellERC1155(bytes memory _params, bytes memory _messageLength, uint256 _amountBuy, bytes memory _signature) external payable {
        address ownerOf = _decodeSignature(_params, _messageLength, _signature);
        (address _erc1155, uint256 _tokenId, uint24 _amount, uint256 _price, address _erc20payment, bool _packed, uint256 expirationDate) = abi.decode(_params,(address,uint256,uint24,uint256,address,bool,uint256));
        require(expirationDate >= block.timestamp, "Expirated");
        require(IERC1155(_erc1155).balanceOf(ownerOf, _tokenId) >= _amount, "BadOwner");
        if (_packed) require(_amount == _amountBuy, "MustBuyAll");
        _price = _price * _amountBuy;

        IERC1155(_erc1155).safeTransferFrom(ownerOf, msg.sender, _tokenId, _amount, "");
        _pay(ownerOf, _price, _erc20payment);
        
        emit TokenSold(msg.sender, ownerOf, _erc1155, _tokenId, _amountBuy, _price, _erc20payment);
    }

    /**
     * @notice Returns ERC1155 tokens previously rented
     * @param _params         --> 
     * @param _messageLength  --> 
     * @param _signature      --> 
     */
    function sellMultipleERC1155(bytes memory _params, bytes memory _messageLength, bytes memory _signature) external payable {
        address ownerOf = _decodeSignature(_params, _messageLength, _signature);
        (address _erc1155, uint256[] memory _tokenIds, uint256[] memory _amounts, uint256 _price, address _erc20payment, uint256 expirationDate) = abi.decode(_params,(address,uint256[],uint256[],uint256,address,uint256));
        require(expirationDate >= block.timestamp, "Expirated");
        for (uint i=0; i<_tokenIds.length; i++) require(IERC1155(_erc1155).balanceOf(ownerOf, _tokenIds[i]) >= _amounts[i], "BadOwner");

        IERC1155(_erc1155).safeBatchTransferFrom(ownerOf, msg.sender, _tokenIds, _amounts, "");
        _pay(ownerOf, _price, _erc20payment);

        emit TokensSold(msg.sender, ownerOf, _erc1155, _tokenIds, _amounts, _price, _erc20payment);
    }

    /**
     * @notice Swap two ERC1155 tokens
     * @param _params         --> 
     * @param _messageLength  --> 
     * @param _signature      --> 
     */
    function swapERC1155(bytes memory _params, bytes memory _messageLength, bytes memory _signature) external {
        address ownerOfFrom = _decodeSignature(_params, _messageLength, _signature);
        (address _fromERC1155, uint256 _fromTokenId, uint256 _fromAmount, address _toERC1155, uint256 _toTokenId, uint256 _toAmount, uint256 expirationDate) = abi.decode(_params,(address,uint256,uint256,address,uint256,uint256,uint256));
        require(expirationDate >= block.timestamp, "Expirated");
        require(IERC1155(_fromERC1155).balanceOf(ownerOfFrom, _fromTokenId) >= _fromAmount, "BadOwner");

        // TODO. Check that two users have Blizz token staked

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
    function swapMultipleERC1155(bytes memory _params, bytes memory _messageLength, bytes memory _signature) external {
        address ownerOfFrom = _decodeSignature(_params, _messageLength, _signature);
        (address _fromERC1155, uint256[] memory _fromTokenIds, uint256[] memory _fromAmounts, address _toERC1155, uint256[] memory _toTokenIds, uint256[] memory _toAmounts, uint256 _expirationDate) = abi.decode(_params,(address,uint256[],uint256[],address,uint256[],uint256[],uint256));
        require(_expirationDate >= block.timestamp, "Expirated");
        for (uint i=0; i<_fromTokenIds.length; i++) require(IERC1155(_fromERC1155).balanceOf(ownerOfFrom, _fromTokenIds[i]) >= _fromAmounts[i], "BadOwner");

        // TODO. Check that two users have Blizz token staked

        IERC1155(_fromERC1155).safeBatchTransferFrom(ownerOfFrom, msg.sender, _fromTokenIds, _fromAmounts, "");
        IERC1155(_toERC1155).safeBatchTransferFrom(msg.sender, ownerOfFrom, _toTokenIds, _toAmounts, "");

        emit TokensSwapped(ownerOfFrom, _fromERC1155, _fromTokenIds, _fromAmounts, msg.sender, _toERC1155, _toTokenIds, _toAmounts);
    }

    /**
     * @notice Returns the rent data of an NFT that an account has put for rent
     * @param _account  --> 
     * @param _id       --> 
     */
    function rentedOf(address _account, address _erc1155, uint256 _id) external view returns (TokenRentInfo[] memory) {
        return _rents[_erc1155][_id][_account];
    }

    /**
     * @notice Returns the amount of an NFT that an account has put for rent
     * @param _ownerOf  --> 
     * @param _tokenId  --> 
     */
    function getUserRentedItems(address _ownerOf, address _erc1155, uint256 _tokenId) external view override returns(uint256 amount) {
        return _getUserRentedItems(_ownerOf, _erc1155, _tokenId);
    }

    /**
     * @notice Returns the amount of an NFT that an account has put for rent
     * @param _ownerOf  --> 
     * @param _tokenId  --> 
     */
    function getUsersRentedItems(address[] memory _ownerOf, address _erc1155, uint256 _tokenId) external view returns(uint256[] memory amounts) {
        for (uint i=0; i<_ownerOf.length; i++) {
            amounts[i] = _getUserRentedItems(_ownerOf[i], _erc1155, _tokenId);
        }
    }

    /**
     * @notice Make the payments
     * @param _ownerOf  --> 
     * @param _price  --> 
     * @param _erc20payment  -->  
     */
    function _pay(address _ownerOf, uint256 _price, address _erc20payment) internal {
        if (_erc20payment == address(0)) {
            require(msg.value >= _price, "BadETH");
            uint256 fee = msg.value * _getFee() / 10000;
            payable(_ownerOf).transfer(msg.value - fee);
        } else {
            uint256 fee = _price * _getFee() / 10000;
            IERC20(_erc20payment).transferFrom(msg.sender, _ownerOf, _price - fee);
            if (fee > 0) IERC20(_erc20payment).transferFrom(msg.sender, address(this), fee);
        }
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
        _rents[_erc1155][_tokenId][_ownerOf].push(TokenRentInfo({
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

    function _getUserRentedItems(address _ownerOf, address _erc1155, uint256 _tokenId) internal view returns(uint256 amount) {
        TokenRentInfo[] memory rents = _rents[_erc1155][_tokenId][_ownerOf];
        for (uint i=0; i<rents.length; i++) {
            amount += rents[i].amount;
        }
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0));
        owner = _newOwner;
    }

    function _getFee() internal view returns(uint256) {
        uint256 numTokensStaked = IBlizztStake(blizztStake).balanceOf(msg.sender) / 10 ** 18;
        if (numTokensStaked >= maxStakedTokens) return minFee;
        return maxFee - ((maxFee - minFee) * numTokensStaked / maxStakedTokens);
    }

    function getFee() external view returns(uint256) {
        return _getFee();
    }

    function withdrawFees(address _token) external onlyOwner {
        uint256 balance;
        if (_token == address(0)) {
            balance = address(this).balance;
            payable(feesWallet).transfer(balance);
        } else {
            IERC20 erc20 = IERC20(_token);
            balance = erc20.balanceOf(address(this));
            erc20.transfer(feesWallet, balance);
        }

        emit WithdrawFees(msg.sender, balance);
    }

    /** 
     * @notice Change the marketplace fees
     * @param _minFee               --> 
     * @param _maxFee               --> 
     * @param _maxStakedTokens      --> 
     */
    function changeFees(uint24 _minFee, uint24 _maxFee, uint24 _maxStakedTokens) external onlyOwner {
        minFee = _minFee;
        maxFee = _maxFee;
        maxStakedTokens = _maxStakedTokens;
    }

    /** 
     * @notice Change the Blizzt stake contract
     * @param _newBlizztStake       --> 
     */
    function updateBlizztStake(address _newBlizztStake) external onlyOwner {
        blizztStake = _newBlizztStake;
    }
}
