// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {MEME_Inscription} from "../src/token/MEME_Inscription.sol";
import {MEME_Token} from "../src/token/MEME_Token.sol";
import {TWAP_MEME} from "../src/TWAP/TWAP_MEME.sol";
import {WETH9} from "../src/uniswap/v2-periphery/contracts/test/WETH9.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract TWAPTest is Test {
    // 合约实例
    MEME_Inscription public memeInscription;
    TWAP_MEME public twapMeme;
    IUniswapV2Factory public uniswapV2Factory;
    IUniswapV2Router02 public uniswapV2Router;
    WETH9 public weth;
    
    // 测试账户
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");
    address public user4 = makeAddr("user4");
    address public owner = makeAddr("owner");
    
    // MEME代币地址
    address public memeToken;
    
    // 常量
    uint256 public constant INITIAL_ETH_LIQUIDITY = 10 ether;
    uint256 public constant INITIAL_MEME_LIQUIDITY = 1000000 * 10**18; // 100万MEME
    uint256 public constant SECOND_ETH_LIQUIDITY = 5 ether;
    uint256 public constant SECOND_MEME_LIQUIDITY = 400000 * 10**18; // 40万MEME
    uint256 public constant FIRST_BUY_AMOUNT = 1 ether;
    uint256 public constant SECOND_BUY_AMOUNT = 2 ether;
    uint256 public constant THIRD_BUY_AMOUNT = 3 ether;
    
    // 价格快照描述
    string constant INITIAL_LIQUIDITY_DESC = "Initial Liquidity";
    string constant SECOND_LIQUIDITY_DESC = "Second Liquidity";
    string constant FIRST_BUY_DESC = "First Buy";
    string constant SECOND_BUY_DESC = "Second Buy";
    string constant THIRD_BUY_DESC = "Third Buy";
    
    function setUp() public {
        // 部署WETH9合约
        weth = new WETH9();
        
        // 部署Uniswap V2工厂和路由合约
        uniswapV2Factory = IUniswapV2Factory(deployCode("UniswapV2Factory.sol", abi.encode(address(0))));
        uniswapV2Router = IUniswapV2Router02(deployCode("UniswapV2Router02.sol", abi.encode(address(uniswapV2Factory), address(weth))));
        
        // 部署MEME铭文合约
        vm.prank(owner);
        memeInscription = new MEME_Inscription(uniswapV2Factory, address(uniswapV2Router));
        
        // 部署TWAP_MEME合约
        twapMeme = new TWAP_MEME(address(uniswapV2Factory), address(weth));
        
        // 为测试用户转账ETH
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
        vm.deal(user4, 100 ether);
        vm.deal(owner, 100 ether); // 为owner地址分配ETH
    }
    
    function test_TWAPPriceChanges() public {
        // 第一步：初始流动性添加
        _addInitialLiquidity();
        
        // 第二步：二次流动性添加
        _addSecondLiquidity();
        
        // 第三步：第一次购买MEME
        _firstBuyMEME();
        
        // 第四步：第二次购买MEME
        _secondBuyMEME();
        
        // 第五步：第三次购买MEME
        _thirdBuyMEME();
        
        // 第六步：汇总价格变化
        _summarizePriceChanges();
    }
    
    // 添加初始流动性
    // 添加初始流动性
    function _addInitialLiquidity() internal {
        // 部署MEME代币
        vm.prank(user1);
        memeToken = memeInscription.deployInscription(
            "MEME Token", 
            1000000,    // totalSupply: 总供应量100万
            100,        // perMint: 每次铸造100个
            0.0001 ether // price: 每个代币0.0001 ETH
        );
        
        // 铸造MEME代币
        vm.prank(user1);
        memeInscription.mintInscription{value: 0.01 ether}(memeToken); // 铸造100个MEME，花费0.01 ETH
        
        // 获取MEME代币实例并授权
        vm.startPrank(user1);
        MEME_Token token = MEME_Token(memeToken);
        uint256 userBalance = token.balanceOf(user1);
        token.approve(address(memeInscription), userBalance);
        
        // 添加初始流动性
        memeInscription.addLiquidity{
            value: INITIAL_ETH_LIQUIDITY
        }(
            memeToken,
            userBalance,  // tokenAmount
            0,           // amountTokenMin: 允许滑点
            0            // amountETHMin: 允许滑点
        );
        vm.stopPrank();
        
        // 初始化TWAP合约的交易对
        twapMeme.initializePair(memeToken);
        
        // 记录初始流动性价格快照
        vm.warp(block.timestamp + 1); // 增加1秒
        twapMeme.takeSnapshot(INITIAL_LIQUIDITY_DESC);
        
        // 验证初始价格
        uint256 initialPrice = twapMeme.getCurrentPrice();
        console2.log("Initial Price (ETH/MEME):", initialPrice / 1e18);
        
        // 获取交易对地址
        address pair = uniswapV2Factory.getPair(memeToken, uniswapV2Router.WETH());
        assertNotEq(pair, address(0), "Pair not created");
    }
    
    // 添加二次流动性
    function _addSecondLiquidity() internal {
        // 铸造更多MEME代币
        vm.prank(user2);
        memeInscription.mintInscription{value: 0.01 ether}(memeToken); // 铸造100个MEME
        
        // 获取MEME代币实例并授权
        vm.startPrank(user2);
        MEME_Token token = MEME_Token(memeToken);
        uint256 userBalance = token.balanceOf(user2);
        token.approve(address(memeInscription), userBalance);
        
        // 添加二次流动性
        memeInscription.addLiquidity{
            value: SECOND_ETH_LIQUIDITY
        }(
            memeToken,
            userBalance,  // tokenAmount
            0,           // amountTokenMin: 允许滑点
            0            // amountETHMin: 允许滑点
        );
        vm.stopPrank();
        
        // 记录二次流动性价格快照
        vm.warp(block.timestamp + 1); // 增加1秒
        twapMeme.takeSnapshot(SECOND_LIQUIDITY_DESC);
        
        // 验证二次流动性后的价格
        uint256 secondPrice = twapMeme.getCurrentPrice();
        console2.log("Second Liquidity Price (ETH/MEME):", secondPrice / 1e18);
    }
    
    // 第一次购买MEME
    function _firstBuyMEME() internal {
        // 用户3购买MEME
        vm.prank(user3);
        memeInscription.buyMeme{value: FIRST_BUY_AMOUNT}(memeToken, 0);
        
        // 记录第一次购买后的价格快照
        vm.warp(block.timestamp + 1); // 增加1秒
        twapMeme.takeSnapshot(FIRST_BUY_DESC);
        
        // 验证第一次购买后的价格
        uint256 firstBuyPrice = twapMeme.getCurrentPrice();
        console2.log("First Buy Price (ETH/MEME):", firstBuyPrice / 1e18);
        
        // 获取用户3的MEME余额
        MEME_Token memeTokenContract = MEME_Token(memeToken);
        uint256 user3Balance = memeTokenContract.balanceOf(user3);
        console2.log("User3 MEME Balance after first buy:", user3Balance / 1e18);
    }
    
    // 第二次购买MEME
    function _secondBuyMEME() internal {
        // 用户4购买MEME
        vm.prank(user4);
        memeInscription.buyMeme{value: SECOND_BUY_AMOUNT}(memeToken, 0);
        
        // 记录第二次购买后的价格快照
        vm.warp(block.timestamp + 1); // 增加1秒
        twapMeme.takeSnapshot(SECOND_BUY_DESC);
        
        // 验证第二次购买后的价格
        uint256 secondBuyPrice = twapMeme.getCurrentPrice();
        console2.log("Second Buy Price (ETH/MEME):", secondBuyPrice / 1e18);
        
        // 获取用户4的MEME余额
        MEME_Token memeTokenContract = MEME_Token(memeToken);
        uint256 user4Balance = memeTokenContract.balanceOf(user4);
        console2.log("User4 MEME Balance after second buy:", user4Balance / 1e18);
    }
    
    // 第三次购买MEME
    function _thirdBuyMEME() internal {
        // 用户1再次购买MEME
        vm.prank(user1);
        memeInscription.buyMeme{value: THIRD_BUY_AMOUNT}(memeToken, 0);
        
        // 记录第三次购买后的价格快照
        vm.warp(block.timestamp + 1); // 增加1秒
        twapMeme.takeSnapshot(THIRD_BUY_DESC);
        
        // 验证第三次购买后的价格
        uint256 thirdBuyPrice = twapMeme.getCurrentPrice();
        console2.log("Third Buy Price (ETH/MEME):", thirdBuyPrice / 1e18);
        
        // 获取用户1的MEME余额
        MEME_Token memeTokenContract = MEME_Token(memeToken);
        uint256 user1Balance = memeTokenContract.balanceOf(user1);
        console2.log("User1 MEME Balance after third buy:", user1Balance / 1e18);
    }
    
    // 汇总价格变化
    function _summarizePriceChanges() internal {
        // 获取快照数量
        uint256 snapshotCount = twapMeme.getSnapshotCount();
        console2.log("Total snapshots taken:", snapshotCount);
        
        // 输出每个快照的价格
        for (uint256 i = 0; i < snapshotCount; i++) {
            (uint256 timestamp, uint256 price, string memory description) = twapMeme.getSnapshot(i);
            console2.log("Snapshot %s: %s - Price: %s wei", i, description, price);
        }
        
        // 计算TWAP价格
        // 从初始流动性到第三次购买的TWAP
        uint256 overallTWAP = twapMeme.calculateTWAP(0, snapshotCount - 1);
        console2.log("Overall TWAP (Initial to Third Buy):", overallTWAP / 1e18);
        
        // 从二次流动性到第三次购买的TWAP
        uint256 secondToThirdTWAP = twapMeme.calculateTWAP(1, snapshotCount - 1);
        console2.log("TWAP (Second Liquidity to Third Buy):", secondToThirdTWAP / 1e18);
        
        // 从第一次购买到第三次购买的TWAP
        uint256 firstBuyToThirdBuyTWAP = twapMeme.calculateTWAP(2, snapshotCount - 1);
        console2.log("TWAP (First Buy to Third Buy):", firstBuyToThirdBuyTWAP / 1e18);
        
        // 获取价格变化汇总
        (string[] memory descriptions, uint256[] memory prices, int256[] memory priceChanges) = twapMeme.summarizePriceChanges();
        
        // 输出价格变化汇总
        console2.log("\nPrice Changes Summary:");
        for (uint256 i = 0; i < descriptions.length; i++) {
            console2.log("%s: %s wei", descriptions[i], prices[i]);
            
            if (i > 0) {
                // 价格变化百分比已经放大了10000倍
                console2.log("  Change from previous: %s%%", priceChanges[i-1] / 100);
            }
        }
    }
}