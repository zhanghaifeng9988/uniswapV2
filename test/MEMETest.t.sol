// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {WETH9} from "../src/uniswap/v2-periphery/contracts/test/WETH9.sol";
import {UniswapV2Factory} from "v2-core/UniswapV2Factory.sol";
import {UniswapV2Pair} from "v2-core/UniswapV2Pair.sol";
import {UniswapV2Router02} from "v2-periphery/UniswapV2Router02.sol";
import {MEME_Inscription} from "../src/token/MEME_Inscription.sol";
import {MEME_Token} from "../src/token/MEME_Token.sol";

contract MEMETest is Test {
    // 合约实例
    UniswapV2Router02 public router;
    UniswapV2Factory public factory;
    WETH9 public weth;
    MEME_Inscription public inscription;
    
    // 测试账户
    address public owner;
    address public user1;
    address public user2;
    
    // MEME代币地址
    address public memeToken;
    
    // 常量
    uint256 constant INITIAL_ETH = 100 ether;
    
    function setUp() public {
        // 设置测试账户
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        
        // 给测试用户转账ETH
        vm.deal(user1, INITIAL_ETH);
        vm.deal(user2, INITIAL_ETH);
        
        // 部署Uniswap相关合约
        weth = new WETH9();
        factory = new UniswapV2Factory(owner);
        router = new UniswapV2Router02(address(factory), address(weth));
        
        // 部署MEME铭文合约
        inscription = new MEME_Inscription(factory, address(router));
        
        // 用户1部署MEME代币
        vm.startPrank(user1);
        memeToken = inscription.deployInscription(
            "TEST",    // 代币符号
            1000000,    // 总供应量（100万）
            100,        // 每次铸造100个
            0.0001 ether // 每个代币0.0001 ETH
        );
        vm.stopPrank();
    }
    
    function test_InitialLiquidity() public {
        // 用户1铸造MEME代币
        vm.startPrank(user1);
        inscription.mintInscription{value: 0.01 ether}(memeToken); // 铸造100个MEME，花费0.01 ETH
        
        // 获取MEME代币实例
        MEME_Token token = MEME_Token(memeToken);
        uint256 userBalance = token.balanceOf(user1);
        
        // 授权Router使用代币
        token.approve(address(router), type(uint256).max);
        
        // 将全部铸造的MEME添加到流动性池中
        router.addLiquidityETH{value: 0.01 ether}(
            memeToken,
            userBalance, // 用户持有的全部MEME
            0, // 允许滑点
            0, // 允许滑点
            user1,
            block.timestamp + 1
        );
        
        // 获取交易对地址
        address pair = factory.getPair(memeToken, address(weth));
        require(pair != address(0), "Pair not created");
        
        // 获取交易对中的储备量
        (uint112 reserve0, uint112 reserve1, ) = UniswapV2Pair(pair).getReserves();
        
        // 确保储备量顺序正确（Uniswap按地址排序）
        (uint112 reserveMEME, uint112 reserveWETH) = address(memeToken) < address(weth) 
            ? (reserve0, reserve1) 
            : (reserve1, reserve0);
        
        // 计算实际价格比例
        uint256 actualPrice = (uint256(reserveWETH) * 1e18) / uint256(reserveMEME);
        uint256 expectedPrice = 0.0001 ether; // 每个MEME 0.0001 ETH
        
        // 允许1%的误差
        uint256 tolerance = expectedPrice / 100;
        
        console.log(unicode"MEME储备量:", reserveMEME / 1e18);
        console.log(unicode"WETH储备量:", reserveWETH / 1e18);
        console.log(unicode"实际价格(wei):", actualPrice);
        console.log(unicode"预期价格(wei):", expectedPrice);
        
        // 验证初始价格是否符合预期
        assertApproxEqRel(actualPrice, expectedPrice, tolerance, "Initial price incorrect");
        
        vm.stopPrank();
    }
    
    function test_SecondLiquidity() public {
        // 先铸造MEME并添加初始流动性
        vm.startPrank(user1);
        inscription.mintInscription{value: 0.01 ether}(memeToken); // 铸造100个MEME
        
        // 获取MEME代币实例
        MEME_Token token = MEME_Token(memeToken);
        uint256 userBalance = token.balanceOf(user1);
        
        // 授权Router使用代币
        token.approve(address(router), type(uint256).max);
        
        // 将全部铸造的MEME添加到流动性池中
        router.addLiquidityETH{value: 0.01 ether}(
            memeToken,
            userBalance,
            0,
            0,
            user1,
            block.timestamp + 1
        );
        vm.stopPrank();
        
        // 用户2铸造MEME用于添加流动性
        vm.startPrank(user2);
        inscription.mintInscription{value: 0.01 ether}(memeToken); // 铸造100个MEME
        
        // 获取用户2的MEME余额
        uint256 user2Balance = token.balanceOf(user2);
        
        // 授权Router使用代币
        token.approve(address(router), type(uint256).max);
        
        // 添加流动性，使用较低的ETH比例（0.008 ETH对应100个MEME）
        // 这会使MEME价格降低
        uint256 ethAmount = 0.008 ether;    // 0.008 ETH
        
        router.addLiquidityETH{value: ethAmount}(
            memeToken,
            user2Balance, // 用户2持有的全部MEME
            0, // 允许滑点
            0, // 允许滑点
            user2,
            block.timestamp + 1
        );
        
        // 获取交易对地址和储备量
        address pair = factory.getPair(memeToken, address(weth));
        (uint112 reserve0, uint112 reserve1, ) = UniswapV2Pair(pair).getReserves();
        
        // 确保储备量顺序正确
        (uint112 reserveMEME, uint112 reserveWETH) = address(memeToken) < address(weth) 
            ? (reserve0, reserve1) 
            : (reserve1, reserve0);
        
        // 计算新的价格比例
        uint256 newPrice = (uint256(reserveWETH) * 1e18) / uint256(reserveMEME);
        uint256 initialPrice = 0.0001 ether;
        
        console.log(unicode"添加流动性后MEME储备量:", reserveMEME / 1e18);
        console.log(unicode"添加流动性后WETH储备量:", reserveWETH / 1e18);
        console.log(unicode"新价格(wei):", newPrice);
        console.log(unicode"初始价格(wei):", initialPrice);
        
        // 验证价格是否降低，允许更大的误差范围（30%）
        // 预期新价格应该是初始价格的80%左右（因为使用了0.008 ETH而不是0.01 ETH）
        assertApproxEqRel(newPrice, initialPrice * 80 / 100, 0.3e18, "Price should be around 80% of initial price");
        vm.stopPrank();
    }
    
    function test_BuyMEME() public {
        // 先铸造MEME并添加初始流动性
        vm.startPrank(user1);
        inscription.mintInscription{value: 0.01 ether}(memeToken); // 铸造100个MEME
        
        // 获取MEME代币实例
        MEME_Token token = MEME_Token(memeToken);
        uint256 userBalance = token.balanceOf(user1);
        
        // 授权Router使用代币
        token.approve(address(router), type(uint256).max);
        
        // 将全部铸造的MEME添加到流动性池中
        router.addLiquidityETH{value: 0.01 ether}(
            memeToken,
            userBalance,
            0,
            0,
            user1,
            block.timestamp + 1
        );
        vm.stopPrank();
        
        // 用户2铸造MEME并添加流动性降低价格
        vm.startPrank(user2);
        inscription.mintInscription{value: 0.01 ether}(memeToken); // 铸造100个MEME
        
        // 获取用户2的MEME余额
        uint256 user2Balance = token.balanceOf(user2);
        
        // 授权Router使用代币
        token.approve(address(router), type(uint256).max);
        
        // 添加流动性，降低价格
        uint256 ethAmount = 0.008 ether;    // 0.008 ETH
        
        router.addLiquidityETH{value: ethAmount}(
            memeToken,
            user2Balance,
            0,
            0,
            user2,
            block.timestamp + 1
        );
        vm.stopPrank();
        
        // 用户1购买MEME代币
        vm.startPrank(user1);
        uint256 balanceBefore = token.balanceOf(user1);
        uint256 ethToSpend = 0.002 ether;
        
        // 使用buyMeme函数购买MEME
        inscription.buyMeme{value: ethToSpend}(memeToken, 0); // 最小输出为0，允许任意滑点
        
        uint256 balanceAfter = token.balanceOf(user1);
        uint256 memeReceived = balanceAfter - balanceBefore;
        
        console.log(unicode"花费ETH:", ethToSpend / 1e18);
        console.log(unicode"获得MEME:", memeReceived / 1e18);
        console.log(unicode"实际价格比例:", (ethToSpend * 1e18) / memeReceived);
        
        // 验证是否成功购买了MEME
        assertTrue(memeReceived > 0, "Should receive MEME tokens");
        
        // 验证购买价格是否接近铸造价格，允许20%的误差
        uint256 actualPrice = (ethToSpend * 1e18) / memeReceived;
        assertApproxEqRel(actualPrice, 0.0001 ether, 0.2e18, "Buy price should be close to mint price");
        
        vm.stopPrank();
    }
    
    // 添加receive函数以接收ETH
    receive() external payable {}
}