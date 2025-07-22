// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

contract People {

    struct Person {
        string name;
        uint256 age;
    }

    Person[] public persons;

    function add (string memory _name, uint256 _age) public {
        Person memory person = Person(_name, _age);
        persons.push(person);
    }

    function remove () public {
        persons.pop();
    }

    event Authorized (address _address);
    // ex: emit Authorized (msg.sender)
}

    // ENUM
    // enum Sex {men, women, none} 
    // Sex public me = Sex.women;
