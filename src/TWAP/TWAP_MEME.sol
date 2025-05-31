// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title TWAP_MEME
 * @dev 用于检测MEME代币价格变化的TWAP（时间加权平均价格）合约
 * 记录从两次流动性上架到三次购买过程中的价格变化
 */
contract TWAP_MEME {
    // 存储价格快照的结构体
    struct PriceSnapshot {
        uint256 timestamp;
        uint256 price0Cumulative; // MEME/ETH 累积价格
        uint256 price1Cumulative; // ETH/MEME 累积价格
        uint112 reserve0;
        uint112 reserve1;
        string description; // 描述此次快照的场景（如"初始流动性"、"第一次购买"等）
    }
    
    // 存储所有价格快照
    PriceSnapshot[] public priceSnapshots;
    
    // Uniswap相关地址
    address public immutable factory;
    address public immutable WETH;
    address public memeToken;
    address public pair;
    
    // 记录MEME和WETH的顺序
    bool public memeIsToken0;
    
    // 事件
    event SnapshotTaken(uint256 snapshotId, string description, uint256 timestamp, uint256 price);
    event PairInitialized(address memeToken, address pair, bool memeIsToken0);
    
    /**
     * @dev 构造函数
     * @param _factory Uniswap V2工厂合约地址
     * @param _WETH WETH代币地址
     */
    constructor(address _factory, address _WETH) {
        factory = _factory;
        WETH = _WETH;
    }
    
    /**
     * @dev 初始化MEME代币对
     * @param _memeToken MEME代币地址
     */
    function initializePair(address _memeToken) external {
        require(_memeToken != address(0), "Invalid MEME token address");
        require(memeToken == address(0), "Pair already initialized");
        
        memeToken = _memeToken;
        pair = IUniswapV2Factory(factory).getPair(memeToken, WETH);
        require(pair != address(0), "Pair does not exist");
        
        // 确定MEME和WETH的顺序
        address token0 = IUniswapV2Pair(pair).token0();
        memeIsToken0 = (token0 == memeToken);
        
        emit PairInitialized(memeToken, pair, memeIsToken0);
    }
    
    /**
     * @dev 记录当前价格快照
     * @param description 描述此次快照的场景
     */
    function takeSnapshot(string memory description) external {
        require(pair != address(0), "Pair not initialized");
        
        // 获取当前累积价格和储备量
        (uint256 price0Cumulative, uint256 price1Cumulative, uint112 reserve0, uint112 reserve1) = getCurrentCumulativePrices();
        
        // 创建并存储快照
        PriceSnapshot memory snapshot = PriceSnapshot({
            timestamp: block.timestamp,
            price0Cumulative: price0Cumulative,
            price1Cumulative: price1Cumulative,
            reserve0: reserve0,
            reserve1: reserve1,
            description: description
        });
        
        priceSnapshots.push(snapshot);
        
        // 计算并发出当前价格事件
        uint256 currentPrice = getCurrentPrice();
        emit SnapshotTaken(priceSnapshots.length - 1, description, block.timestamp, currentPrice);
    }
    
    /**
     * @dev 获取当前累积价格和储备量
     */
    function getCurrentCumulativePrices() public view returns (uint256 price0Cumulative, uint256 price1Cumulative, uint112 reserve0, uint112 reserve1) {
        price0Cumulative = IUniswapV2Pair(pair).price0CumulativeLast();
        price1Cumulative = IUniswapV2Pair(pair).price1CumulativeLast();
        
        // 获取当前储备量
        uint32 blockTimestampLast;
        (reserve0, reserve1, blockTimestampLast) = IUniswapV2Pair(pair).getReserves();
    }
    
    /**
     * @dev 获取当前MEME/ETH价格（以wei为单位）
     */
    function getCurrentPrice() public view returns (uint256) {
        (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pair).getReserves();
        
        if (memeIsToken0) {
            // 如果MEME是token0，价格 = reserve1(WETH) / reserve0(MEME)
            return (uint256(reserve1) * 1e18) / uint256(reserve0);
        } else {
            // 如果MEME是token1，价格 = reserve0(WETH) / reserve1(MEME)
            return (uint256(reserve0) * 1e18) / uint256(reserve1);
        }
    }
    
    /**
     * @dev 计算两个快照之间的TWAP价格
     * @param startIndex 起始快照索引
     * @param endIndex 结束快照索引
     */
    function calculateTWAP(uint256 startIndex, uint256 endIndex) public view returns (uint256) {
        require(startIndex < priceSnapshots.length && endIndex < priceSnapshots.length, "Invalid snapshot indices");
        require(startIndex < endIndex, "Start index must be less than end index");
        
        PriceSnapshot memory startSnapshot = priceSnapshots[startIndex];
        PriceSnapshot memory endSnapshot = priceSnapshots[endIndex];
        
        uint256 timeElapsed = endSnapshot.timestamp - startSnapshot.timestamp;
        require(timeElapsed > 0, "Time elapsed must be greater than 0");
        
        uint256 priceCumulativeDelta;
        if (memeIsToken0) {
            // 如果MEME是token0，使用price1Cumulative (ETH/MEME)
            priceCumulativeDelta = endSnapshot.price1Cumulative - startSnapshot.price1Cumulative;
        } else {
            // 如果MEME是token1，使用price0Cumulative (ETH/MEME)
            priceCumulativeDelta = endSnapshot.price0Cumulative - startSnapshot.price0Cumulative;
        }
        
        // 计算TWAP价格 (以wei为单位)
        return (priceCumulativeDelta / timeElapsed) * 1e18 / 2**112;
    }
    
    /**
     * @dev 获取快照数量
     */
    function getSnapshotCount() external view returns (uint256) {
        return priceSnapshots.length;
    }
    
    /**
     * @dev 获取快照信息
     * @param index 快照索引
     */
    function getSnapshot(uint256 index) external view returns (
        uint256 timestamp,
        uint256 price,
        string memory description
    ) {
        require(index < priceSnapshots.length, "Invalid snapshot index");
        
        PriceSnapshot memory snapshot = priceSnapshots[index];
        
        // 计算该快照时的即时价格
        uint256 spotPrice;
        if (memeIsToken0) {
            // 如果MEME是token0，价格 = reserve1(WETH) / reserve0(MEME)
            spotPrice = (uint256(snapshot.reserve1) * 1e18) / uint256(snapshot.reserve0);
        } else {
            // 如果MEME是token1，价格 = reserve0(WETH) / reserve1(MEME)
            spotPrice = (uint256(snapshot.reserve0) * 1e18) / uint256(snapshot.reserve1);
        }
        
        return (snapshot.timestamp, spotPrice, snapshot.description);
    }
    
    /**
     * @dev 总结价格变化情况
     * 返回所有快照的价格和描述，以及相邻快照之间的价格变化百分比
     */
    function summarizePriceChanges() external view returns (
        string[] memory descriptions,
        uint256[] memory prices,
        int256[] memory priceChanges
    ) {
        uint256 count = priceSnapshots.length;
        require(count > 0, "No snapshots available");
        
        descriptions = new string[](count);
        prices = new uint256[](count);
        priceChanges = new int256[](count > 1 ? count - 1 : 0);
        
        // 填充价格和描述数组
        for (uint256 i = 0; i < count; i++) {
            PriceSnapshot memory snapshot = priceSnapshots[i];
            
            // 计算该快照时的即时价格
            uint256 spotPrice;
            if (memeIsToken0) {
                spotPrice = (uint256(snapshot.reserve1) * 1e18) / uint256(snapshot.reserve0);
            } else {
                spotPrice = (uint256(snapshot.reserve0) * 1e18) / uint256(snapshot.reserve1);
            }
            
            prices[i] = spotPrice;
            descriptions[i] = snapshot.description;
            
            // 计算价格变化百分比（相对于前一个快照）
            if (i > 0) {
                uint256 prevPrice = prices[i-1];
                if (prevPrice > 0) {
                    // 计算价格变化百分比，放大10000倍以保留小数点后两位
                    if (spotPrice > prevPrice) {
                        // 价格上涨
                        priceChanges[i-1] = int256(((spotPrice - prevPrice) * 10000) / prevPrice);
                    } else {
                        // 价格下跌
                        priceChanges[i-1] = -int256(((prevPrice - spotPrice) * 10000) / prevPrice);
                    }
                }
            }
        }
        
        return (descriptions, prices, priceChanges);
    }
}