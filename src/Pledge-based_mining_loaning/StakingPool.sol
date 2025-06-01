// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IStaking.sol";
import "./IToken.sol";

/**
 * @title StakingPool
 * @dev A staking pool that allows users to stake ETH and earn KK tokens
 * Features:
 * - Stake ETH to earn KK tokens
 * - 10 KK tokens are minted per block
 * - Rewards are distributed based on stake amount and duration
 * - Integration with lending protocols for additional yield
 */
contract StakingPool is IStaking, ReentrancyGuard, Ownable {
    IToken public immutable kkToken;
    
    // Staking info
    struct UserInfo {
        uint256 amount;           // 用户质押的ETH数量
        uint256 rewardDebt;       // 用户已计算的奖励债务
        uint256 lastStakeBlock;   // 最后质押的区块号
    }
    
    // Pool info
    struct PoolInfo {
        uint256 totalStaked;      // 总质押量
        uint256 accKKPerShare;    // 累积每股KK奖励
        uint256 lastRewardBlock;  // 最后奖励计算的区块号
    }
    
    PoolInfo public poolInfo;
    mapping(address => UserInfo) public userInfo;
    
    // Constants
    uint256 public constant KK_PER_BLOCK = 10 * 1e18; // 每区块10个KK token
    uint256 private constant ACC_PRECISION = 1e12;
    
    // Lending integration (optional)
    address public lendingProtocol;
    bool public lendingEnabled;
    
    // Events
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 amount);
    event LendingProtocolSet(address indexed protocol);
    
    constructor(address _kkToken) Ownable(msg.sender) {
        kkToken = IToken(_kkToken);
        poolInfo.lastRewardBlock = block.number;
    }
    
    /**
     * @dev Update pool rewards
     */
    function updatePool() public {
        if (block.number <= poolInfo.lastRewardBlock) {
            return;
        }
        
        if (poolInfo.totalStaked == 0) {
            poolInfo.lastRewardBlock = block.number;
            return;
        }
        
        uint256 blocks = block.number - poolInfo.lastRewardBlock;
        uint256 kkReward = blocks * KK_PER_BLOCK;
        
        poolInfo.accKKPerShare += (kkReward * ACC_PRECISION) / poolInfo.totalStaked;
        poolInfo.lastRewardBlock = block.number;
        
        // Mint KK tokens to this contract
        kkToken.mint(address(this), kkReward);
    }
    
    /**
     * @dev 质押 ETH 到合约
     */
    function stake() external payable nonReentrant {
        require(msg.value > 0, "StakingPool: stake amount must be greater than 0");
        
        updatePool();
        
        UserInfo storage user = userInfo[msg.sender];
        
        // 如果用户已有质押，先领取之前的奖励
        if (user.amount > 0) {
            uint256 pending = (user.amount * poolInfo.accKKPerShare) / ACC_PRECISION - user.rewardDebt;
            if (pending > 0) {
                kkToken.transfer(msg.sender, pending);
                emit Claimed(msg.sender, pending);
            }
        }
        
        // 更新用户信息
        user.amount += msg.value;
        user.lastStakeBlock = block.number;
        poolInfo.totalStaked += msg.value;
        
        // 计算新的奖励债务
        user.rewardDebt = (user.amount * poolInfo.accKKPerShare) / ACC_PRECISION;
        
        // 如果启用了借贷协议，将ETH存入
        if (lendingEnabled && lendingProtocol != address(0)) {
            _depositToLending(msg.value);
        }
        
        emit Staked(msg.sender, msg.value);
    }
    
    /**
     * @dev 赎回质押的 ETH
     * @param amount 赎回数量
     */
    function unstake(uint256 amount) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= amount, "StakingPool: insufficient staked amount");
        require(amount > 0, "StakingPool: unstake amount must be greater than 0");
        
        updatePool();
        
        // 计算并发送待领取的奖励
        uint256 pending = (user.amount * poolInfo.accKKPerShare) / ACC_PRECISION - user.rewardDebt;
        if (pending > 0) {
            kkToken.transfer(msg.sender, pending);
            emit Claimed(msg.sender, pending);
        }
        
        // 更新用户信息
        user.amount -= amount;
        poolInfo.totalStaked -= amount;
        
        // 计算新的奖励债务
        user.rewardDebt = (user.amount * poolInfo.accKKPerShare) / ACC_PRECISION;
        
        // 如果启用了借贷协议，从借贷协议中提取ETH
        if (lendingEnabled && lendingProtocol != address(0)) {
            _withdrawFromLending(amount);
        }
        
        // 发送ETH给用户
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "StakingPool: ETH transfer failed");
        
        emit Unstaked(msg.sender, amount);
    }
    
    /**
     * @dev 领取 KK Token 收益
     */
    function claim() external nonReentrant {
        updatePool();
        
        UserInfo storage user = userInfo[msg.sender];
        uint256 pending = (user.amount * poolInfo.accKKPerShare) / ACC_PRECISION - user.rewardDebt;
        
        require(pending > 0, "StakingPool: no pending rewards");
        
        // 更新奖励债务
        user.rewardDebt = (user.amount * poolInfo.accKKPerShare) / ACC_PRECISION;
        
        // 发送KK token
        kkToken.transfer(msg.sender, pending);
        
        emit Claimed(msg.sender, pending);
    }
    
    /**
     * @dev 获取质押的 ETH 数量
     * @param account 质押账户
     * @return 质押的 ETH 数量
     */
    function balanceOf(address account) external view returns (uint256) {
        return userInfo[account].amount;
    }
    
    /**
     * @dev 获取待领取的 KK Token 收益
     * @param account 质押账户
     * @return 待领取的 KK Token 收益
     */
    function earned(address account) external view returns (uint256) {
        UserInfo memory user = userInfo[account];
        uint256 accKKPerShare = poolInfo.accKKPerShare;
        
        if (block.number > poolInfo.lastRewardBlock && poolInfo.totalStaked > 0) {
            uint256 blocks = block.number - poolInfo.lastRewardBlock;
            uint256 kkReward = blocks * KK_PER_BLOCK;
            accKKPerShare += (kkReward * ACC_PRECISION) / poolInfo.totalStaked;
        }
        
        return (user.amount * accKKPerShare) / ACC_PRECISION - user.rewardDebt;
    }
    
    /**
     * @dev 设置借贷协议地址（加分项功能）
     */
    function setLendingProtocol(address _lendingProtocol) external onlyOwner {
        lendingProtocol = _lendingProtocol;
        emit LendingProtocolSet(_lendingProtocol);
    }
    
    /**
     * @dev 启用/禁用借贷功能
     */
    function setLendingEnabled(bool _enabled) external onlyOwner {
        lendingEnabled = _enabled;
    }
    
    /**
     * @dev 存入借贷协议（内部函数，加分项）
     */
    function _depositToLending(uint256 amount) internal {
        // 这里需要根据具体的借贷协议实现
        // 例如：Compound的cETH.mint{value: amount}()
        // 或者：Aave的lendingPool.deposit{value: amount}()
        
        // 示例：调用借贷协议的存款方法
        if (lendingProtocol != address(0)) {
            (bool success, ) = lendingProtocol.call{value: amount}(
                abi.encodeWithSignature("mint()")
            );
            // 注意：实际实现中需要处理错误和返回值
        }
    }
    
    /**
     * @dev 从借贷协议提取（内部函数，加分项）
     */
    function _withdrawFromLending(uint256 amount) internal {
        // 这里需要根据具体的借贷协议实现
        // 例如：Compound的cETH.redeem(amount)
        // 或者：Aave的lendingPool.withdraw(amount)
        
        // 示例：调用借贷协议的提取方法
        if (lendingProtocol != address(0)) {
            (bool success, ) = lendingProtocol.call(
                abi.encodeWithSignature("redeem(uint256)", amount)
            );
            // 注意：实际实现中需要处理错误和返回值
        }
    }
    
    /**
     * @dev 获取池子总信息
     */
    function getPoolInfo() external view returns (
        uint256 totalStaked,
        uint256 accKKPerShare,
        uint256 lastRewardBlock
    ) {
        return (
            poolInfo.totalStaked,
            poolInfo.accKKPerShare,
            poolInfo.lastRewardBlock
        );
    }
    
    /**
     * @dev 紧急提取函数（仅限所有者）
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = owner().call{value: balance}("");
            require(success, "StakingPool: emergency withdraw failed");
        }
    }
    
    /**
     * @dev 接收ETH
     */
    receive() external payable {}
}