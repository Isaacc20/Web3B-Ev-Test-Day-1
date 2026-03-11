// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../modules/MultiSig.sol";

contract Execution is MultiSig {
    constructor(
        address _token,
        address[] memory _owners,
        uint256 _threshold
    ) MultiSig(_token, _owners, _threshold) {}

    function executeTransaction(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];

        require(proposal.status != ProposalStatus.Executed, "Already executed");
        require(
            proposal.status == ProposalStatus.Approved,
            "Not approved by MultiSig"
        );

        proposal.status = ProposalStatus.Executed;

        if (proposal.data.length > 0) {
            (bool success, ) = proposal.target.call{value: proposal.value}(
                proposal.data
            );
            require(success, "Execution: call failed");
        } else if (proposal.token == address(0)) {
            (bool success, ) = payable(proposal.target).call{
                value: proposal.value
            }("");
            require(success, "Execution: ETH transfer failed");
        } else {
            bool success = IERC20(proposal.token).transfer(
                proposal.target,
                proposal.value
            );
            require(success, "Execution: ERC20 transfer failed");
        }

        emit ExecutionExecuted(proposalId);
    }

    receive() external payable {}
}
