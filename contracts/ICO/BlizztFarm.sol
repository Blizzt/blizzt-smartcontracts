// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

import "../interfaces/IBlizztFarm.sol";

// Farm distributes the ERC20 rewards based on staked LP to each user.
//
// Cloned from https://github.com/SashimiProject/sashimiswap/blob/master/contracts/MasterChef.sol
// Modified by LTO Network to work for non-mintable ERC20.
// Modified by RuufPay to change the farm initialization

contract BlizztFarm is IBlizztFarm, ReentrancyGuard, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of ERC20s
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accERC20PerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accERC20PerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;             // Address of LP token contract.
        uint256 allocPoint;         // How many allocation points assigned to this pool. ERC20s to distribute per block.
        uint256 lastRewardBlock;    // Last block number that ERC20s distribution occurs.
        uint256 accERC20PerShare;   // Accumulated ERC20s per share, times 1e36.
    }

    // Address of the ERC20 Token contract.
    IERC20 public immutable erc20;
    // The total amount of ERC20 that's paid out as reward.
    uint256 public paidOut = 0;
    // ERC20 tokens rewarded per block.
    uint256 public rewardPerBlock;

    // Info of each pool.
    PoolInfo public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (address => UserInfo) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;

    // The block number when farming starts.
    uint256 public startBlock;
    // The block number when farming ends.
    uint256 public endBlock;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    constructor (IERC20 _erc20) {
        erc20 = _erc20;
        poolInfo = PoolInfo({
            lpToken: _erc20,
            allocPoint: 0,
            lastRewardBlock: 0,
            accERC20PerShare: 0
        });
    }

    function initialSetup(uint256 _startBlock, uint256 _numBlocks) external override onlyOwner {
        require(startBlock == 0, "Initalized yet");

        startBlock = _startBlock;
        uint256 amount = erc20.balanceOf(address(this));
        rewardPerBlock = amount / _numBlocks;
        endBlock = _startBlock + _numBlocks;
    }

    // Fund the farm, increase the end block
    function fund(uint256 _amount) external override {
        require(block.number < endBlock, "fund: too late, the farm is closed");

        erc20.safeTransferFrom(address(msg.sender), address(this), _amount);
        endBlock += _amount.div(rewardPerBlock);
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, address _lpToken) external override onlyOwner {
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo = PoolInfo({
            lpToken: IERC20(_lpToken),
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accERC20PerShare: 0
        });
    }

    // Update the given pool's ERC20 allocation point. Can only be called by the owner.
    function set(uint256 _allocPoint) public onlyOwner {
        totalAllocPoint = totalAllocPoint.sub(poolInfo.allocPoint).add(_allocPoint);
        poolInfo.allocPoint = _allocPoint;
    }

    // View function to see deposited LP for a user.
    function deposited(address _user) external override view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        return user.amount;
    }

    // View function to see pending ERC20s for a user.
    function pending(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 accERC20PerShare = poolInfo.accERC20PerShare;
        uint256 lpSupply = poolInfo.lpToken.balanceOf(address(this));

        if (block.number > poolInfo.lastRewardBlock && lpSupply != 0) {
            uint256 lastBlock = block.number < endBlock ? block.number : endBlock;
            uint256 nrOfBlocks = lastBlock.sub(poolInfo.lastRewardBlock);
            uint256 erc20Reward = nrOfBlocks.mul(rewardPerBlock).mul(poolInfo.allocPoint).div(totalAllocPoint);
            accERC20PerShare = accERC20PerShare.add(erc20Reward.mul(1e36).div(lpSupply));
        }

        return user.amount.mul(accERC20PerShare).div(1e36).sub(user.rewardDebt);
    }

    // View function for total reward the farm has yet to pay out.
    function totalPending() external view returns (uint256) {
        if (block.number <= startBlock) {
            return 0;
        }

        uint256 lastBlock = block.number < endBlock ? block.number : endBlock;
        return rewardPerBlock.mul(lastBlock - startBlock).sub(paidOut);
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool() public {
        uint256 lastBlock = block.number < endBlock ? block.number : endBlock;

        if (lastBlock <= poolInfo.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = poolInfo.lpToken.balanceOf(address(this));
        if ((lpSupply == 0) || (poolInfo.allocPoint == 0)) {
            poolInfo.lastRewardBlock = lastBlock;
            return;
        }

        uint256 nrOfBlocks = lastBlock.sub(poolInfo.lastRewardBlock);
        uint256 erc20Reward = nrOfBlocks.mul(rewardPerBlock).mul(poolInfo.allocPoint).div(totalAllocPoint);

        poolInfo.accERC20PerShare = poolInfo.accERC20PerShare.add(erc20Reward.mul(1e36).div(lpSupply));
        poolInfo.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to Farm for ERC20 allocation.
    function deposit(address _user, uint256 _amount) external override nonReentrant {
        UserInfo storage user = userInfo[_user];
        updatePool();
        if (_amount > 0) {
            poolInfo.lpToken.safeTransferFrom(msg.sender, address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(poolInfo.accERC20PerShare).div(1e36);

        emit Deposit(_user, _amount);
    }

    // Withdraw LP tokens from Farm.
    function withdraw(uint256 _amount) public nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "withdraw: can't withdraw more than deposit");
        updatePool();
        uint256 pendingAmount = user.amount.mul(poolInfo.accERC20PerShare).div(1e36).sub(user.rewardDebt);
        if (pendingAmount > 0) {
            safeErc20Transfer(msg.sender, pendingAmount);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            poolInfo.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(poolInfo.accERC20PerShare).div(1e36);

        emit Withdraw(msg.sender, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw() public nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        poolInfo.lpToken.safeTransfer(address(msg.sender), amount);

        emit EmergencyWithdraw(msg.sender, amount);
    }

    // Transfer ERC20 and update the required ERC20 to payout all rewards
    function safeErc20Transfer(address _to, uint256 _amount) internal {
        uint256 balance = erc20.balanceOf(address(this));
        bool transferSuccess = false;
        if (_amount > balance) {
            transferSuccess = erc20.transfer(_to, balance);
        } else {
            transferSuccess = erc20.transfer(_to, _amount);
        }

        require(transferSuccess, "safeSpaceTransfer: transfer failed");
        paidOut += _amount;
    }
}