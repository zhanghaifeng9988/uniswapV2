// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract OpenspaceNFT is ERC721, Ownable {
    bool public isPresaleActive = false;  // 默认关闭
    uint256 public nextTokenId;

    // 添加预售状态事件记录
    event PresaleStatusChanged(bool status);

    constructor() ERC721("OpenspaceNFT", "OSNFT") Ownable(msg.sender) {
        nextTokenId = 1;//初始化第一个NFT的ID为1
    }

    // 启用预售
    //只有合约所有者可以激活预售
    function enablePresale() external onlyOwner {
        isPresaleActive = true;
        emit PresaleStatusChanged(true);
    }

    //预售功能
    function presale(uint256 amount) external payable {
        require(isPresaleActive, "Presale is not active");
        //所有者限制 ：合约所有者不能参与预售
        require(msg.sender != owner(), "Disabled for owner");
        //价格验证 ：每个NFT价格为0.01 ETH，总支付金额必须正确
        require(amount * 0.01 ether == msg.value, "Invalid amount");
        //供应量限制 ：总供应量不能超过1024个NFT
        require(amount + nextTokenId <= 1024, "Not enough tokens left");

        uint256 _nextId = nextTokenId;
        for (uint256 i = 0; i < amount; i++) {
            _safeMint(msg.sender, _nextId);
            _nextId++;
        }
        nextTokenId = _nextId;
    }

    //提取资金只有所有者可以提取合约中的ETH
    function withdraw() external onlyOwner {
        (bool success,) = msg.sender.call{ value: address(this).balance }("");
        require(success, "Transfer failed");
    }
}

