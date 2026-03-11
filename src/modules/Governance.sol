// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IGovernance.sol";

abstract contract Governance is IGovernance {
    address public token;

    uint public constant MINIMUM_PROPOSER_BALANCE = 1000 * 1e18;
    uint public constant MINIMUM_VOTER_BALANCE = 100 * 1e18;
    uint public constant VOTING_PERIOD = 24 hours;

    mapping(uint => Proposal) public proposals;
    mapping(uint => mapping(address => bool)) public hasVoted;
    uint public proposalCount;

    modifier validateProposer() {
        require(
            IERC20(token).balanceOf(msg.sender) >= MINIMUM_PROPOSER_BALANCE,
            "Not eligible to propose"
        );
        _;
    }

    constructor(address _token) {
        token = _token;
    }

    function ProposeTransfer(
        address target,
        address _token,
        uint value
    ) external override validateProposer {
        require(target != address(0), "Invalid target");

        proposalCount++;
        proposals[proposalCount] = Proposal({
            id: proposalCount,
            proposer: msg.sender,
            target: target,
            token: _token,
            value: value,
            data: "",
            startTime: block.timestamp,
            endTime: block.timestamp + VOTING_PERIOD,
            forVotes: 0,
            againstVotes: 0,
            approvals: 0,
            status: ProposalStatus.Pending
        });

        emit ProposalCreated(
            proposalCount,
            msg.sender,
            target,
            _token,
            value,
            block.timestamp,
            block.timestamp + VOTING_PERIOD
        );
    }

    function ProposeCall(
        address target,
        uint value,
        bytes calldata data
    ) external override validateProposer {
        require(target != address(0), "Invalid target");

        proposalCount++;
        proposals[proposalCount] = Proposal({
            id: proposalCount,
            proposer: msg.sender,
            target: target,
            token: address(0),
            value: value,
            data: data,
            startTime: block.timestamp,
            endTime: block.timestamp + VOTING_PERIOD,
            forVotes: 0,
            againstVotes: 0,
            approvals: 0,
            status: ProposalStatus.Pending
        });

        emit ProposalCreated(
            proposalCount,
            msg.sender,
            target,
            address(0),
            value,
            block.timestamp,
            block.timestamp + VOTING_PERIOD
        );
    }

    function ProposeUpgrade(
        address proxy,
        address implementation
    ) external override validateProposer {
        require(proxy != address(0), "Invalid proxy");
        require(implementation != address(0), "Invalid implementation");

        bytes memory data = abi.encodeWithSignature(
            "upgradeTo(address)",
            implementation
        );

        proposalCount++;
        proposals[proposalCount] = Proposal({
            id: proposalCount,
            proposer: msg.sender,
            target: proxy,
            token: address(0),
            value: 0,
            data: data,
            startTime: block.timestamp,
            endTime: block.timestamp + VOTING_PERIOD,
            forVotes: 0,
            againstVotes: 0,
            approvals: 0,
            status: ProposalStatus.Pending
        });

        emit ProposalCreated(
            proposalCount,
            msg.sender,
            proxy,
            address(0),
            0,
            block.timestamp,
            block.timestamp + VOTING_PERIOD
        );
    }

    function Vote(uint proposalId, bool vote) external override {
        Proposal storage proposal = proposals[proposalId];
        require(
            IERC20(token).balanceOf(msg.sender) >= MINIMUM_VOTER_BALANCE,
            "Not eligible to vote"
        );
        require(proposal.status == ProposalStatus.Pending, "Not voting period");
        require(proposal.endTime > block.timestamp, "Voting ended");
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        if (vote) {
            proposal.forVotes += 1;
        } else {
            proposal.againstVotes += 1;
        }

        hasVoted[proposalId][msg.sender] = true;
        emit VoteCast(proposalId, msg.sender, vote);
    }

    function finalizeVoting(uint proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.endTime, "Voting still active");
        require(proposal.status == ProposalStatus.Pending, "Already finalized");

        if (proposal.forVotes > proposal.againstVotes) {
            proposal.status = ProposalStatus.Passed;
        } else {
            proposal.status = ProposalStatus.Failed;
        }
    }
}
