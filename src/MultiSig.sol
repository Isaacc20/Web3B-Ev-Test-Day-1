// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./OwnerFunctions.sol";

contract MultiSig is OwnerFunctions {
    uint256 public threshold;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
        uint256 submissionTime;
        uint256 executionTime;
    }

    mapping(uint256 => mapping(address => bool)) public confirmed;
    mapping(uint256 => Transaction) public transactions;

    uint256 public constant TIMELOCK_DURATION = 1 hours;

    uint256 public txCount;

    event Submission(uint256 indexed txId);
    event Confirmation(uint256 indexed txId, address indexed owner);
    event Execution(uint256 indexed txId);

    constructor(
        address[] memory _owners,
        uint256 _threshold
    ) OwnerFunctions(_owners) {
        threshold = _threshold;
    }

    function submitTransaction(
        address to,
        uint256 value,
        bytes calldata data
    ) external onlyOwner {
        require(!paused, "This contract is paused");

        uint256 id = txCount++;

        transactions[id] = Transaction({
            to: to,
            value: value,
            data: data,
            executed: false,
            confirmations: 1,
            submissionTime: block.timestamp,
            executionTime: 0
        });

        confirmed[id][msg.sender] = true;

        emit Submission(id);
    }

    function confirmTransaction(uint256 txId) external onlyOwner {
        require(!paused, "paused");

        Transaction storage txn = transactions[txId];

        require(!txn.executed, "executed");
        require(!confirmed[txId][msg.sender], "already confirmed");

        confirmed[txId][msg.sender] = true;

        txn.confirmations++;

        if (txn.confirmations == threshold) {
            txn.executionTime = block.timestamp + TIMELOCK_DURATION;
        }

        emit Confirmation(txId, msg.sender);
    }

    function executeTransaction(uint256 txId) external onlyOwner {
        Transaction storage txn = transactions[txId];

        require(txn.confirmations >= threshold, "Not enough confirmations");
        require(!txn.executed, "Transaction already executed");
        require(
            block.timestamp >= txn.executionTime,
            "Transaction not ready to execute"
        );

        txn.executed = true;

        (bool s, ) = payable(txn.to).call{value: txn.value}(txn.data);

        require(s, "Transaction failed");

        emit Execution(txId);
    }
}
