// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IGovernance {
    enum ProposalStatus {
        Pending,
        Passed,
        Failed,
        Approved,
        Rejected,
        Executed
    }

    struct Proposal {
        uint id;
        address proposer;
        address target; // The contract to call (e.g. token contract or multisig)
        address token; // The token to transfer (if applicable)
        uint value; // ETH value
        bytes data; // Calldata for the execution
        uint startTime;
        uint endTime;
        uint forVotes;
        uint againstVotes;
        uint approvals; // Number of multisig signatures
        ProposalStatus status;
    }

    event ProposalCreated(
        uint id,
        address proposer,
        address target,
        address token,
        uint value,
        uint startTime,
        uint endTime
    );
    event VoteCast(uint id, address voter, bool vote);
    event Approval(uint id, address owner);
    event ExecutionExecuted(uint id);

    function ProposeTransfer(
        address target,
        address token,
        uint value
    ) external;

    function ProposeCall(
        address target,
        uint value,
        bytes calldata data
    ) external;

    function ProposeUpgrade(address proxy, address implementation) external;

    function Vote(uint proposalId, bool vote) external;

    function approveBySignature(
        address owner,
        uint256 proposalId,
        bytes calldata signature
    ) external;
}
