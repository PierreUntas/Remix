// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {

    constructor(uint256 initialSupply) ERC20("Pierre Arens Token", "PAT") {
        _mint(msg.sender, initialSupply);
    }
} 