// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract TokenWithFee is ERC20 {
    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }
    
    function _update(address sender, address recipient, uint256 amount) internal virtual override {
        if (sender != address(0) && recipient != address(0)) {
            // 收取 1% 的转账费用
            uint256 fee = amount / 100;
            uint256 netAmount = amount - fee;
            
            super._update(sender, address(this), fee);
            super._update(sender, recipient, netAmount);
        } else {
            super._update(sender, recipient, amount);
        }
    }
}