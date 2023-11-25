// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


/**
 * @notice ERC20 token used in Fire Cat Finance.
 * @dev Total supply capped at 200M.
 */
contract TestToken is Ownable, ERC20 {
    constructor(uint256 initialSupply) ERC20("Test Token", "tToken") Ownable(msg.sender) { 
        _mint(msg.sender, initialSupply * (10 ** uint256(decimals())));
        _transferOwnership(msg.sender);
    }
}
