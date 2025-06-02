// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title VotingToken
 * @dev ERC20代币，支持投票功能，用于DAO治理
 */
contract VotingToken is ERC20, ERC20Permit, ERC20Votes, Ownable {
    
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address initialOwner
    ) 
        ERC20(name, symbol)
        ERC20Permit(name)
        Ownable(initialOwner)
    {
        _mint(initialOwner, initialSupply);
    }

    /**
     * @dev 铸造新代币（仅所有者可调用）
     */
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    /**
     * @dev 销毁代币（仅所有者可调用）
     */
    function burn(uint256 amount) public onlyOwner {
        _burn(msg.sender, amount);
    }

    // 以下函数是必需的重写
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, value);
    }

    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}