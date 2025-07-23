// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

contract Random {
    uint256 public nonce = 0;

    function GetRandomNumber() public returns (uint) {
        nonce ++;
        return uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce))) % 100;
    }
}