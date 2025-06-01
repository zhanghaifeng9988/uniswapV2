// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TokenA} from "../src/token/ERC20Token1.sol";
import {TokenB} from "../src/token/ERC20Token2.sol";

contract ERC20TokenDeployScript is Script {
    function setUp() public {
        console.log(unicode"准备部署 TokenA 和 TokenB 到 Sepolia 测试网");
    }

    function run() public {
        vm.startBroadcast();
        
        // 部署 TokenA 合约
        TokenA tokenA = new TokenA();
        address tokenAAddress = address(tokenA);
        console.log(unicode"TokenA 已部署到地址:", tokenAAddress);
        
        // 部署 TokenB 合约
        TokenB tokenB = new TokenB();
        address tokenBAddress = address(tokenB);
        console.log(unicode"TokenB 已部署到地址:", tokenBAddress);
        
        vm.stopBroadcast();
        
        // 输出部署结果摘要
        console.log(unicode"\n部署摘要:");
        console.log(unicode"====================");
        console.log(unicode"TokenA (TKA) 地址:", tokenAAddress);
        console.log(unicode"TokenB (TKB) 地址:", tokenBAddress);
        console.log(unicode"====================");
    }
}