// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/arbitrage/flashSwapArbitrageDebug.sol";

contract FlashSwapArbitrageDebugTest is Test {
    FlashSwapArbitrageDebug arbitrage;
    
    function setUp() public {
        // 使用已部署的合约地址
        arbitrage = FlashSwapArbitrageDebug(0x700b6A60ce7EaaEA56F065753d8dcB9653dbAD35);
    }
    
    function testArbitrage() public {
        // 直接调用套利函数，不需要 fork
        arbitrage.startArbitrage(100000000000000000); // 0.1 ether
    }
}