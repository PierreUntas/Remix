// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

contract Alyra {
    address UserAddress;

    function SetUserAddress(address _address) external {
        UserAddress = _address;
    }

    function GetBalance (address _address) public view returns (uint256) {
        return _address.balance;
    }

    function sendViaTransfer(address payable _to) public payable {
        _to.transfer(msg.value);
    }

     function sendViaSend(address payable _to) public payable {
         bool sent = _to.send(msg.value);
         require (sent, "Failed to send Ether");
    }

    function sendViaCall(address payable _to) external payable {
        (bool sent,) = _to.call{value: msg.value}(""); 
        require(sent, "Failed to send Ether");
    }

    receive() external payable {}

    fallback() external payable {}
}