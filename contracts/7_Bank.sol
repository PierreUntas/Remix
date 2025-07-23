// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

contract Bank {
    mapping(address => uint256) public balances;

    function deposit(uint256 _amount) public {
        balances[msg.sender] += _amount;
    }

    function transfer(address _to, uint256 _amount) public {
        require(_to != address(0), "You can't burn your tokens");
        require(balances[msg.sender] >= _amount);
        balances[msg.sender] -= _amount;
        balances[_to] += _amount;
    }

    function balanceOf(address _addr) public view returns(uint256){
        return balances[_addr];
    }
}