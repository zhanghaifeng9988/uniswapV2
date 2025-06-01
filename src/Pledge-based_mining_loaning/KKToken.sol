// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IToken.sol";

/**
 * @title KK Token
 * @dev ERC20 token that can be minted by authorized contracts
 */
contract KKToken is ERC20, Ownable, IToken {
    mapping(address => bool) public minters;

    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);

    constructor() ERC20("KK Token", "KK") Ownable(msg.sender) {}

    modifier onlyMinter() {
        require(minters[msg.sender], "KKToken: caller is not a minter");
        _;
    }

    /**
     * @dev Add a minter
     */
    function addMinter(address minter) external onlyOwner {
        minters[minter] = true;
        emit MinterAdded(minter);
    }

    /**
     * @dev Remove a minter
     */
    function removeMinter(address minter) external onlyOwner {
        minters[minter] = false;
        emit MinterRemoved(minter);
    }

    /**
     * @dev Mint tokens to an address
     */
    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
    }
}