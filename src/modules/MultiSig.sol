// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Governance.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MultiSig is Governance, EIP712, Nonces {
    using ECDSA for bytes32;

    address[] public owners;
    uint256 public threshold;
    mapping(address => bool) public isOwner;
    mapping(uint => mapping(address => bool)) public approvedByOwner;

    bytes32 private constant APPROVAL_TYPEHASH =
        keccak256("Approval(uint256 proposalId,uint256 nonce)");

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    constructor(
        address _token,
        address[] memory _owners,
        uint256 _threshold
    ) Governance(_token) EIP712("TreasuryExecutor", "1") {
        require(
            _threshold > 0 && _threshold <= _owners.length,
            "Invalid threshold"
        );
        threshold = _threshold;
        for (uint i = 0; i < _owners.length; i++) {
            isOwner[_owners[i]] = true;
            owners.push(_owners[i]);
        }
    }

    function approveProposal(uint256 proposalId) external onlyOwner {
        _approve(proposalId, msg.sender);
    }

    function approveBySignature(
        address signer,
        uint256 proposalId,
        bytes calldata signature
    ) external override {
        bytes32 structHash = keccak256(
            abi.encode(APPROVAL_TYPEHASH, proposalId, _useNonce(signer))
        );
        bytes32 hash = _hashTypedDataV4(structHash);
        address recoveredSigner = hash.recover(signature);

        require(recoveredSigner == signer, "Invalid signature");
        require(isOwner[signer], "Signer not an owner");
        _approve(proposalId, signer);
    }

    function _approve(uint256 proposalId, address owner) internal {
        Proposal storage proposal = proposals[proposalId];

        require(
            proposal.status == ProposalStatus.Passed,
            "Voting hasn't passed"
        );
        require(!approvedByOwner[proposalId][owner], "You already approved");
        require(
            proposal.status != ProposalStatus.Approved,
            "Proposal already approved"
        );

        approvedByOwner[proposalId][owner] = true;
        proposal.approvals++;

        emit Approval(proposalId, owner);

        if (proposal.approvals >= threshold) {
            proposal.status = ProposalStatus.Approved;
        }
    }
}
