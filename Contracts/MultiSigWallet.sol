// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract MultiSigWallet {
    event Deposit(address indexed sender, uint amount);
    event Submit(uint indexed txId);
    event Approve(address indexed owner, uint indexed txId);
    event Revoke(address indexed owner, uint indexed txID);
    event Execute(uint indexed txId);

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
    }

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public required;

    Transaction[] public transactions;
    mapping(uint => mapping(address => bool)) public approved;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier txExists(uint txId) {
        require(txId < transactions.length, "tx does not exist");
        _;
    }

    modifier notApproved(uint txId) {
        require(!approved[txId][msg.sender], "tx already approved");
        _;
    }

    modifier notExecuted(uint txId) {
        require(!transactions[txId].executed, "tx already executed");
        _;
    }

    constructor(address[] memory _owners, uint _required) {
        require(_owners.length > 0, "owners required");
        require(_required > 0 && _required <= _owners.length, "invalid required number of owners");

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        required = _required;
    }

    receive() external payable {
        if (msg.value > 0) {
            emit Deposit(msg.sender, msg.value);
        }
    }

    function submit(address to, uint value, bytes memory data) public returns (uint txId) {
        require(isOwner[msg.sender], "not owner");
        txId = transactions.length;
        transactions.push(Transaction({
            to: to,
            value: value,
            data: data,
            executed: false
        }));
        emit Submit(transactions.length - 1);
    }

    function approve(uint txId)
        external
        onlyOwner
        txExists(txId)
        notExecuted(txId)
        notApproved(txId)
    {
        approved[txId][msg.sender] = true;
        emit Approve(msg.sender, txId);
        execute(txId);
    }

    function _getApprovalCount(uint txId) internal view returns (uint count) {
        for (uint i = 0; i < owners.length; i++) {
            if (approved[txId][owners[i]]) {
                count += 1;
            }
        }
    }

    function execute(uint txId) external txExists(txId) notExecuted(txId) {
        require(_getApprovalCount(txId) >= required, "approvals < required");
        Transaction storage transaction = transactions[txId];

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "tx failed");

        emit Execute(txId);
    }
    
    function revoke(uint txId)
        external
        onlyOwner
        txExists(txId)
        notExecuted(txId)
        notApproved(txId)
    {
        require(approved[txId][msg.sender], "tx not approved");
        approved[txId][msg.sender] = false;
        emit Revoke(msg.sender, txId);
    }
}



