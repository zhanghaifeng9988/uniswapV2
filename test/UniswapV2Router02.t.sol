// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0 <0.9.0;

import {Test, console} from "forge-std/Test.sol";
import {WETH9} from "../src/uniswap/v2-periphery/contracts/test/WETH9.sol";
import {UniswapV2Factory} from "v2-core/UniswapV2Factory.sol";
import {UniswapV2Pair} from "v2-core/UniswapV2Pair.sol";
import {UniswapV2Router02} from "v2-periphery/UniswapV2Router02.sol";
import {ERC20Test} from "../contracts/test/ERC20Test.sol";
import {TokenWithFee} from "../contracts/test/TokenWithFee.sol";
import "../src/uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";

contract UniswapV2Router02Test is Test {
    UniswapV2Router02 public router;
    UniswapV2Factory public factory;
    WETH9 public weth;
    ERC20Test public token0;
    ERC20Test public token1;
    UniswapV2Pair public pair;
    
    address public owner;
    address public user;
    
    uint256 constant MINIMUM_LIQUIDITY = 10**3;
    
    function setUp() public {
        owner = address(this);
        user = address(0x1);
        vm.startPrank(owner);
        
        // 部署 WETH
        weth = new WETH9();
        
        // 部署 Factory
        factory = new UniswapV2Factory(owner);
        
        // 部署 Router
        router = new UniswapV2Router02(address(factory), address(weth));
        
        // 部署测试代币
        token0 = new ERC20Test("Token0", "TK0", 1000000 ether);
        token1 = new ERC20Test("Token1", "TK1", 1000000 ether);
        
        // 确保 token0 和 token1 按地址排序
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }
        
        // 创建交易对
        factory.createPair(address(token0), address(token1));
        address pairAddress = factory.getPair(address(token0), address(token1));
        pair = UniswapV2Pair(pairAddress);
        
        // 向用户转账代币
        token0.transfer(user, 10000 ether);
        token1.transfer(user, 10000 ether);
        
        // 授权 Router 使用代币
        token0.approve(address(router), type(uint256).max);
        token1.approve(address(router), type(uint256).max);
        
        vm.stopPrank();
        
        vm.startPrank(user);
        token0.approve(address(router), type(uint256).max);
        token1.approve(address(router), type(uint256).max);
        vm.stopPrank();
    }
    
    function test_AddLiquidity() public {
        vm.startPrank(owner);
        
        uint256 token0Amount = 1 ether;
        uint256 token1Amount = 4 ether;
        
        uint256 expectedLiquidity = 2 ether - MINIMUM_LIQUIDITY;
        
        uint256 token0Before = token0.balanceOf(owner);
        uint256 token1Before = token1.balanceOf(owner);
        
        (uint256 amountA, uint256 amountB, uint256 liquidity) = router.addLiquidity(
            address(token0),
            address(token1),
            token0Amount,
            token1Amount,
            0,
            0,
            owner,
            block.timestamp + 1
        );
        
        assertEq(amountA, token0Amount);
        assertEq(amountB, token1Amount);
        assertEq(liquidity, expectedLiquidity);
        assertEq(token0.balanceOf(owner), token0Before - token0Amount);
        assertEq(token1.balanceOf(owner), token1Before - token1Amount);
        assertEq(pair.balanceOf(owner), expectedLiquidity);
        
        vm.stopPrank();
    }
    
    function test_SwapExactTokensForTokens() public {
        // 先添加流动性
        vm.startPrank(owner);
        
        uint256 token0Amount = 5 ether;
        uint256 token1Amount = 10 ether;
        
        router.addLiquidity(
            address(token0),
            address(token1),
            token0Amount,
            token1Amount,
            0,
            0,
            owner,
            block.timestamp + 1
        );
        
        uint256 swapAmount = 1 ether;
        address[] memory path = new address[](2);
        path[0] = address(token0);
        path[1] = address(token1);
        
        uint256 token0Before = token0.balanceOf(owner);
        uint256 token1Before = token1.balanceOf(owner);
        
        // 计算预期输出金额
        (uint256 reserveIn, uint256 reserveOut) = router.getReserves(address(factory), address(token0), address(token1));
        uint256 expectedOutputAmount = router.getAmountOut(swapAmount, reserveIn, reserveOut);
        
        // 执行交换
        uint256[] memory amounts = router.swapExactTokensForTokens(
            swapAmount,
            0,
            path,
            owner,
            block.timestamp + 1
        );
        
        assertEq(amounts[0], swapAmount);
        assertEq(amounts[1], expectedOutputAmount);
        assertEq(token0.balanceOf(owner), token0Before - swapAmount);
        assertEq(token1.balanceOf(owner), token1Before + expectedOutputAmount);
        
        vm.stopPrank();
    }
    
    function test_SwapTokensForExactTokens() public {
        // 先添加流动性
        vm.startPrank(owner);
        
        uint256 token0Amount = 5 ether;
        uint256 token1Amount = 10 ether;
        
        router.addLiquidity(
            address(token0),
            address(token1),
            token0Amount,
            token1Amount,
            0,
            0,
            owner,
            block.timestamp + 1
        );
        
        uint256 amountInMax = 1.5 ether;
        uint256 amountOut = 1 ether;
        address[] memory path = new address[](2);
        path[0] = address(token0);
        path[1] = address(token1);
        
        uint256 token0Before = token0.balanceOf(owner);
        uint256 token1Before = token1.balanceOf(owner);
        
        // 计算预期输入金额
        // 删除这两行
        // 修改前
        // (uint256 reserveIn, uint256 reserveOut) = router.getReserves(address(factory), address(token0), address(token1));
        
        // 只保留这行
        (uint256 reserveIn, uint256 reserveOut) = UniswapV2Library.getReserves(address(factory), address(token0), address(token1));
        uint256 expectedAmountIn = router.getAmountIn(amountOut, reserveIn, reserveOut);
        
        // 执行交换
        uint256[] memory amounts = router.swapTokensForExactTokens(
            amountOut,
            amountInMax,
            path,
            owner,
            block.timestamp + 1
        );
        
        assertEq(amounts[0], expectedAmountIn);
        assertEq(amounts[1], amountOut);
        assertEq(token0.balanceOf(owner), token0Before - expectedAmountIn);
        assertEq(token1.balanceOf(owner), token1Before + amountOut);
        
        vm.stopPrank();
    }
    
    function test_SwapWithFeeToken() public {
        vm.startPrank(owner);
        
        // 部署带有转账费用的代币
        TokenWithFee tokenWithFee = new TokenWithFee("Fee Token", "FEE", 1000000 ether);
        
        // 向用户转账代币
        tokenWithFee.transfer(user, 10000 ether);
        
        // 授权 Router 使用代币
        tokenWithFee.approve(address(router), type(uint256).max);
        
        // 创建交易对
        factory.createPair(address(tokenWithFee), address(weth));
        
        // 添加流动性
        uint256 tokenAmount = 100 ether;
        uint256 ethAmount = 10 ether;
        
        router.addLiquidityETH{
            value: ethAmount
        }(
            address(tokenWithFee),
            tokenAmount,
            0,
            0,
            owner,
            block.timestamp + 1
        );
        
        vm.stopPrank();
        
        // 用户交换代币
        vm.startPrank(user);
        
        tokenWithFee.approve(address(router), type(uint256).max);
        
        uint256 swapAmount = 1 ether;
        address[] memory path = new address[](2);
        path[0] = address(tokenWithFee);
        path[1] = address(weth);
        
        uint256 userEthBefore = user.balance;
        
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            swapAmount,
            0,
            path,
            user,
            block.timestamp + 1
        );
        
        uint256 userEthAfter = user.balance;
        
        assertTrue(userEthAfter > userEthBefore, "ETH balance should increase");
        
        vm.stopPrank();
    }
}