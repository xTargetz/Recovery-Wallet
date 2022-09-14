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
    address public admin;
    mapping(address => bool) public recAllow;
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public required;

    Transaction[] public transactions;
    mapping(uint => mapping(address => bool)) public approved;
    mapping(address => uint256) public oi;

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
    modifier onlyA(){
        require(admin == msg.sender);
        _;
    }
    // ["0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2","0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db","0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB","0x617F2E2fD72FD9D5503197092aC168c91465E7f2","0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"]
    constructor(address[] memory _owners, uint _required) {
        require(_owners.length > 0, "owners required");
        require(_required > 0 && _required <= _owners.length, "invalid required number of owners");
        admin = msg.sender;
        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner not unique");
            oi[owner] = i;
            recAllow[owner] = false;
            isOwner[owner] = true;
            owners.push(owner);
        }
        recAllow[admin] = true;
        required = _required;
    }

    receive() external payable {
        if (msg.value > 0) {
            emit Deposit(msg.sender, msg.value);
        }
    }
    // set new number of required users only for Admin
    function setRequired(uint256 _req) onlyA() external returns(uint256){
        require(owners.length > 0, "owners required");
        require(_req > 0 && _req <= owners.length, "invalid required number of owners");
        required = _req;
        return _req;
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
    function showOwners() external view returns(address[] memory){
        return owners;
    }
    function removeOwner(address _owner) external onlyA() returns(uint256){
        uint256 oindex = oi[_owner];
        uint256 len = owners.length-1;
        oi[_owner] = 111;
        isOwner[_owner] = false;
        if(oindex != len)
        {
            // SWAP LAST 
            address hold = owners[len];
            owners[oindex] = hold;
        }
        // DROP LAST
        delete owners[len];
        return owners.length;
    }
    function addOwner(address _owner) external onlyA() returns(address){
        uint256 o = owners.length;
        owners.push(_owner);
        oi[_owner] = o;
        recAllow[_owner] = false;
        isOwner[_owner] = true;
        return owners[o];
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
        // execute(txId);
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
