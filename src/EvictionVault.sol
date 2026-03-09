// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./MultiSig.sol";

contract EvictionVault is MultiSig {
    mapping(address => uint256) public balances;

    mapping(address => bool) public claimed;

    mapping(bytes32 => bool) public usedHashes;

    event Deposit(address indexed depositor, uint256 amount);
    event Withdrawal(address indexed withdrawer, uint256 amount);
    event Claim(address indexed claimant, uint256 amount);

    constructor(
        address[] memory _owners,
        uint256 _threshold
    ) payable MultiSig(_owners, _threshold) {
        totalVaultValue = msg.value;
    }

    receive() external payable {
        balances[msg.sender] += msg.value;
        totalVaultValue += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function deposit() external payable {
        balances[msg.sender] += msg.value;
        totalVaultValue += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        require(!paused, "paused");
        require(balances[msg.sender] >= amount, "insufficient balance");

        balances[msg.sender] -= amount;
        totalVaultValue -= amount;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "transfer failed");

        emit Withdrawal(msg.sender, amount);
    }

    function claim(bytes32[] calldata proof, uint256 amount) external {
        require(!paused, "paused");

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount));
        bytes32 computed = MerkleProof.processProof(proof, leaf);

        require(computed == merkleRoot, "Invalid proof");
        require(!claimed[msg.sender], "Already claimed");
        require(amount <= totalVaultValue, "Insufficient vault balance");
        require(amount > 0, "Invalid amount");

        claimed[msg.sender] = true;
        totalVaultValue -= amount;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "transfer failed");

        emit Claim(msg.sender, amount);
    }

    function verifySignature(
        address signer,
        bytes32 messageHash,
        bytes memory signature
    ) external pure returns (bool) {
        return ECDSA.recover(messageHash, signature) == signer;
    }
}
