// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IBlizztFarm.sol";
import "../interfaces/IUniswapV2Router02.sol";

contract BlizztICO {

    address immutable private blizztWallet;                     // Blizzt master wallet
    address immutable private blizztToken;                      // Blizzt token address
    address immutable private blizztFarm;                       // Blizzt ICO farm
    uint256 immutable private maxICOTokens;                     // Max ICO tokens to sell
    uint256 immutable private icoStartDate;                     // ICO start date
    uint256 immutable private icoEndDate;                       // ICO end date
    uint256 immutable private tokensPerDollar;                  // ICO tokens per $ invested
    AggregatorV3Interface private priceFeedMATICUSD;            // Chainlink price feeder MATIC/USD
    IUniswapV2Router02 immutable private uniswapRouter;

    uint256 public icoTokensBought;                             // Tokens sold
    uint256 public tokenListingDate;                            // Token listing date

    uint64 private icoFinishedDate;
    uint32 internal constant _1_YEAR_BLOCKS = 2300000;          // Calculated with an average of 6400 blocks/day

    event onTokensBought(address _buyer, uint256 _tokens, uint256 _paymentAmount);
    event onWithdrawICOFunds(uint256 _maticbalance);
    event onICOFinished(uint256 _date);
    event onTokenListed(uint256 _ethOnUniswap, uint256 _tokensOnUniswap, uint256 _date);

    /**
     * @notice Constructor
     * @param _wallet               --> Blizzt master wallet
     * @param _token                --> Blizzt token address
     * @param _icoStartDate         --> ICO start date
     * @param _icoEndDate           --> ICO end date
     * @param _maxICOTokens         --> Number of tokens selling in this ICO
     * @param _tokensPerDollar      --> 
     * @param _uniswapRouter        -->
     */
    constructor(address _wallet, address _token, address _farm, uint256 _icoStartDate, uint256 _icoEndDate, uint256 _maxICOTokens, uint256 _tokensPerDollar, address _uniswapRouter) {
        blizztWallet = _wallet;
        blizztToken = _token;
        blizztFarm = _farm;
        icoStartDate = _icoStartDate;
        icoEndDate = _icoEndDate;
        maxICOTokens = _maxICOTokens;
        tokensPerDollar = _tokensPerDollar;
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        _setPriceFeeders();

        IERC20(_token).approve(_farm, _maxICOTokens);
    }

    /**
     * @notice Buy function. Used to buy tokens using MATIC
     */
    function buy() external payable {
        _buy();
    }

    /**
    * @notice This function automates the token listing in Quickswap
    * and initializes the rewards farm for the ICO buyers
    */  
    function listTokenInUniswapAndStake() external {
        require(_isICOActive() == false, "ico is not ended");
        require(tokenListingDate == 0, "the bonus offering and uniswap paring can only be done once per ISO");
        //require(block.timestamp > icoFinishedDate + 30 days, "30 days until listing");    // TODO. Removed for testing

        (uint256 ethOnUniswap, uint256 tokensOnUniswap) = _createUniswapPair(); 
        
        tokenListingDate = block.timestamp;

        payable(blizztWallet).transfer(address(this).balance);
        
        _setupFarm();
        
        emit onTokenListed(ethOnUniswap, tokensOnUniswap, block.timestamp);
    }

    /**
    * @notice Call by anyone if the ICO finish without sell all the tokens
    */  
    function closeICO() external {
        if ((block.timestamp > icoEndDate) && (icoFinishedDate == 0)) {
            icoFinishedDate = uint64(icoEndDate);
        }
    }

    /**
     * @notice Returns the number of tokens and user has bought
     * @param _user --> User account
     * @return Returns the user token balance in wei units
     */
    function getUserBoughtTokens(address _user) external view returns(uint256) {
        return IBlizztFarm(blizztFarm).deposited(_user);
    }

    /**
     * @notice Returns the crypto numbers in the ICO
     * @return blizzt Returns the Blizzt tokens balance in the contract
     * @return matic Returns the MATICs balance in the contract
     */
    function getICOData() external view returns(uint256 blizzt, uint256 matic) {
        blizzt = IERC20(blizztToken).balanceOf(address(this));
        matic = address(this).balance;
    }

    /**
     * @notice Public function that returns ETHUSD par
     * @return Returns the how much USDs are in 1 ETH in weis
     */
    function getUSDMATICPrice() external view returns(uint256) {
        return _getUSDMATICPrice();
    }

    /**
     * @notice External - Is ICO active?
     * @return Returns true or false
     */
    function isICOActive() external view returns(bool) {
        return _isICOActive();
    }

    function _buy() internal {
        require(_isICOActive() == true, "ICONotActive");

        // Buy Blizzt tokens with MATIC
        (uint256 tokensBought, uint256 paid, bool icoFinished) = _buyTokensWithMATIC();

        // Send the tokens to the farm contract
        IBlizztFarm(blizztFarm).deposit(msg.sender, tokensBought);
        icoTokensBought += tokensBought;
        
        emit onTokensBought(msg.sender, tokensBought, paid);

        if (icoFinished) {
            icoFinishedDate = uint64(block.timestamp);
            emit onICOFinished(block.timestamp);
        }
    }

    function _buyTokensWithMATIC() internal returns (uint256, uint256, bool) {
        uint256 usdMATIC = _getUSDMATICPrice();
        uint256 amountToPay = msg.value;
        uint256 paidUSD = msg.value * usdMATIC / 10**18;
        uint256 paidTokens = paidUSD * tokensPerDollar;
        uint256 availableTokens = maxICOTokens - icoTokensBought;
        bool lastTokens = (availableTokens < paidTokens);
        if (lastTokens) {
            paidUSD = availableTokens * paidUSD / paidTokens;
            paidTokens = availableTokens;
            amountToPay = paidUSD * 10 ** 18 / usdMATIC;
            
            payable(msg.sender).transfer(msg.value - amountToPay);  // Return ETHs for the tokens user couldn't buy
        }

        return (paidTokens, amountToPay, lastTokens);
    }

    /**
    * @dev This function creates a uniswap pair and handles liquidity provisioning.
    * Returns the uniswap token leftovers.
    */  
    function _createUniswapPair() internal returns (uint256, uint256) {     
        uint256 maticOnUniswap = address(this).balance / 3;
        uint256 tokensOnUniswap = icoTokensBought / 3;

        IERC20(blizztToken).approve(address(uniswapRouter), tokensOnUniswap);
      
        uniswapRouter.addLiquidityETH{value: maticOnUniswap}(
            blizztToken,
            tokensOnUniswap,
            0,
            0,
            blizztWallet,
            block.timestamp
        );

        return (maticOnUniswap, tokensOnUniswap);
    }

    function _setupFarm() internal {
        IBlizztFarm(blizztFarm).initialSetup(block.number, _1_YEAR_BLOCKS);
        IBlizztFarm(blizztFarm).add(1, blizztToken);
        
        // 10% extra rewards for staking in the farm until the end
        uint256 tokensToFarm = icoTokensBought / 10;
        IERC20(blizztToken).approve(blizztFarm, tokensToFarm);
        IBlizztFarm(blizztFarm).fund(tokensToFarm);
    }

    /**
     * @notice Uses Chainlink to query the USDETH price
     * @return Returns the ETH amount in weis
     */
    function _getUSDMATICPrice() internal view returns(uint256) {
        (, int price, , , ) = priceFeedMATICUSD.latestRoundData();

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

    /**
     * @notice Internal - Is ICO active?
     * @return Returns true or false
     */
    function _isICOActive() internal view returns(bool) {
        if ((block.timestamp < icoStartDate) || (block.timestamp > icoEndDate) || (icoFinishedDate > 0)) return false;
        else return true;
    }

    function _setPriceFeeders() internal {
        uint256 chainId = _getChainId();
        if (chainId == 1) {
            priceFeedMATICUSD = AggregatorV3Interface(0x7bAC85A8a13A4BcD8abb3eB7d6b4d632c5a57676);
        } else if (chainId == 4) {
            priceFeedMATICUSD = AggregatorV3Interface(0x7794ee502922e2b723432DDD852B3C30A911F021);
        }
    }

    receive() external payable {
        // Call function buy if someone sends directly ethers to the contract
        _buy();
    }
}