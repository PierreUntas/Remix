// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import "./5_Token.sol";

contract Crowdsale {
    uint public rate = 200;
    Token public token;

    constructor(uint256 initialSypply) {
        token = new Token(initialSypply);
    }

    receive() external payable {
        require(msg.value > 0.2 ether, "you can send less than 0.2 ETH");
        distribute(msg.value);
    }

    function distribute(uint256 amount) internal {
        token.transfer(msg.sender, amount * rate);
    }
}