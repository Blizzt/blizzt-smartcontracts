// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../interfaces/IUniswapV2Router02.sol";
import "../interfaces/IBlizztToken.sol";

contract UnistakeICO {

    struct Contributor {
        uint256 phase;
        uint256 remainder;
        uint256 fromTotalDivs;
    }

    address payable public immutable wallet;

    uint256 public immutable totalSupplyR1;
    uint256 public immutable totalSupplyR2;
    uint256 public immutable totalSupplyR3;

    uint256 public immutable totalSupplyUniswap;

    uint256 public immutable rateR1;
    uint256 public immutable rateR2;
    uint256 public immutable rateR3;

    uint256 public immutable periodDurationR3;

    uint256 public immutable timeDelayR1;
    uint256 public immutable timeDelayR2;

    uint256 public immutable stakingPeriodR1;
    uint256 public immutable stakingPeriodR2;
    uint256 public immutable stakingPeriodR3;

    IBlizztToken public immutable token;
    IUniswapV2Router02 public immutable uniswapRouter;

    uint256 public immutable listingRate;
    address public immutable platformStakingContract;

    bool[3]    private _hasEnded;
    uint256[3] private _actualSupply;

    uint256 private _endedDayR3;

    uint256 private _latestStakingPlatformPayment;

    mapping(address => bool)[3] private _hasWithdrawn;

    bool    private _bonusOfferingActive;
    uint256 private _bonusOfferingActivated;
    uint256 private _bonusTotal;

    mapping(address => bool)        private _contributor;
    mapping(address => Contributor) private _contributors;
    mapping(address => uint256)[3]  private _contributions;

    uint256 private _contributionsTotal;

    uint256 private _contributorsTotal;
    uint256 private _contributedFundsTotal;

    uint256 private _startTimeR2 = 2**256 - 1;
    uint256 private _startTimeR3 = 2**256 - 1;
    uint256 private _endTimeR3   = 2**256 - 1;

    mapping(address => uint256) private _restkedDividends;
    mapping(uint256 => uint256) private _payouts;

    uint256 private _totalDividends;
    uint256 private _scaledRemainder;
    uint256 private _scaling = uint256(10) ** 12;
    uint256 private _phase = 1;
    uint256 private _totalRestakedDividends;

    uint256 private _fundsWithdrawn;

    event Staked(
        address indexed account, 
        uint256 amount);

    event Claimed(
        address indexed account, 
        uint256 amount);

    event Reclaimed(
        address indexed account, 
        uint256 amount);

    event Splitted(
        address indexed account, 
        uint256 amount1, 
        uint256 amount2);  

    event Bought(
        uint8 indexed round, 
        address indexed account,
        uint256 amount);

    event Activated(
        bool status, 
        uint256 time);

    event Ended(
        address indexed account, 
        uint256 amount, 
        uint256 time);


    /* 
    * @dev Initialization of the ISO,
    * following arguments are provided via the constructor: 
    * ----------------------------------------------------
    * tokenArg                    - token offered in the ISO.
    * totalSupplyArg              - total amount of tokens allocated for each round.
    * totalSupplyUniswapArg       - amount of tokens that will be sent to uniswap.
    * ratesArg                    - contribution ratio ETH:Token for each round.
    * periodDurationR3Arg         - duration of a day during round 3.
    * timeDelayR1Arg              - time delay between round 1 and round 2.
    * timeDelayR2Arg              - time delay between round 2 and round 3.
    * stakingPeriodArg            - staking duration required to get bonus tokens for each round.
    * uniswapRouterArg            - contract address of the uniswap router object.
    * listingRateArg              - initial listing rate of the offered token.
    * platformStakingContractArg  - contract address of the timed distribution contract.
    * walletArg                   - account address of the team wallet.
    */
    constructor(
        address tokenArg,                   // Address token
        uint256[3] memory totalSupplyArg,   // Supply for the three rounds
        uint256 totalSupplyUniswapArg,      // Tokens to uniswap
        uint256[3] memory ratesArg,         // Tokens per ETH in each round
        uint256 periodDurationR3Arg,        // Maximum R3 duration
        uint256 timeDelayR1Arg,             // Delay Round1
        uint256 timeDelayR2Arg,             // Delay Round 2
        uint256[3] memory stakingPeriodArg, // Staking periods (30,60,90,120)
        address uniswapRouterArg,           // Uniswap router
        uint256 listingRateArg,             // Uniswap token price
        address platformStakingContractArg, // Stake contract address
        address payable walletArg           // Team wallet
    ) {
        // Sanity checks
        for (uint256 j = 0; j < 3; j++) {
            require(totalSupplyArg[j] > 0, "The 'totalSupplyArg' argument must be larger than zero");
            require(ratesArg[j] > 0, "The 'ratesArg' argument must be larger than zero");
            require(stakingPeriodArg[j] > 0, "The 'stakingPeriodArg' argument must be larger than zero");
        }

        require(totalSupplyUniswapArg > 0, "The 'totalSupplyUniswapArg' argument must be larger than zero");
        require(tokenArg != address(0), "The 'tokenArg' argument cannot be the zero address");
        require(uniswapRouterArg != address(0), "The 'uniswapRouterArg' argument cannot be the zero addresss");
        require(walletArg != address(0), "The 'walletArg' argument cannot be the zero address");

        // Initialize variables
        token = IBlizztToken(tokenArg);

        totalSupplyR1 = totalSupplyArg[0];
        totalSupplyR2 = totalSupplyArg[1];
        totalSupplyR3 = totalSupplyArg[2];

        totalSupplyUniswap = totalSupplyUniswapArg;

        uniswapRouter = IUniswapV2Router02(uniswapRouterArg);

        periodDurationR3 = periodDurationR3Arg;
    
        timeDelayR1 = timeDelayR1Arg;
        timeDelayR2 = timeDelayR2Arg;
    
        rateR1 = ratesArg[0];
        rateR2 = ratesArg[1];
        rateR3 = ratesArg[2];
    
        stakingPeriodR1 = stakingPeriodArg[0];
        stakingPeriodR2 = stakingPeriodArg[1];
        stakingPeriodR3 = stakingPeriodArg[2];

        listingRate = listingRateArg;

        platformStakingContract = platformStakingContractArg;
        wallet = walletArg;
    }

    /**
    * @dev The fallback function is used for all contributions
    * during the ISO. The function monitors the current 
    * round and manages token contributions accordingly.
    */
    receive() external payable {
        if (token.balanceOf(address(this)) > 0) {
            uint8 currentRound = _calculateCurrentRound();
            
            if (currentRound == 0) {
                _buyTokenR1();
            } else if (currentRound == 1) {
                _buyTokenR2();
            } else if (currentRound == 2) {
                _buyTokenR3();
            } else {
                revert("The stake offering rounds are not active");
            }
        } else {
            revert("The stake offering must be active");
        }
    }

    /**
    * @dev Wrapper around the round 3 closing function.
    */     
    function closeR3() external {
        uint256 period = _calculatePeriod(block.timestamp);
        _closeR3(period);
    }
  
    /**
    * @dev This function prepares the staking and bonus reward settings
    * and it also provides liquidity to a freshly created uniswap pair.
    */  
    function activateStakesAndUniswapLiquidity() external {
        require(_hasEnded[0] && _hasEnded[1] && _hasEnded[2], "all rounds must have ended");
        require(!_bonusOfferingActive, "the bonus offering and uniswap paring can only be done once per ISO");
        
        uint256[3] memory bonusSupplies = [
            _actualSupply[0],
            _actualSupply[1],
            _actualSupply[2]
            ];
            
        uint256 totalSupply = totalSupplyR1 + totalSupplyR2 + totalSupplyR3;
        uint256 soldSupply = _actualSupply[0] + _actualSupply[1] + _actualSupply[2];
        uint256 unsoldSupply = totalSupply - soldSupply;
            
        uint256 exceededBonus = totalSupply - bonusSupplies[0] - bonusSupplies[1] - bonusSupplies[2];
        
        uint256 exceededUniswapAmount = _createUniswapPair(_endedDayR3); 
        
        _bonusOfferingActive = true;
        _bonusOfferingActivated = block.timestamp;
        _bonusTotal = bonusSupplies[0] + bonusSupplies[1] + bonusSupplies[2];
        _contributionsTotal = soldSupply;
        
        _distribute(unsoldSupply + exceededBonus + exceededUniswapAmount);
        
        emit Activated(true, block.timestamp);
    }

    /**
    * @dev This function allows the caller to stake claimable dividends.
    */   
    function restakeDividends() external {
        uint256 pending = _pendingDividends(msg.sender);
        pending = pending + _contributors[msg.sender].remainder;
        require(pending >= 0, "You do not have dividends to restake");
        _restkedDividends[msg.sender] = _restkedDividends[msg.sender] + pending;
        _totalRestakedDividends = _totalRestakedDividends + pending;
        _bonusTotal = _bonusTotal - pending;

        _contributors[msg.sender].phase = _phase;
        _contributors[msg.sender].remainder = 0;
        _contributors[msg.sender].fromTotalDivs = _totalDividends;
        
        emit Staked(msg.sender, pending);
    }

    /**
    * @dev This function is called by contributors to 
    * withdraw round 1 tokens. 
    * -----------------------------------------------------
    * Withdrawing tokens might result in bonus tokens, dividends,
    * or similar (based on the staking duration of the contributor).
    * 
    */  
    function withdrawR1Tokens() external {
        require(_bonusOfferingActive, "The bonus offering is not active yet");
        
        _withdrawTokens(0);
    }
 
    /**
    * @dev This function is called by contributors to 
    * withdraw round 2 tokens. 
    * -----------------------------------------------------
    * Withdrawing tokens might result in bonus tokens, dividends,
    * or similar (based on the staking duration of the contributor).
    * 
    */      
    function withdrawR2Tokens() external {
        require(_bonusOfferingActive, "The bonus offering is not active yet");
        
        _withdrawTokens(1);
    }
 
    /**
    * @dev This function is called by contributors to 
    * withdraw round 3 tokens. 
    * -----------------------------------------------------
    * Withdrawing tokens might result in bonus tokens, dividends,
    * or similar (based on the staking duration of the contributor).
    * 
    */   
    function withdrawR3Tokens() external {
        require(_bonusOfferingActive, "The bonus offering is not active yet");  

        _withdrawTokens(2);
    }

    /**
    * @dev This function allows the caller to withdraw claimable dividends.
    */    
    function claimDividends() public {
        if (_totalDividends > _contributors[msg.sender].fromTotalDivs) {
            uint256 pending = _pendingDividends(msg.sender);
            pending = pending + _contributors[msg.sender].remainder;
            require(pending >= 0, "You do not have dividends to claim");
            
            _contributors[msg.sender].phase = _phase;
            _contributors[msg.sender].remainder = 0;
            _contributors[msg.sender].fromTotalDivs = _totalDividends;
            
            _bonusTotal = _bonusTotal - pending;

            require(token.transfer(msg.sender, pending), "Error in sending reward from contract");

            emit Claimed(msg.sender, pending);
        }
    }

    /**
    * @dev This function allows the caller to withdraw restaked dividends.
    */     
    function withdrawRestakedDividends() public {
        uint256 amount = _restkedDividends[msg.sender];
        require(amount >= 0, "You do not have restaked dividends to withdraw");
        
        claimDividends();
        
        _restkedDividends[msg.sender] = 0;
        _totalRestakedDividends = _totalRestakedDividends - amount;
        
        token.transfer(msg.sender, amount);      
        
        emit Reclaimed(msg.sender, amount);
    }

    /**
    * @dev Returns restaked dividends.
    */   
    function getRestakedDividends(address accountArg) public view returns (uint256) { 
        return _restkedDividends[accountArg];
    }

    /**
    * @dev Returns round 1 contributions of an account. 
    */  
    function getR1Contribution(address accountArg) public view returns (uint256) {
        return _contributions[0][accountArg];
    }
  
    /**
    * @dev Returns round 2 contributions of an account. 
    */    
    function getR2Contribution(address accountArg) public view returns (uint256) {
        return _contributions[1][accountArg];
    }
  
    /**
    * @dev Returns round 3 contributions of an account. 
    */  
    function getR3Contribution(address accountArg) public view returns (uint256) { 
        return _contributions[2][accountArg];
    }

    /**
    * @dev Returns the total contributions of an account. 
    */    
    function getContributionTotal(address accountArg) public view returns (uint256) {
        uint256 contributionR1 = getR1Contribution(accountArg);
        uint256 contributionR2 = getR2Contribution(accountArg);
        uint256 contributionR3 = getR3Contribution(accountArg);
        uint256 restaked = getRestakedDividends(accountArg);

        return contributionR1 + contributionR2 + contributionR3 + restaked;
    }

    /**
    * @dev Returns the current round of the ISO. 
    */  
    function getCurrentRound() external view returns (uint8) {
        uint8 round = _calculateCurrentRound();
        
        if (round == 0 && !_hasEnded[0]) {
            return 1;
        } 
        if (round == 1 && !_hasEnded[1] && _hasEnded[0]) {
            if (block.timestamp <= _startTimeR2) {
                return 0;
            }
            return 2;
        }
        if (round == 2 && !_hasEnded[2] && _hasEnded[1]) {
            if (block.timestamp <= _startTimeR3) {
                return 0;
            }
            return 3;
        } 
        else {
            return 0;
        }
    }

    /**
    * @dev Returns whether round 1 has ended or not. 
    */   
    function hasR1Ended() external view returns (bool) {
        return _hasEnded[0];
    }

    /**
    * @dev Returns whether round 2 has ended or not. 
    */   
    function hasR2Ended() external view returns (bool) {
        return _hasEnded[1];
    }

    /**
    * @dev Returns whether round 3 has ended or not. 
    */   
    function hasR3Ended() external view returns (bool) { 
        return _hasEnded[2];
    }

    /**
    * @dev Returns the remaining time delay between round 1 and round 2.
    */    
    function getRemainingTimeDelayR1R2() external view returns (uint256) {
        if (timeDelayR1 > 0) {
            if (_hasEnded[0] && !_hasEnded[1]) {
                if (_startTimeR2 - block.timestamp > 0) {
                    return _startTimeR2 - block.timestamp;
                } else {
                    return 0;
                }
            } else {
                return 0;
            }
        } else {
            return 0;
        }
    }

    /**
    * @dev Returns the remaining time delay between round 2 and round 3.
    */  
    function getRemainingTimeDelayR2R3() external view returns (uint256) {
        if (timeDelayR2 > 0) {
            if (_hasEnded[0] && _hasEnded[1] && !_hasEnded[2]) {
                if (_startTimeR3 - block.timestamp > 0) {
                    return _startTimeR3 - block.timestamp;
                } else {
                    return 0;
                }
            } else {
                return 0;
            }
        } else {
            return 0;
        }
    }

    /**
    * @dev Returns the total sales for round 1.
    */  
    function getR1Sales() external view returns (uint256) {
        return _actualSupply[0];
    }

    /**
    * @dev Returns the total sales for round 2.
    */  
    function getR2Sales() external view returns (uint256) {
        return _actualSupply[1];
    }

    /**
    * @dev Returns the total sales for round 3.
    */  
    function getR3Sales() external view returns (uint256) {
        return _actualSupply[2];
    }

    /**
    * @dev This function handles token purchases for round 1.
    */ 
    function _buyTokenR1() private {
        if (token.balanceOf(address(this)) > 0) {
            require(!_hasEnded[0], "The first round must be active");
            
            bool isRoundEnded = _buyToken(0, rateR1, totalSupplyR1);
            
            if (isRoundEnded == true) {
                _startTimeR2 = block.timestamp + timeDelayR1;
            }
        } else {
            revert("The stake offering must be active");
        }
    }

    /**
    * @dev This function handles token purchases for round 2.
    */   
    function _buyTokenR2() private {
        require(_hasEnded[0] && !_hasEnded[1], "The first round one must not be active while the second round must be active");
        require(block.timestamp >= _startTimeR2, "The time delay between the first round and the second round must be surpassed");
      
        bool isRoundEnded = _buyToken(1, rateR2, totalSupplyR2);
      
        if (isRoundEnded == true) {
            _startTimeR3 = block.timestamp + timeDelayR2;
        }
    }

    /**
    * @dev This function handles token purchases for round 3.
    */   
    function _buyTokenR3() private {
        require(_hasEnded[1] && !_hasEnded[2], "The second round one must not be active while the third round must be active");
        require(block.timestamp >= _startTimeR3, "The time delay between the first round and the second round must be surpassed"); 

        uint256 period = _calculatePeriod(block.timestamp);
        (bool isRoundClosed, uint256 actualPeriodTotalSupply) = _closeR3(period);

        if (!isRoundClosed) {
            bool isRoundEnded = _buyToken(2, rateR3, actualPeriodTotalSupply);
            
            if (isRoundEnded == true) {
                _endTimeR3 = block.timestamp;
                _endedDayR3 = _calculateEndingPeriod();
            }
        }
    }

    /**
    * @dev This function creates a uniswap pair and handles liquidity provisioning.
    * Returns the uniswap token leftovers.
    */  
    function _createUniswapPair(uint256 endingPeriodArg) private returns (uint256) {
        uint256 listingPrice = endingPeriodArg;
        uint256 ethOnUniswap = _contributedFundsTotal;
      
        ethOnUniswap = ethOnUniswap <= (address(this).balance)
        ? ethOnUniswap
        : (address(this).balance);
      
        uint256 tokensOnUniswap = ethOnUniswap * listingRate * 10000 / (10000 - listingPrice) / 100000;
      
        token.approve(address(uniswapRouter), tokensOnUniswap);
      
        uniswapRouter.addLiquidityETH{value: ethOnUniswap}(
            address(token),
            tokensOnUniswap,
            0,
            0,
            wallet,
            block.timestamp
        );
      
        wallet.transfer(address(this).balance);
      
        return totalSupplyUniswap - tokensOnUniswap;
    }

    /**
    * @dev this function will close round 3 if based on day and sold supply.
    * Returns whether a particular round has ended or not and 
    * the max supply of a particular day during round 3.
    */    
    function _closeR3(uint256 periodArg) private returns (bool isRoundEnded, uint256 maxPeriodSupply) {
        require(_hasEnded[0] && _hasEnded[1] && !_hasEnded[2], 'Round 3 has ended or Round 1 or 2 have not ended yet');
        require(block.timestamp >= _startTimeR3, 'Pause period between Round 2 and 3');
      
        maxPeriodSupply = totalSupplyR3;
      
        if (maxPeriodSupply <= _actualSupply[2]) {
            payable(msg.sender).transfer(msg.value);
            _hasEnded[2] = true;
            
            _endTimeR3 = block.timestamp;
            
            uint256 endingPeriod = _calculateEndingPeriod();
            
            _endedDayR3 = endingPeriod;
            
            return (true, maxPeriodSupply);
            
        } else {
            return (false, maxPeriodSupply);
        }
    }

    /**
    * @dev this function handles low level token purchases. 
    * Returns whether a particular round has ended or not.
    */     
    function _buyToken(uint8 indexArg, uint256 rateArg, uint256 totalSupplyArg) private returns (bool isRoundEnded) {
        // Calculate number of tokens that user is buying
        uint256 tokensNumber = msg.value * rateArg / 100000;
        // Get the current supply in this round
        uint256 actualTotalBalance = _actualSupply[indexArg];
        // Set the new supply in this round
        uint256 newTotalRoundBalance = actualTotalBalance + tokensNumber;
      
        // If it's the first time, write the user as a buyer
        if (!_contributor[msg.sender]) {
            _contributor[msg.sender] = true;
            _contributorsTotal++;
        }  
      
        // If not round ended yet
        if (newTotalRoundBalance < totalSupplyArg) {
            _contributions[indexArg][msg.sender] = _contributions[indexArg][msg.sender] + tokensNumber;
            _actualSupply[indexArg] = newTotalRoundBalance;
            _contributedFundsTotal = _contributedFundsTotal + msg.value;
            
            emit Bought(uint8(indexArg + 1), msg.sender, tokensNumber);
            
            return false;
            
        } else {
            // If the round ends with this purchase
            uint256 availableTokens = totalSupplyArg - actualTotalBalance;
            uint256 availableEth = availableTokens * 100000 / rateArg;
            
            _contributions[indexArg][msg.sender] = _contributions[indexArg][msg.sender] + availableTokens;
            _actualSupply[indexArg] = totalSupplyArg;
            _contributedFundsTotal = _contributedFundsTotal + availableEth;
            _hasEnded[indexArg] = true;
            
            payable(msg.sender).transfer(msg.value - availableEth);

            emit Bought(uint8(indexArg + 1), msg.sender, availableTokens);
            
            return true;
        }
    }

    /**
    * @dev This function handles distribution of extra supply.
    */    
    function _distribute(uint256 amountArg) private {
        uint256 vested = amountArg / 2;
        uint256 burned = amountArg - vested;
        
        token.transfer(platformStakingContract, vested);
        token.burn(burned);
    }

    /**
    * @dev Returns the staking duration of a particular round.
    */   
    function _getDuration(uint256 indexArg) private view returns (uint256) {
        if (indexArg == 0) {
            return stakingPeriodR1;
        }
        if (indexArg == 1) {
            return stakingPeriodR2;
        }
        if (indexArg == 2) {
            return stakingPeriodR3;
        }
    }

    /**
    * @dev This function splits forfeited bonuses into dividends 
    * and to timed distribution contract accordingly.
    */     
    function _split(uint256 amountArg) private {
        if (amountArg == 0) {
            return;
        }
        
        uint256 dividends = amountArg / 2;
        uint256 platformStakingShare = amountArg - dividends;
        
        _bonusTotal = _bonusTotal - platformStakingShare;
        _latestStakingPlatformPayment = platformStakingShare;
        
        token.transfer(platformStakingContract, platformStakingShare);
        
        _addDividends(_latestStakingPlatformPayment);
        
        emit Splitted(msg.sender, dividends, platformStakingShare);
    }
  
    /**
    * @dev this function handles addition of new dividends.
    */   
    function _addDividends(uint256 bonusArg) private {
        uint256 latest = (bonusArg * _scaling) + _scaledRemainder;
        uint256 dividendPerToken = latest / (_contributionsTotal + _totalRestakedDividends);
        _scaledRemainder = latest % (_contributionsTotal + _totalRestakedDividends);
        _totalDividends = _totalDividends + dividendPerToken;
        _payouts[_phase] = _payouts[_phase-1] + dividendPerToken;
        _phase++;
    }
  
    /**
    * @dev returns pending dividend rewards.
    */    
    function _pendingDividends(address accountArg) private returns (uint256) {
        uint256 amount = (_totalDividends - _payouts[_contributors[accountArg].phase - 1]) * getContributionTotal(accountArg) / _scaling;
        _contributors[accountArg].remainder += (_totalDividends - _payouts[_contributors[accountArg].phase - 1]) * getContributionTotal(accountArg) % _scaling ;
        return amount;
    }

    /**
    * @dev Returns the current round.
    */     
    function _calculateCurrentRound() private view returns (uint8) {
        if (!_hasEnded[0]) {
            return 0;
        } else if (_hasEnded[0] && !_hasEnded[1] && !_hasEnded[2]) {
            return 1;
        } else if (_hasEnded[0] && _hasEnded[1] && !_hasEnded[2]) {
            return 2;
        } else {
            return 2**8 - 1;
        }
    }
 
    /**
    * @dev Returns the current day.
    */     
    function _calculatePeriod(uint256 timeArg) private view returns (uint256) {
        uint256 period = (timeArg - _startTimeR3) / periodDurationR3;
        
        if (period > 3) return 3;
        
        return period;
    }
 
    /**
    * @dev Returns the ending day of round 3.
    */     
    function _calculateEndingPeriod() private view returns (uint256) {
        require(_endTimeR3 != (2**256) - 1, "The third round must be active");
        
        return _calculatePeriod(_endTimeR3);
    }

    /**
    * @dev This function handles calculation of token withdrawals
    * (it also withdraws dividends and restaked dividends 
    * during certain circumstances).
    */    
    function _withdrawTokens(uint8 indexArg) private {
        require(_hasEnded[0] && _hasEnded[1] && _hasEnded[2], 
        "The rounds must be inactive before any tokens can be withdrawn");
        require(!_hasWithdrawn[indexArg][msg.sender], 
        "The caller must have withdrawable tokens available from this round");
        
        claimDividends();
      
        uint256 amount = _contributions[indexArg][msg.sender];
        
        _contributions[indexArg][msg.sender] = _contributions[indexArg][msg.sender] - amount;
        _contributionsTotal = _contributionsTotal - amount;
        
        uint256 contributions = getContributionTotal(msg.sender);
        uint256 restaked = getRestakedDividends(msg.sender);
        
        if (contributions - restaked == 0) withdrawRestakedDividends();
        
        uint pending = _pendingDividends(msg.sender);
        _contributors[msg.sender].remainder = _contributors[msg.sender].remainder + pending;
        _contributors[msg.sender].fromTotalDivs = _totalDividends;
        _contributors[msg.sender].phase = _phase;
        
        _hasWithdrawn[indexArg][msg.sender] = true;
        
        token.transfer(msg.sender, amount);
      
        _endStake(indexArg, msg.sender, amount);
    }

    /**
    * @dev This function handles fund withdrawals.
    */  
    function _withdrawFunds(uint256 amountArg) private {
        require(msg.sender == wallet, 
        "The caller must be the specified funds wallet of the team");
        require(amountArg <= (address(this).balance - _fundsWithdrawn) / 2,
        "The 'amountArg' argument exceeds the limit");
        require(!_hasEnded[2], 
        "The third round is not active");
        
        _fundsWithdrawn = _fundsWithdrawn + amountArg;
        
        wallet.transfer(amountArg);
    }

    /**
    * @dev This function handles bonus payouts and the split of forfeited bonuses.
    */     
    function _endStake(uint256 indexArg, address accountArg, uint256 amountArg) private {
        uint256 elapsedTime = block.timestamp - _bonusOfferingActivated;
        uint256 payout;
        
        uint256 duration = _getDuration(indexArg);
        
        if (elapsedTime >= duration) {
            payout = amountArg;
        } else if (elapsedTime >= duration * 3 / 4 && elapsedTime < duration) {
            payout = amountArg * 3 / 4;
        } else if (elapsedTime >= duration * 2 && elapsedTime < duration * 3 / 4) {
            payout = amountArg / 2;
        } else if (elapsedTime >= duration / 4 && elapsedTime < duration / 2) {
            payout = amountArg / 4;
        } else {
            payout = 0;
        }
        
        _split(amountArg - payout);
        
        if (payout != 0) {
            token.transfer(accountArg, payout);
        }
        
        emit Ended(accountArg, amountArg, block.timestamp);
    }

}
