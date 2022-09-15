// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract MultiSigWallet {
    event Deposit(address indexed sender, uint256 amount);
    event Submit(uint256 indexed txId);
    event Approve(address indexed guard, uint256 indexed txId);
    event Revoke(address indexed guard, uint256 indexed txID);
    event Execute(uint256 indexed txId);

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
    }
    address public admin; // contract admin
    // is allowed to add users remove users and set amount of required guards

    mapping(address => bool) public recAllow; // bool is user allowed to recover the contract
    address[] public guards; // guards can add tx to contract
    mapping(address => bool) public isGuard; // bool is user a guard
    uint256 public required; // number of guards required to execute a tx

    Transaction[] public transactions; // array of tx
    // ! txid => # guard address => ? bool approved
    mapping(uint256 => mapping(address => bool)) public approved; // mapping bool of user to tx
    // # user address => array position
    mapping(address => uint256) public oi;

    modifier onlyOwner() {
        require(isGuard[msg.sender], "not guard");
        _;
    }

    modifier txExists(uint256 txId) {
        require(txId < transactions.length, "tx does not exist");
        _;
    }

    modifier notApproved(uint256 txId) {
        require(!approved[txId][msg.sender], "tx already approved");
        _;
    }

    modifier notExecuted(uint256 txId) {
        require(!transactions[txId].executed, "tx already executed");
        _;
    }
    modifier onlyA() {
        require(admin == msg.sender);
        _;
    }

    // ["0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2","0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db","0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB","0x617F2E2fD72FD9D5503197092aC168c91465E7f2","0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"]
    constructor(
        address[] memory _guards,
        uint256 _required,
        address _admin
    ) {
        require(_guards.length > 0, "guards required");
        require(
            _required > 0 && _required <= _guards.length,
            "invalid required number of guards"
        );
        admin = _admin;
        for (uint256 i = 0; i < _guards.length; i++) {
            address guard = _guards[i];
            require(guard != address(0), "invalid guard");
            require(!isGuard[guard], "guard not unique");
            oi[guard] = i;
            recAllow[guard] = false;
            isGuard[guard] = true;
            guards.push(guard);
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
    function setRequired(uint256 _req) external onlyA returns (uint256) {
        require(guards.length > 0, "guards required");
        require(
            _req > 0 && _req <= guards.length,
            "invalid required number of guards"
        );
        required = _req;
        return _req;
    }

    function submit(
        address to,
        uint256 value,
        bytes memory data
    ) public returns (uint256 txId) {
        require(isGuard[msg.sender], "not guard");
        txId = transactions.length;
        transactions.push(
            Transaction({to: to, value: value, data: data, executed: false})
        );
        emit Submit(transactions.length - 1);
    }

    function showOwners() external view returns (address[] memory) {
        return guards;
    }

    function removeOwner(address _guard) external onlyA returns (uint256) {
        uint256 oindex = oi[_guard];
        uint256 len = guards.length - 1;
        oi[_guard] = 999;
        isGuard[_guard] = false;
        if (oindex != len) {
            // SWAP LAST
            address hold = guards[len];
            oi[hold] = oindex;
            guards[oindex] = hold;
        }
        // DROP LAST
        delete guards[len];
        return guards.length;
    }

    function addOwner(address _guard) external onlyA returns (address) {
        uint256 o = guards.length;
        guards.push(_guard);
        oi[_guard] = o;
        recAllow[_guard] = false;
        isGuard[_guard] = true;
        return guards[o];
    }

    function approve(uint256 txId)
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

    function _getApprovalCount(uint256 txId)
        internal
        view
        returns (uint256 count)
    {
        for (uint256 i = 0; i < guards.length; i++) {
            if (approved[txId][guards[i]]) {
                count += 1;
            }
        }
    }

    function execute(uint256 txId) external txExists(txId) notExecuted(txId) {
        require(_getApprovalCount(txId) >= required, "approvals < required");
        Transaction storage transaction = transactions[txId];

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "tx failed");

        emit Execute(txId);
    }

    function revoke(uint256 txId)
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
