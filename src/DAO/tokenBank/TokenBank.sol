// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title TokenBank
 * @dev 代币银行合约，管理ETH和ERC20代币，由DAO治理合约管理
 */
contract TokenBank is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // 事件定义
    event EthDeposit(address indexed from, uint256 amount);
    event EthWithdrawal(address indexed to, uint256 amount);
    event TokenDeposit(address indexed token, address indexed from, uint256 amount);
    event TokenWithdrawal(address indexed token, address indexed to, uint256 amount);
    
    // 存储各种代币的余额
    mapping(address => uint256) public tokenBalances;
    
    constructor(address initialOwner) Ownable(initialOwner) {}
    
    /**
     * @dev 接收ETH存款
     */
    receive() external payable {
        emit EthDeposit(msg.sender, msg.value);
    }
    
    /**
     * @dev ETH存款函数
     */
    function depositEth() external payable {
        require(msg.value > 0, "TokenBank: deposit amount must be greater than 0");
        emit EthDeposit(msg.sender, msg.value);
    }
    
    /**
     * @dev ERC20代币存款
     * @param token 代币合约地址
     * @param amount 存款金额
     */
    function depositToken(address token, uint256 amount) external {
        require(token != address(0), "TokenBank: invalid token address");
        require(amount > 0, "TokenBank: deposit amount must be greater than 0");
        
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        tokenBalances[token] += amount;
        
        emit TokenDeposit(token, msg.sender, amount);
    }
    
    /**
     * @dev 提取ETH（仅管理员可调用）
     * @param to 接收地址
     * @param amount 提取金额
     */
    function withdrawEth(address payable to, uint256 amount) external onlyOwner nonReentrant {
        require(to != address(0), "TokenBank: invalid recipient address");
        require(amount > 0, "TokenBank: withdrawal amount must be greater than 0");
        require(address(this).balance >= amount, "TokenBank: insufficient ETH balance");
        
        to.transfer(amount);
        emit EthWithdrawal(to, amount);
    }
    
    /**
     * @dev 提取ERC20代币（仅管理员可调用）
     * @param token 代币合约地址
     * @param to 接收地址
     * @param amount 提取金额
     */
    function withdrawToken(address token, address to, uint256 amount) external onlyOwner nonReentrant {
        require(token != address(0), "TokenBank: invalid token address");
        require(to != address(0), "TokenBank: invalid recipient address");
        require(amount > 0, "TokenBank: withdrawal amount must be greater than 0");
        require(tokenBalances[token] >= amount, "TokenBank: insufficient token balance");
        
        tokenBalances[token] -= amount;
        IERC20(token).safeTransfer(to, amount);
        
        emit TokenWithdrawal(token, to, amount);
    }
    
    /**
     * @dev 获取ETH余额
     */
    function getEthBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev 获取指定代币余额
     * @param token 代币合约地址
     */
    function getTokenBalance(address token) external view returns (uint256) {
        return tokenBalances[token];
    }
    
    /**
     * @dev 批量提取多种代币（仅管理员可调用）
     * @param tokens 代币地址数组
     * @param to 接收地址
     * @param amounts 提取金额数组
     */
    function batchWithdrawTokens(
        address[] calldata tokens,
        address to,
        uint256[] calldata amounts
    ) external onlyOwner nonReentrant {
        require(tokens.length == amounts.length, "TokenBank: arrays length mismatch");
        require(to != address(0), "TokenBank: invalid recipient address");
        
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 amount = amounts[i];
            
            require(token != address(0), "TokenBank: invalid token address");
            require(amount > 0, "TokenBank: withdrawal amount must be greater than 0");
            require(tokenBalances[token] >= amount, "TokenBank: insufficient token balance");
            
            tokenBalances[token] -= amount;
            IERC20(token).safeTransfer(to, amount);
            
            emit TokenWithdrawal(token, to, amount);
        }
    }
    
    /**
     * @dev 紧急提取所有资金（仅管理员可调用）
     * @param to 接收地址
     */
    function emergencyWithdrawAll(address payable to) external onlyOwner nonReentrant {
        require(to != address(0), "TokenBank: invalid recipient address");
        
        // 提取所有ETH
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            to.transfer(ethBalance);
            emit EthWithdrawal(to, ethBalance);
        }
    }
}