// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/token/OpenspaceNFT.sol";

contract DeployOpenspaceNFT is Script {
    function run() external {
        // 使用keystore时，不需要从环境变量读取私钥
        // Foundry会自动处理keystore解锁
        vm.startBroadcast();
        
        // 部署NFT合约
        OpenspaceNFT nft = new OpenspaceNFT();
        
        console.log("OpenspaceNFT deployed to:", address(nft));
        console.log("Owner:", nft.owner());
        console.log("Presale status:", nft.isPresaleActive());
        console.log("Next Token ID:", nft.nextTokenId());
        
        vm.stopBroadcast();
    }
}