// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

contract OwnerFunctions {
    address[] public owners;
    mapping(address => bool) public isOwner;

    bytes32 public merkleRoot;
    bool public paused;
    uint256 public totalVaultValue;

    event MerkleRootSet(bytes32 indexed newRoot);

    constructor(address[] memory _owners) {
        require(_owners.length > 0, "no owners");
        for (uint i = 0; i < _owners.length; i++) {
            address o = _owners[i];
            require(o != address(0), "zero address");
            isOwner[o] = true;
            owners.push(o);
        }
    }

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    function setMerkleRoot(bytes32 root) external onlyOwner {
        merkleRoot = root;
        emit MerkleRootSet(root);
    }

    function pause() external onlyOwner {
        paused = true;
    }

    function unpause() external onlyOwner {
        paused = false;
    }

    function emergencyWithdrawAll() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "Vault balance is empty");

        // Reset state before interaction (CEI)
        totalVaultValue = 0;

        (bool success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "Withdrawal failed");
    }
}
