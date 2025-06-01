// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenA is ERC20, Ownable {
    uint8 private constant _decimals = 18;
    uint256 private constant _initialSupply = 10000 * 10**18; // 10000个代币，每个有18位小数
    
    constructor() ERC20("TokenA", "TKA") Ownable(msg.sender) {
        _mint(msg.sender, _initialSupply);
    }
    
    // 添加mint函数，方便后续测试时增发代币
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
    
    // 覆盖decimals函数，确保与Uniswap兼容
    function decimals() public pure override returns (uint8) {
        return _decimals;
    }
}