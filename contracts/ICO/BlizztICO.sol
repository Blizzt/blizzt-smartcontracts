// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IUniswapV2Router02.sol";

contract BlizztICO {

    address immutable private blizztWallet;                     // Blizzt master wallet
    address immutable private blizztToken;                      // Blizzt token address
    address immutable private usdtToken;                        // USDT token address
    address immutable private usdcToken;                        // USDC token address
    uint256 immutable private maxICOTokens;                     // Max ICO tokens to sell
    uint256 immutable private icoStartDate;                     // ICO start date
    uint256 immutable private icoEndDate;                       // ICO end date
    uint256 immutable private priceICO;                         // ICO start date
    AggregatorV3Interface internal priceFeed;                   // Chainlink price feeder ETH/USD
    IUniswapV2Router02 immutable private uniswapRouter;

    mapping(address => uint256) private userBoughtTokens;       // Mapping to store all the buys
    mapping(address => uint256) private userWithdrawTokens;     // Mapping to store the user tokens withdraw

    uint256 public icoTokensBought;                             // Tokens sold
    uint256 public tokenListingDate;                            // Token listing date

    bool private icoFinished;
    uint32 internal constant _1_MONTH_IN_SECONDS = 2592000;
    uint32 internal constant _3_MONTHS_IN_SECONDS = 3 * _1_MONTH_IN_SECONDS;
    uint32 internal constant _6_MONTHS_IN_SECONDS = 6 * _1_MONTH_IN_SECONDS;
    uint32 internal constant _9_MONTHS_IN_SECONDS = 9 * _1_MONTH_IN_SECONDS;

    event onTokensBought(address _buyer, uint256 _tokens, uint256 _paymentAmount, address _tokenPayment);
    event onWithdrawICOFunds(uint256 _usdtBalance, uint256 _usdcBalance, uint256 _ethbalance);
    event onICOFinished(uint256 _date);
    event onTokenListed(uint256 _ethOnUniswap, uint256 _tokensOnUniswap, uint256 _date);

    event onDebug(uint256 usdETH, uint256 paidUSD, uint256 paidTokens, uint256 availableTokens, bool lastTokens, uint256 amountToPay);

    /**
     * @notice Constructor
     * @param _wallet               --> Xifra master wallet
     * @param _token                --> Xifra token address
     * @param _icoStartDate         --> ICO start date
     * @param _icoEndDate           --> ICO end date
     * @param _usdtToken            --> USDT token address
     * @param _usdcToken            --> USDC token address
     * @param _maxICOTokens         --> Number of tokens selling in this ICO
     * @param _priceICO             --> 
     * @param _uniswapRouter        -->
     */
    constructor(address _wallet, address _token, uint256 _icoStartDate, uint256 _icoEndDate, address _usdtToken, address _usdcToken, uint256 _maxICOTokens, uint256 _priceICO, address _uniswapRouter) {
        blizztWallet = _wallet;
        blizztToken = _token;
        icoStartDate = _icoStartDate;
        icoEndDate = _icoEndDate;
        usdtToken = _usdtToken;
        usdcToken = _usdcToken;
        maxICOTokens = _maxICOTokens;
        priceICO = _priceICO;
        if (_getChainId() == 1) priceFeed = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
        else if (_getChainId() == 4) priceFeed = AggregatorV3Interface(0x8A753747A1Fa494EC906cE90E9f37563A8AF630e);
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
    }

    /**
     * @notice Buy function. Used to buy tokens using ETH, USDT or USDC
     * @param _paymentAmount    --> Result of multiply number of tokens to buy per price per token. Must be always multiplied per 1000 to avoid decimals 
     * @param _tokenPayment     --> Address of the payment token (or 0x0 if payment is ETH)
     */
    function buy(uint256 _paymentAmount, address _tokenPayment) external payable {
        require(_isICOActive() == true, "ICONotActive");

        uint256 tokensBought;

        if (msg.value == 0) {
            // Stable coin payment
            (tokensBought, icoFinished) = _buyTokensWithStableCoin(_paymentAmount, _tokenPayment);

        } else {
            // ETH Payment
            (tokensBought, icoFinished) = _buyTokensWithETH();
        }

        // Add tokens to the user vesting
        userBoughtTokens[msg.sender] += tokensBought;
        icoTokensBought += tokensBought;
        
        //emit onTokensBought(msg.sender, tokensBought, _paymentAmount, _tokenPayment);

        if (icoFinished) emit onICOFinished(block.timestamp);
    }

    /**
     * @notice Returns the crypto numbers and balance in the ICO contract
     */
    function withdrawICOFunds() external {
        require(_isICOActive() == false, "ICONotActive");
        
        uint256 usdtBalance = IERC20(usdtToken).balanceOf(address(this));
        require(IERC20(usdtToken).transfer(blizztWallet, usdtBalance));

        uint256 usdcBalance = IERC20(usdcToken).balanceOf(address(this));
        require(IERC20(usdcToken).transfer(blizztWallet, usdcBalance));

        uint256 ethbalance = address(this).balance;
        payable(blizztWallet).transfer(ethbalance);

        emit onWithdrawICOFunds(usdtBalance, usdcBalance, ethbalance);
    }

    /**
    * @dev This function prepares the staking and bonus reward settings
    * and it also provides liquidity to a freshly created uniswap pair.
    */  
    function listTokenInUniswapAndStake() external {
        require(icoFinished, "all rounds must have ended");
        require(tokenListingDate == 0, "the bonus offering and uniswap paring can only be done once per ISO");
                   
        uint256 unsoldSupply = maxICOTokens - icoTokensBought;
        
        (uint256 ethOnUniswap, uint256 tokensOnUniswap) = _createUniswapPair(); 
        
        tokenListingDate = block.timestamp;
        payable(blizztWallet).transfer(address(this).balance);
        
        //_distribute(unsoldSupply + exceededBonus + exceededUniswapAmount);
        
        emit onTokenListed(ethOnUniswap, tokensOnUniswap, block.timestamp);
    }

    /**
    * @dev This function creates a uniswap pair and handles liquidity provisioning.
    * Returns the uniswap token leftovers.
    */  
    function _createUniswapPair() internal returns (uint256, uint256) {
        uint256 ethOnUniswap = address(this).balance / 3;
        uint256 ETHUSDPrice = _getUSDETHPrice();
        uint256 ethValue = ethOnUniswap * ETHUSDPrice / (10 ** 18);
        uint256 tokenListingPrice = 10000;    // 0.01$ per token
        uint256 tokensOnUniswap = ethOnUniswap * tokenListingPrice;

        IERC20(blizztToken).approve(address(uniswapRouter), tokensOnUniswap);
      
        uniswapRouter.addLiquidityETH{value: ethOnUniswap}(
            blizztToken,
            tokensOnUniswap,
            0,
            0,
            blizztWallet,
            block.timestamp
        );

        return (ethOnUniswap, tokensOnUniswap);
    }

    /**
     * @notice Returns the number of tokens and user has bought
     * @param _user --> User account
     * @return Returns the user token balance in wei units
     */
    function getUserBoughtTokens(address _user) external view returns(uint256) {
        return userBoughtTokens[_user];
    }

    /**
     * @notice Returns the number of tokens and user has withdrawn
     * @param _user --> User account
     * @return Returns the user token withdrawns in wei units
     */
    function getUserWithdrawnTokens(address _user) external view returns(uint256) {
        return userWithdrawTokens[_user];
    }

    /**
     * @notice Returns the crypto numbers in the ICO
     * @return blizzt Returns the Blizzt tokens balance in the contract
     * @return eth Returns the ETHs balance in the contract
     * @return usdt Returns the USDTs balance in the contract
     * @return usdc Returns the USDCs balance in the contract
     */
    function getICOData() external view returns(uint256 blizzt, uint256 eth, uint256 usdt, uint256 usdc) {
        blizzt = IERC20(blizztToken).balanceOf(address(this));
        usdt = IERC20(usdtToken).balanceOf(address(this));
        usdc = IERC20(usdcToken).balanceOf(address(this));
        eth = address(this).balance;
    }

    /**
     * @notice Traslate a payment in USD to ETHs
     * @param _paymentAmount --> Payment amount in USD
     * @return Returns the ETH amount in weis
     */
    function calculateETHPayment(uint256 _paymentAmount) external view returns(uint256) {
        uint256 usdETH = _getUSDETHPrice();
        return (_paymentAmount * 10 ** 18) / usdETH;
    }

    /**
     * @notice Get the vesting unlock dates
     * @param _period --> There are 4 periods (0,1,2,3)
     * @return _date Returns the date in UnixDateTime UTC format
     */
    function getVestingDate(uint256 _period) external view returns(uint256 _date) {
        if (_period == 0) {
            _date = tokenListingDate;
        } else if (_period == 1) {
            _date = tokenListingDate + _3_MONTHS_IN_SECONDS;
        } else if (_period == 2) {
            _date = tokenListingDate + _6_MONTHS_IN_SECONDS;
        } else if (_period == 3) {
            _date = tokenListingDate + _9_MONTHS_IN_SECONDS;
        }
    }

    /**
     * @notice Public function that returns ETHUSD par
     * @return Returns the how much USDs are in 1 ETH in weis
     */
    function getUSDETHPrice() external view returns(uint256) {
        return _getUSDETHPrice();
    }

    /**
     * @notice Uses Chainlink to query the USDETH price
     * @return Returns the ETH amount in weis (Fixed value of 3932.4 USDs in localhost development environments)
     */
    function _getUSDETHPrice() internal view returns(uint256) {
        int price = 0;

        if (address(priceFeed) != address(0)) {
            (, price, , , ) = priceFeed.latestRoundData();
        } else {
            // For local testing
            price = 393240000000;
        }

        return uint256(price * 10**10);
    }

    /**
     * @notice Internal function that queries the chainId
     * @return Returns the chainId (1 - Mainnet, 4 - Rinkeby testnet)
     */
    function _getChainId() internal view returns (uint256) {
        uint256 chainId;
        assembly { chainId := chainid() }
        return chainId;
    }

    function _buyTokensWithStableCoin(uint256 _paymentAmount, address _tokenPayment) internal returns (uint256, bool) {
        require(_paymentAmount > 0, "BadPayment");
        require(_tokenPayment == usdtToken || _tokenPayment == usdcToken, "TokenNotSupported");
        
        uint256 amountToPay = 0;
        uint256 paidTokens = _paymentAmount * priceICO;
        uint256 availableTokens = maxICOTokens - icoTokensBought;
        bool lastTokens = (availableTokens < paidTokens);
        if (lastTokens) {
            amountToPay = availableTokens * priceICO; // Last tokens in the contract
        } else {
            amountToPay = paidTokens * priceICO;
        }
        
        require(IERC20(_tokenPayment).transferFrom(msg.sender, address(this), amountToPay));

        return (amountToPay, lastTokens);
    }

    function _buyTokensWithETH() internal returns (uint256, bool) {
        uint256 usdETH = _getUSDETHPrice();
        uint256 paidUSD = msg.value * usdETH / 10**18;
        uint256 paidTokens = paidUSD * priceICO;
        uint256 availableTokens = maxICOTokens - icoTokensBought;
        bool lastTokens = (availableTokens < paidTokens);
        if (lastTokens) {
            uint256 realAmountToPay = msg.value * availableTokens / paidTokens;
            paidTokens = availableTokens;
            payable(msg.sender).transfer(msg.value - realAmountToPay);  // Return ETHs for the tokens user couldn't buy
        }
        emit onDebug(usdETH, paidUSD, paidTokens, availableTokens, lastTokens, 0);

        return (paidTokens, lastTokens);
    }

    /**
     * @notice Internal - Is ICO active?
     * @return Returns true or false
     */
    function _isICOActive() internal view returns(bool) {
        if ((block.timestamp < icoStartDate) || (block.timestamp > icoEndDate) || (icoFinished == true)) return false;
        else return true;
    }

    /**
     * @notice External - Is ICO active?
     * @return Returns true or false
     */
    function isICOActive() external view returns(bool) {
        return _isICOActive();
    }

    receive() external payable {
        // Call function buy if someone sends directly ethers to the contract
        uint256 tokensBought;
        (tokensBought, icoFinished) = _buyTokensWithETH();

        // TODO. Send tokens to the vesting contract
        IERC20(blizztToken).transfer(msg.sender, tokensBought);
        
        emit onTokensBought(msg.sender, tokensBought, msg.value, 0x0000000000000000000000000000000000000000);

        if (icoFinished) emit onICOFinished(block.timestamp);
    }
}