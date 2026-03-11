// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/core/Execution.sol";
import "../src/modules/GovernanceToken.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MaliciousContract {
    Execution public treasury;
    uint256 public proposalId;

    constructor(Execution _treasury) {
        treasury = _treasury;
    }

    function setProposal(uint256 _id) external {
        proposalId = _id;
    }

    // Triggered by Execution contract call
    fallback() external payable {
        if (proposalId != 0) {
            treasury.executeTransaction(proposalId);
        }
    }
}

contract ExecutionTest is Test {
    using ECDSA for bytes32;

    Execution public treasury;
    GovernanceToken public token;

    address public proposer = address(0x111);
    address public voter = address(0x222);
    address[] public owners;
    uint256[] public ownerKeys;

    uint256 public constant PROPOSER_MIN = 1000 * 1e18;
    uint256 public constant VOTER_MIN = 100 * 1e18;

    function setUp() public {
        token = new GovernanceToken();

        // Setup 3 owners
        for (uint256 i = 1; i <= 3; i++) {
            uint256 key = i;
            ownerKeys.push(key);
            owners.push(vm.addr(key));
        }

        treasury = new Execution(address(token), owners, 2);

        // Distribute tokens
        token.transfer(proposer, PROPOSER_MIN);
        token.transfer(voter, VOTER_MIN);

        vm.label(proposer, "Proposer");
        vm.label(voter, "Voter");
        vm.deal(address(treasury), 10 ether);
    }

    // --- POSITIVE CASE (Happy Path) ---
    function test_HappyPath_ExecuteTransfer() public {
        vm.startPrank(proposer);
        treasury.ProposeTransfer(address(0xABC), address(0), 1 ether);
        vm.stopPrank();

        vm.startPrank(voter);
        treasury.Vote(1, true);
        vm.stopPrank();

        vm.warp(block.timestamp + 25 hours);
        treasury.finalizeVoting(1);

        // Approve by signature from owner 1 and 2
        bytes memory sig1 = _signApproval(1, 1);
        bytes memory sig2 = _signApproval(2, 1);

        treasury.approveBySignature(owners[0], 1, sig1);
        treasury.approveBySignature(owners[1], 1, sig2);

        uint256 balanceBefore = address(0xABC).balance;
        treasury.executeTransaction(1);
        assertEq(address(0xABC).balance, balanceBefore + 1 ether);
    }

    // --- 1. Malicious Contract Reentrancy ---
    function test_RevertIf_Reentrancy() public {
        MaliciousContract mal = new MaliciousContract(treasury);

        vm.startPrank(proposer);
        treasury.ProposeTransfer(address(mal), address(0), 1 ether);
        vm.stopPrank();

        mal.setProposal(1); // Set target to re-enter itself

        _passVotingAndGetApprovals(1);

        vm.expectRevert("Execution: ETH transfer failed");
        treasury.executeTransaction(1);

        // Final verification: Ensure balance moved only once
        assertEq(address(mal).balance, 1 ether);
    }

    // --- 2. Double Claim (Double Execution) ---
    function test_RevertIf_DoubleExecution() public {
        _createAndApproveProposal(1);

        treasury.executeTransaction(1);

        vm.expectRevert("Already executed");
        treasury.executeTransaction(1);
    }

    // --- 3. Invalid Signature (Non-owner) ---
    function test_RevertIf_InvalidSignature() public {
        _createAndPassVoting(1);

        uint256 nonOwnerKey = 999;
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Approval(uint256 proposalId,uint256 nonce)"),
                1,
                treasury.nonces(vm.addr(nonOwnerKey))
            )
        );
        bytes32 hash = _hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(nonOwnerKey, hash);
        bytes memory sig = abi.encodePacked(r, s, v);

        vm.expectRevert("Signer not an owner");
        treasury.approveBySignature(vm.addr(nonOwnerKey), 1, sig);
    }

    // --- 4. Premature execution: Before Voting ---
    function test_RevertIf_ApproveBeforeVotingPassed() public {
        vm.startPrank(proposer);
        treasury.ProposeTransfer(address(0x1), address(0), 1 ether);
        vm.stopPrank();

        vm.expectRevert("Voting hasn't passed");
        vm.prank(owners[0]);
        treasury.approveProposal(1);
    }

    // --- 5. Premature execution: Before MultiSig ---
    function test_RevertIf_ExecuteBeforeMultiSig() public {
        _createAndPassVoting(1);

        vm.expectRevert("Not approved by MultiSig");
        treasury.executeTransaction(1);
    }

    // --- 6. Proposal Replay (Nonce reuse attempt) ---
    function test_RevertIf_SignatureNonceReplay() public {
        _createAndPassVoting(1);
        bytes memory sig = _signApproval(1, 1);

        treasury.approveBySignature(owners[0], 1, sig);

        vm.expectRevert(); // Nonce changed, signature invalid for next try or duplicate
        treasury.approveBySignature(owners[0], 1, sig);
    }

    // --- 7. Proposer Insolvency (< 1000 tokens) ---
    function test_RevertIf_ProposerLowBalance() public {
        address poorUser = address(0x99);
        token.transfer(poorUser, 999 * 1e18); // Just under 1000

        vm.startPrank(poorUser);
        vm.expectRevert("Not eligible to propose");
        treasury.ProposeTransfer(address(0x1), address(0), 1 ether);
    }

    // --- 8. Voter Insolvency (< 100 tokens) ---
    function test_RevertIf_VoterLowBalance() public {
        _createAndPassVoting(1); // Voter 1 already has tokens from setup

        address poorVoter = address(0x88);
        token.transfer(poorVoter, 99 * 1e18);

        vm.startPrank(poorVoter);
        vm.expectRevert("Not eligible to vote");
        treasury.Vote(1, true);
    }

    // --- 9. Invalid Target ---
    function test_RevertIf_ProposeToZeroAddress() public {
        vm.startPrank(proposer);
        vm.expectRevert("Invalid target");
        treasury.ProposeTransfer(address(0), address(0), 1 ether);
    }

    // --- HELPERS ---

    function _signApproval(
        uint256 ownerIndex,
        uint256 proposalId
    ) internal view returns (bytes memory) {
        address owner = owners[ownerIndex - 1];
        uint256 key = ownerKeys[ownerIndex - 1];

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Approval(uint256 proposalId,uint256 nonce)"),
                proposalId,
                treasury.nonces(owner)
            )
        );
        bytes32 hash = _hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, hash);
        return abi.encodePacked(r, s, v);
    }

    function _hashTypedDataV4(
        bytes32 structHash
    ) internal view returns (bytes32) {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes("TreasuryExecutor")),
                keccak256(bytes("1")),
                block.chainid,
                address(treasury)
            )
        );
        return
            keccak256(
                abi.encodePacked("\x19\x01", domainSeparator, structHash)
            );
    }

    function _createAndPassVoting(uint256 id) internal {
        vm.startPrank(proposer);
        treasury.ProposeTransfer(address(0x123), address(0), 1 ether);
        vm.stopPrank();

        vm.startPrank(voter);
        treasury.Vote(id, true);
        vm.stopPrank();

        vm.warp(block.timestamp + 25 hours);
        treasury.finalizeVoting(id);
    }

    function _passVotingAndGetApprovals(uint256 id) internal {
        vm.prank(voter);
        treasury.Vote(id, true);

        vm.warp(block.timestamp + 25 hours);
        treasury.finalizeVoting(id);

        treasury.approveBySignature(owners[0], id, _signApproval(1, id));
        treasury.approveBySignature(owners[1], id, _signApproval(2, id));
    }

    function _createAndApproveProposal(uint256 id) internal {
        _createAndPassVoting(id);
        treasury.approveBySignature(owners[0], id, _signApproval(1, id));
        treasury.approveBySignature(owners[1], id, _signApproval(2, id));
    }
}
