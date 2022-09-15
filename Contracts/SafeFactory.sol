// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;
import "./MultiSigWallet.sol";

contract SafeFactory {
    MultiSigWallet public multi;

    mapping(uint256 => address) public safeAdr;
    mapping(uint256 => address) public adminAdr;
    mapping(address => uint256) public safeCount;
    mapping(address => mapping(uint256 => address)) public mySafes;
    uint256 s;
    address admin;

    constructor() {
        admin = msg.sender;
        s = 0;
    }

    function createSafe(
        address[] memory _adrs,
        uint256 _req,
        address _admin
    ) external returns (bool) {
        multi = new MultiSigWallet(_adrs, _req, _admin);
        safeAdr[s] = address(multi);
        adminAdr[s] = msg.sender;
        mySafes[_admin][safeCount[_admin]] = safeAdr[s];
        safeCount[_admin]++;
        s++;
        return true;
    }
}

