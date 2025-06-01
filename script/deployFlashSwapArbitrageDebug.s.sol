// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/arbitrage/flashSwapArbitrageDebug.sol";

contract DeployFlashSwapArbitrageDebug is Script {
    function run() external {
        // 直接使用 Anvil 的默认私钥
        uint256 deployerPrivateKey = 0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6;
        vm.startBroadcast(deployerPrivateKey);

        // 使用正确的已部署地址
        address pairA = 0xf8d7F2F2138A35f3a477E83c6CaC59ceCFc6D51d;  // PoolA
        address pairB = 0xA43F71AE864dA7AdA5B597aD8Ec43381Fd9F96B7;  // PoolB
        address tokenA = 0x5FbDB2315678afecb367f032d93F642f64180aa3;  // TokenA
        address tokenB = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512; // TokenB
        address routerB = 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707; // RouterB

        // 部署合约
        FlashSwapArbitrageDebug arbitrage = new FlashSwapArbitrageDebug(
            pairA,
            pairB,
            tokenA,
            tokenB,
            routerB
        );

        console.log("FlashSwapArbitrageDebug deployed at:", address(arbitrage));
        console.log("PairA:", pairA);
        console.log("PairB:", pairB);
        console.log("TokenA:", tokenA);
        console.log("TokenB:", tokenB);
        console.log("RouterB:", routerB);

        vm.stopBroadcast();
    }
}