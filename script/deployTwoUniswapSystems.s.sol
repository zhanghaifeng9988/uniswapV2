// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {UniswapV2Factory} from "@uniswap/v2-core/contracts/UniswapV2Factory.sol";
import {UniswapV2Router02} from "@uniswap/v2-periphery/contracts/UniswapV2Router02.sol";
import {TokenA} from "../src/token/ERC20Token1.sol";
import {TokenB} from "../src/token/ERC20Token2.sol";

contract DeployTwoUniswapSystemsScript is Script {
    // 已部署的代币地址
    address public tokenAAddress;
    address public tokenBAddress;
    
    // 将要部署的Uniswap系统地址
    address public factoryA;
    UniswapV2Router02 public router1; // 系统A的Router实例
    address public factoryB;
    UniswapV2Router02 public router2; // 系统B的Router实例
    
    // Sepolia测试网WETH地址
    address public constant WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    
    function setUp() public {
        console.log(unicode"准备部署两个独立的Uniswap系统并创建流动池");
        
        // 设置已部署的代币地址
        // 这些地址应该替换为您实际部署的地址
        tokenAAddress = 0x5FbDB2315678afecb367f032d93F642f64180aa3; // 替换为您部署的TokenA地址
        tokenBAddress = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512; // 替换为您部署的TokenB地址
    }

    function run() public {
        vm.startBroadcast();
        
        // 部署第一个Uniswap系统（用于PoolA）
        UniswapV2Factory factory1 = new UniswapV2Factory(msg.sender);
        factoryA = address(factory1);
        console.log(unicode"系统A - UniswapV2Factory 已部署到地址:", factoryA);
        
        router1 = new UniswapV2Router02(factoryA, WETH);
        console.log(unicode"系统A - UniswapV2Router02 已部署到地址:", address(router1));
        
        // 部署第二个Uniswap系统（用于PoolB）
        UniswapV2Factory factory2 = new UniswapV2Factory(msg.sender);
        factoryB = address(factory2);
        console.log(unicode"系统B - UniswapV2Factory 已部署到地址:", factoryB);
        
        // 修复：避免变量遮蔽，直接使用类成员变量router2
        router2 = new UniswapV2Router02(factoryB, WETH);
        console.log(unicode"系统B - UniswapV2Router02 已部署到地址:", address(router2));
        
        // 获取代币实例
        TokenA tokenA = TokenA(tokenAAddress);
        TokenB tokenB = TokenB(tokenBAddress);
        
        // 铸造更多代币用于添加流动性
        tokenA.mint(msg.sender, 1000000 * 10**18); // 铸造100万个TokenA
        tokenB.mint(msg.sender, 1000000 * 10**18); // 铸造100万个TokenB
        
        // 为系统A创建交易对并添加流动性（1:1比例）
        // 批准Router使用代币
        uint256 tokenAAmountForPoolA = 100000 * 10**18; // 100000个TokenA
        uint256 tokenBAmountForPoolA = 100000 * 10**18; // 100000个TokenB
        
        // 修复：使用router1替代routerA
        tokenA.approve(address(router1), tokenAAmountForPoolA);
        tokenB.approve(address(router1), tokenBAmountForPoolA);
        
        // 添加流动性到PoolA (1:1)
        (uint amountA1, uint amountB1, uint liquidity1) = router1.addLiquidity(
            tokenAAddress,
            tokenBAddress,
            tokenAAmountForPoolA,
            tokenBAmountForPoolA,
            0, // 最小A数量
            0, // 最小B数量
            msg.sender, // 接收LP代币的地址
            block.timestamp + 3600 // 截止时间：1小时后
        );
        
        address pairA = UniswapV2Factory(factoryA).getPair(tokenAAddress, tokenBAddress);
        console.log(unicode"PoolA 创建成功，地址:", pairA);
        console.log(unicode"PoolA 添加流动性:");
        console.log(unicode"- TokenA 数量:", amountA1);
        console.log(unicode"- TokenB 数量:", amountB1);
        console.log(unicode"- 获得的LP代币数量:", liquidity1);
        
        // 为系统B创建交易对并添加流动性（1:5比例）
        // 批准Router使用代币
        uint256 tokenAAmountForPoolB = 100000 * 10**18; // 100000个TokenA
        uint256 tokenBAmountForPoolB = 500000 * 10**18; // 500000个TokenB
        
        // 修复：使用router2替代routerB
        tokenA.approve(address(router2), tokenAAmountForPoolB);
        tokenB.approve(address(router2), tokenBAmountForPoolB);
        
        // 添加流动性到PoolB (1:2)
        // 修复：直接使用router2而不是转换
        (uint amountA2, uint amountB2, uint liquidity2) = router2.addLiquidity(
            tokenAAddress,
            tokenBAddress,
            tokenAAmountForPoolB,
            tokenBAmountForPoolB,
            0, // 最小A数量
            0, // 最小B数量
            msg.sender, // 接收LP代币的地址
            block.timestamp + 3600 // 截止时间：1小时后
        );
        
        address pairB = UniswapV2Factory(factoryB).getPair(tokenAAddress, tokenBAddress);
        console.log(unicode"PoolB 创建成功，地址:", pairB);
        console.log(unicode"PoolB 添加流动性:");
        console.log(unicode"- TokenA 数量:", amountA2);
        console.log(unicode"- TokenB 数量:", amountB2);
        console.log(unicode"- 获得的LP代币数量:", liquidity2);
        
        vm.stopBroadcast();
        
        // 输出部署结果摘要
        console.log(unicode"\n部署摘要:");
        console.log(unicode"=======================");
        console.log(unicode"TokenA 地址:", tokenAAddress);
        console.log(unicode"TokenB 地址:", tokenBAddress);
        console.log(unicode"系统A - Factory 地址:", factoryA);
        // 修复：使用router1替代routerA
        console.log(unicode"系统A - Router 地址:", address(router1));
        console.log(unicode"系统A - Pair 地址 (PoolA):", pairA);
        console.log(unicode"系统B - Factory 地址:", factoryB);
        // 修复：使用router2替代routerB
        console.log(unicode"系统B - Router 地址:", address(router2));
        console.log(unicode"系统B - Pair 地址 (PoolB):", pairB);
        console.log(unicode"=======================");
    }
}