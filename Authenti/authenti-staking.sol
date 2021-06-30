// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./Context.sol";
import "./Address.sol";
import "./SafeMath.sol";
import "./Ownable.sol";

interface IBEP20 {
    
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeBEP20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IBEP20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IBEP20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IBEP20 token, address spender, uint256 value) internal {
    
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeBEP20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IBEP20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IBEP20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeBEP20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function _callOptionalReturn(IBEP20 token, bytes memory data) private {
        
        bytes memory returndata = address(token).functionCall(data, "SafeBEP20: low-level call failed");
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeBEP20: BEP20 operation did not succeed");
        }
    }
}

contract AuthentiStaking is Ownable {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 pendingRewards;
        uint256 lastClaim;
    }

    struct PoolInfo {
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accAuthentiPerShare;
        uint256 depositedAmount;
        uint256 rewardsAmount;
        uint256 lockupDuration;
    }

    IBEP20 public Authenti;
    uint256 public AuthentiPerBlock = uint256(5 ether).div(10); //0.5 Authenti
    uint256 private constant _taxFee = 13;
    uint256 private _tFeeTotal;

    PoolInfo[] public poolInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    uint256 public totalAllocPoint = 10;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event Claim(address indexed user, uint256 indexed pid, uint256 amount);
    event ClaimAndStake(address indexed user, uint256 indexed pid, uint256 amount);

    function addPool(uint256 _allocPoint, uint256 _lockupDuration) internal {
        poolInfo.push(
            PoolInfo({
                allocPoint: _allocPoint,
                lastRewardBlock: 0,
                accAuthentiPerShare: 0,
                depositedAmount: 0,
                rewardsAmount: 0,
                lockupDuration: _lockupDuration
            })
        );
    }
    
    function setAuthentiToken(IBEP20 _Authenti) external onlyOwner {
        require(address(Authenti) == address(0), 'Token already set!');
        Authenti = _Authenti;
        addPool(10, 0);
    }
    
    function startStaking(uint256 startBlock) external onlyOwner {
        require(poolInfo[0].lastRewardBlock == 0, 'Staking already started');
        poolInfo[0].lastRewardBlock = startBlock;
    }

    function pendingRewards(uint256 pid, address _user) external view returns (uint256) {
        require(poolInfo[pid].lastRewardBlock > 0 && block.number >= poolInfo[pid].lastRewardBlock, 'Staking not yet started');
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][_user];
        uint256 accAuthentiPerShare = pool.accAuthentiPerShare;
        uint256 depositedAmount = pool.depositedAmount;
        if (block.number > pool.lastRewardBlock && depositedAmount != 0) {
            uint256 multiplier = block.number.sub(pool.lastRewardBlock);
            uint256 AuthentiReward = multiplier.mul(AuthentiPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accAuthentiPerShare = accAuthentiPerShare.add(AuthentiReward.mul(1e12).div(depositedAmount));
        }
        return user.amount.mul(accAuthentiPerShare).div(1e12).sub(user.rewardDebt).add(user.pendingRewards);
    }

    function updatePool(uint256 pid) internal {
        require(poolInfo[pid].lastRewardBlock > 0 && block.number >= poolInfo[pid].lastRewardBlock, 'Staking not yet started');
        PoolInfo storage pool = poolInfo[pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 depositedAmount = pool.depositedAmount;
        if (pool.depositedAmount == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = block.number.sub(pool.lastRewardBlock);
        uint256 AuthentiReward = multiplier.mul(AuthentiPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        pool.rewardsAmount = pool.rewardsAmount.add(AuthentiReward);
        pool.accAuthentiPerShare = pool.accAuthentiPerShare.add(AuthentiReward.mul(1e12).div(depositedAmount));
        pool.lastRewardBlock = block.number;
    }

    function deposit(uint256 pid, uint256 amount) external {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][msg.sender];
        updatePool(pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accAuthentiPerShare).div(1e12).sub(user.rewardDebt);
            if (pending > 0) {
                user.pendingRewards = user.pendingRewards.add(pending);
            }
        }
        if (amount > 0) {
            Authenti.transferFrom(address(msg.sender), address(this), amount);
            user.amount = user.amount.add(amount);
            pool.depositedAmount = pool.depositedAmount.add(amount);
        }
        user.rewardDebt = user.amount.mul(pool.accAuthentiPerShare).div(1e12);
        user.lastClaim = block.timestamp;
        emit Deposit(msg.sender, pid, amount);
    }

    function withdraw(uint256 pid, uint256 amount) external {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][msg.sender];
        require(block.timestamp > user.lastClaim + pool.lockupDuration, "You cannot withdraw yet!");
        require(user.amount >= amount, "Withdrawing more than you have!");
        updatePool(pid);
        uint256 pending = user.amount.mul(pool.accAuthentiPerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0) {
            user.pendingRewards = user.pendingRewards.add(pending);
        }
        if (amount > 0) {
            Authenti.safeTransfer(address(msg.sender), amount);
            user.amount = user.amount.sub(amount);
            pool.depositedAmount = pool.depositedAmount.sub(amount);
        }
        user.rewardDebt = user.amount.mul(pool.accAuthentiPerShare).div(1e12);
        user.lastClaim = block.timestamp;
        emit Withdraw(msg.sender, pid, amount);
    }

    function claim(uint256 pid) public {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][msg.sender];
        updatePool(pid);
        uint256 pending = user.amount.mul(pool.accAuthentiPerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0 || user.pendingRewards > 0) {
            user.pendingRewards = user.pendingRewards.add(pending);
            uint256 claimedAmount = safeAuthentiTransfer(msg.sender, user.pendingRewards, pid);
            emit Claim(msg.sender, pid, claimedAmount);
            user.pendingRewards = user.pendingRewards.sub(claimedAmount);
            user.lastClaim = block.timestamp;
            pool.rewardsAmount = pool.rewardsAmount.sub(claimedAmount);
        }
        user.rewardDebt = user.amount.mul(pool.accAuthentiPerShare).div(1e12);
    }
    
    function safeAuthentiTransfer(address to, uint256 amount, uint256 pid) internal returns (uint256) {
        PoolInfo memory pool = poolInfo[pid];
        if (amount > pool.rewardsAmount) {
            Authenti.safeTransfer(to, pool.rewardsAmount);
            return pool.rewardsAmount;
        } else {
            Authenti.safeTransfer(to, amount);
            return amount;
        }
    }
    
    function setAuthentiPerBlock(uint256 _AuthentiPerBlock) external onlyOwner {
        require(_AuthentiPerBlock > 0, "Authenti per block should be greater than 0!");
        AuthentiPerBlock = _AuthentiPerBlock;
    }
    
    function totalFees() public pure returns (uint256) {
        return _taxFee;
    }
    
    function _reflectFee(uint256 tFee) private {
        _tFeeTotal = _taxFee.add(tFee);
    }
}