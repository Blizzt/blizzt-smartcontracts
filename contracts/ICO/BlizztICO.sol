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
    address immutable private usdtToken;                        // USDT token address
    address immutable private ethToken;                         // ETH token address
    address immutable private wbtcToken;                        // WBTC token address
    uint256 immutable private maxICOTokens;                     // Max ICO tokens to sell
    uint256 immutable private icoStartDate;                     // ICO start date
    uint256 immutable private icoEndDate;                       // ICO end date
    uint256 immutable private tokensPerDollar;                  // ICO tokens per $ invested
    AggregatorV3Interface private priceFeedETHUSD;              // Chainlink price feeder ETH/USD
    AggregatorV3Interface private priceFeedMATICUSD;            // Chainlink price feeder MATIC/USD
    AggregatorV3Interface private priceFeedWBTCUSD;             // Chainlink price feeder WBTC/USD
    IUniswapV2Router02 immutable private uniswapRouter;

    uint256 public icoTokensBought;                             // Tokens sold
    uint256 public tokenListingDate;                            // Token listing date

    bool private icoFinished;
    uint32 internal constant _1_YEAR_BLOCKS = 2300000;          // Calculated with an average of 6400 blocks/day

    event onTokensBought(address _buyer, uint256 _tokens, uint256 _paymentAmount, address _tokenPayment);
    event onWithdrawICOFunds(uint256 _maticbalance, uint256 _ethBalance, uint256 _usdtBalance, uint256 _wbtcBalance);
    event onICOFinished(uint256 _date);
    event onTokenListed(uint256 _ethOnUniswap, uint256 _tokensOnUniswap, uint256 _date);

    /**
     * @notice Constructor
     * @param _wallet               --> Blizzt master wallet
     * @param _token                --> Blizzt token address
     * @param _icoStartDate         --> ICO start date
     * @param _icoEndDate           --> ICO end date
     * @param _usdtToken            --> USDT token address
     * @param _ethToken             --> ETH token address
     * @param _wbtcToken            --> WBTC token address
     * @param _maxICOTokens         --> Number of tokens selling in this ICO
     * @param _tokensPerDollar             --> 
     * @param _uniswapRouter        -->
     */
    constructor(address _wallet, address _token, address _farm, uint256 _icoStartDate, uint256 _icoEndDate, address _usdtToken, address _ethToken, address _wbtcToken, uint256 _maxICOTokens, uint256 _tokensPerDollar, address _uniswapRouter) {
        blizztWallet = _wallet;
        blizztToken = _token;
        blizztFarm = _farm;
        icoStartDate = _icoStartDate;
        icoEndDate = _icoEndDate;
        usdtToken = _usdtToken;
        ethToken = _ethToken;
        wbtcToken = _wbtcToken;
        maxICOTokens = _maxICOTokens;
        tokensPerDollar = _tokensPerDollar;
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        _setPriceFeeders();

        IERC20(_token).approve(_farm, _maxICOTokens);
    }

    /**
     * @notice Buy function. Used to buy tokens using ETH, USDT or USDC
     * @param _paymentAmount    --> Result of multiply number of tokens to buy per price per token. Must be always multiplied per 1000 to avoid decimals 
     * @param _tokenPayment     --> Address of the payment token (or 0x0 if payment is ETH)
     */
    function buy(uint256 _paymentAmount, address _tokenPayment) external payable {
        require(_isICOActive() == true, "ICONotActive");

        uint256 tokensBought;
        uint256 paid;

        if (msg.value == 0) {
            // Stable coin payment
            (tokensBought, paid, icoFinished) = _buyTokensWithTokens(_paymentAmount, _tokenPayment);

        } else {
            // MATIC Payment
            (tokensBought, paid, icoFinished) = _buyTokensWithMATIC();
        }

        // Send the tokens to the farm contract
        IBlizztFarm(blizztFarm).deposit(msg.sender, tokensBought);
        icoTokensBought += tokensBought;
        
        emit onTokensBought(msg.sender, tokensBought, paid, _tokenPayment);

        if (icoFinished) emit onICOFinished(block.timestamp);
    }

    /**
    * @dev This function prepares the staking and bonus reward settings
    * and it also provides liquidity to a freshly created uniswap pair.
    */  
    function listTokenInUniswapAndStake() external {
        require(icoFinished, "all rounds must have ended");
        require(tokenListingDate == 0, "the bonus offering and uniswap paring can only be done once per ISO");

        (uint256 ethOnUniswap, uint256 tokensOnUniswap) = _createUniswapPair(); 
        
        tokenListingDate = block.timestamp;
        payable(blizztWallet).transfer(address(this).balance);
        
        _setupFarm();
        
        emit onTokenListed(ethOnUniswap, tokensOnUniswap, block.timestamp);
    }

    function _convertUniswapToMATIC(uint256 _amount, address _token) internal {
        address[] memory path = new address[](2);
        path[0] = _token;
        path[1] = uniswapRouter.WETH();

        IERC20(_token).approve(address(uniswapRouter), _amount);

        // ERROR. No existe liquidez para este par en Uniswap y por eso falla el SmartContract aqui
        /*
        uniswapRouter.swapExactTokensForETH(
            _amount,
            0,  // TODO. Protect against flashloans (only call from an account, not an smartcontract)
            path,
            address(this),
            block.timestamp
        );
        */
    }

    function _setupFarm() internal {
        IBlizztFarm(blizztFarm).initialSetup(block.number, _1_YEAR_BLOCKS);
        IBlizztFarm(blizztFarm).add(1, blizztToken);
        
        uint256 balance = IERC20(blizztToken).balanceOf(address(this));
        if (balance > 0) {
            IERC20(blizztToken).approve(blizztFarm, balance);
            IBlizztFarm(blizztFarm).fund(balance);
        }
    }

    event onDebug(uint256 maticOnUniswap, uint256 maticUSD, uint256 usdUniswapInMATICs, uint256 tokensOnUniswap);

    /**
    * @dev This function creates a uniswap pair and handles liquidity provisioning.
    * Returns the uniswap token leftovers.
    */  
    function _createUniswapPair() internal returns (uint256, uint256) {
        uint256 usdtBalance = IERC20(usdtToken).balanceOf(address(this));
        if (usdtBalance > 0) _convertUniswapToMATIC(usdtBalance, usdtToken);
        uint256 wbtcBalance = IERC20(wbtcToken).balanceOf(address(this));
        if (wbtcBalance > 0) _convertUniswapToMATIC(wbtcBalance, wbtcToken);
        uint256 ethBalance = IERC20(ethToken).balanceOf(address(this));
        if (ethBalance > 0) _convertUniswapToMATIC(ethBalance, ethToken);
        
        uint256 maticOnUniswap = address(this).balance / 3;
        uint256 maticUSD = _getUSDMATICPrice();
        uint256 usdUniswapInMATICs = maticOnUniswap * maticUSD / 10 ** 18;
        uint256 tokensOnUniswap = usdUniswapInMATICs * tokensPerDollar; // TODO. 0.01$ per token;

        IERC20(blizztToken).approve(address(uniswapRouter), tokensOnUniswap);
      
        emit onDebug(maticOnUniswap, maticUSD, usdUniswapInMATICs, tokensOnUniswap);

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
     * @return eth Returns the ETHs balance in the contract
     * @return usdt Returns the USDTs balance in the contract
     * @return wbtc Returns the WBTCs balance in the contract
     */
    function getICOData() external view returns(uint256 blizzt, uint256 matic, uint256 eth, uint256 usdt, uint256 wbtc) {
        blizzt = IERC20(blizztToken).balanceOf(address(this));
        usdt = IERC20(usdtToken).balanceOf(address(this));
        wbtc = IERC20(wbtcToken).balanceOf(address(this));
        eth = IERC20(ethToken).balanceOf(address(this));
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
     * @notice Public function that returns Token/USD par
     * @return Returns the how much USDs are in 1 Token in weis
     */
    function getUSDTokenPrice(address _token) external view returns(uint256) {
        return _getUSDTokenPrice(_token);
    }

    /**
     * @notice Uses Chainlink to query the USDETH price
     * @return Returns the ETH amount in weis (Fixed value of 3932.4 USDs in localhost development environments)
     */
    function _getUSDMATICPrice() internal view returns(uint256) {
        (, int price, , , ) = priceFeedMATICUSD.latestRoundData();

        return uint256(price * 10**10);
    }

    function _getUSDTokenPrice(address _token) internal view returns(uint256) {
        int price = 0;
        if (_token == ethToken) {
            (, price, , , ) = priceFeedETHUSD.latestRoundData();
        } else if (_token == usdtToken) {
            price = 100000000;
        } else if (_token == wbtcToken) {
            (, price, , , ) = priceFeedWBTCUSD.latestRoundData();
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

    function _buyTokensWithTokens(uint256 _paymentAmount, address _tokenPayment) internal returns (uint256, uint256, bool) {
        require(_paymentAmount > 0, "BadPayment");
        require(_tokenPayment == ethToken || _tokenPayment == usdtToken || _tokenPayment == wbtcToken, "TokenNotSupported");
        
        uint256 amountToPay = _paymentAmount;
        uint256 tokenUSDs = _getUSDTokenPrice(_tokenPayment);
        uint256 paidUSD = tokenUSDs * _paymentAmount / 10**18;
        uint256 paidTokens = paidUSD * tokensPerDollar;
        uint256 availableTokens = maxICOTokens - icoTokensBought;
        bool lastTokens = (availableTokens < paidTokens);
        if (lastTokens) {
            paidUSD = availableTokens * paidUSD / paidTokens;
            paidTokens = availableTokens;
            amountToPay = paidUSD * 10 ** 18 / tokenUSDs;
        }
       
        require(IERC20(_tokenPayment).transferFrom(msg.sender, address(this), amountToPay));

        return (paidTokens, amountToPay, lastTokens);
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

    function _setPriceFeeders() internal {
        uint256 chainId = _getChainId();
        if (chainId == 1) {
            priceFeedETHUSD = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
            priceFeedMATICUSD = AggregatorV3Interface(0x7bAC85A8a13A4BcD8abb3eB7d6b4d632c5a57676);
            priceFeedWBTCUSD = AggregatorV3Interface(0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c);
        } else if (chainId == 4) {
            priceFeedETHUSD = AggregatorV3Interface(0x8A753747A1Fa494EC906cE90E9f37563A8AF630e);
            priceFeedMATICUSD = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
            priceFeedWBTCUSD = AggregatorV3Interface(0xa24de01df22b63d23Ebc1882a5E3d4ec0d907bFB);
        }
    }

    receive() external payable {
        // Call function buy if someone sends directly ethers to the contract
        uint256 tokensBought;
        uint256 paid;
        (tokensBought, paid, icoFinished) = _buyTokensWithMATIC();

        // TODO. Send tokens to the vesting contract
        IERC20(blizztToken).transfer(msg.sender, tokensBought);
        
        emit onTokensBought(msg.sender, tokensBought, paid, 0x0000000000000000000000000000000000000000);

        if (icoFinished) emit onICOFinished(block.timestamp);
    }
}