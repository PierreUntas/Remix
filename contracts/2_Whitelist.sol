// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

contract Whitelist {
    mapping (address => bool) whitelist;

    event Authorize(address _address);
    event EthReceived(address _address, uint _amount);

    constructor(){
        whitelist[msg.sender] = true;
    }

    function authorize(address _address) check public {
        whitelist[_address] = true;
        emit Authorize(_address);
    }

    modifier check() {
        require(whitelist[msg.sender], "Not allowed");
        _;
    }
}