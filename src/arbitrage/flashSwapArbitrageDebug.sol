// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "../uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "../uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "../token/interfaces/IERC20.sol";
import "forge-std/console.sol";

contract FlashSwapArbitrageDebug {
    address public immutable pairA;
    address public immutable pairB;
    address public immutable tokenA;
    address public immutable tokenB;
    address public immutable routerB;
    
    constructor(
        address _pairA,
        address _pairB,
        address _tokenA,
        address _tokenB,
        address _routerB
    ) {
        pairA = _pairA;
        pairB = _pairB;
        tokenA = _tokenA;
        tokenB = _tokenB;
        routerB = _routerB;
    }
    
    function startArbitrage(uint256 amount) external {
        console.log("=== Starting Arbitrage ===");
        console.log("Amount to borrow:", amount);
        
        // 检查初始状态
        _logReserves();
        
        // 确定借哪个token
        address token0 = IUniswapV2Pair(pairA).token0();
        address token1 = IUniswapV2Pair(pairA).token1();
        
        console.log("PairA token0:", token0);
        console.log("PairA token1:", token1);
        console.log("TokenA:", tokenA);
        console.log("TokenB:", tokenB);
        
        uint256 amount0Out = tokenA == token0 ? amount : 0;
        uint256 amount1Out = tokenA == token1 ? amount : 0;
        
        console.log("amount0Out:", amount0Out);
        console.log("amount1Out:", amount1Out);
        
        bytes memory data = abi.encode(amount);
        IUniswapV2Pair(pairA).swap(amount0Out, amount1Out, address(this), data);
    }
    
    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        console.log("=== In uniswapV2Call ===");
        console.log("sender:", sender);
        console.log("amount0:", amount0);
        console.log("amount1:", amount1);
        
        require(msg.sender == pairA, "Invalid caller");
        require(sender == address(this), "Invalid sender");
        
        uint256 borrowedAmount = abi.decode(data, (uint256));
        console.log("borrowedAmount:", borrowedAmount);
        
        // 检查我们收到的TokenA数量
        uint256 tokenABalance = IERC20(tokenA).balanceOf(address(this));
        console.log("Received TokenA:", tokenABalance);
        
        // 在PairB中交换TokenA -> TokenB
        IERC20(tokenA).approve(routerB, tokenABalance);
        
        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;
        
        console.log("Swapping on RouterB...");
        uint256[] memory amounts = IUniswapV2Router02(routerB).swapExactTokensForTokens(
            tokenABalance,
            0, // 接受任何数量的TokenB
            path,
            address(this),
            block.timestamp + 300
        );
        
        uint256 tokenBReceived = amounts[1];
        console.log("TokenB received:", tokenBReceived);
        
        // 计算需要偿还的TokenA数量（包括0.3%手续费）
        uint256 amountToRepay = borrowedAmount * 1000 / 997 + 1;
        console.log("Amount to repay:", amountToRepay);
        
        // 直接用TokenB在PairA中换取足够的TokenA来偿还
        // 计算需要多少TokenB来获得足够的TokenA
        (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(pairA).getReserves();
        address token0 = IUniswapV2Pair(pairA).token0();
        
        uint256 tokenBNeeded;
        if (tokenA == token0) {
            // 需要TokenB换TokenA，所以TokenB是输入，TokenA是输出
            tokenBNeeded = _getAmountIn(amountToRepay, reserve1, reserve0);
        } else {
            // 需要TokenB换TokenA，所以TokenB是输入，TokenA是输出  
            tokenBNeeded = _getAmountIn(amountToRepay, reserve0, reserve1);
        }
        
        console.log("TokenB needed for repayment:", tokenBNeeded);
        require(tokenBReceived >= tokenBNeeded, "Insufficient TokenB for repayment");
        
        // 直接转账TokenB到PairA进行偿还
        IERC20(tokenB).transfer(pairA, tokenBNeeded);
        
        // 检查最终余额
        uint256 finalTokenA = IERC20(tokenA).balanceOf(address(this));
        uint256 finalTokenB = IERC20(tokenB).balanceOf(address(this));
        console.log("Final TokenA balance:", finalTokenA);
        console.log("Final TokenB balance:", finalTokenB);
        console.log("TokenB profit:", finalTokenB);
        
        console.log("=== Arbitrage Complete ===");
    }
    
    // 添加计算输入数量的辅助函数
    function _getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) 
        internal pure returns (uint256 amountIn) {
        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }
    
    function _logReserves() internal view {
        (uint256 reserveA0, uint256 reserveA1,) = IUniswapV2Pair(pairA).getReserves();
        (uint256 reserveB0, uint256 reserveB1,) = IUniswapV2Pair(pairB).getReserves();
        
        console.log("PairA reserves:", reserveA0, reserveA1);
        console.log("PairB reserves:", reserveB0, reserveB1);
    }
}