// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

contract Admin is Ownable {
    address public admin;
    mapping(address => bool) public whitelistGroup;
    mapping(address => bool) public blacklistGroup;

    constructor() Ownable (msg.sender) {
        admin = msg.sender;
    }
    
    event Whitelisted(address _account);
    event Blacklisted(address _account );

    function whitelist(address _account) public onlyOwner {
        require(!blacklistGroup[_account], "account is blacklisted");
        require(!whitelistGroup[_account], "account is already whitelisted");
        whitelistGroup[_account] = true;
        emit Whitelisted(_account);
    }

    function blacklist(address _account) public onlyOwner {
        require(!whitelistGroup[_account], "account is whitelisted");
        require(!blacklistGroup[_account], "account is already blacklisted");
        if(whitelistGroup[_account] == true) {
             whitelistGroup[_account] = false;
        }
        blacklistGroup[_account] = true;
        emit Blacklisted(_account);
    }

    function isWhitelisted(address _account) public view returns(bool) {
        return whitelistGroup[_account];
    }

    function isBlacklisted(address _account) public view returns(bool) {
        return blacklistGroup[_account];
    }
}