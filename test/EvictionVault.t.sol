// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {EvictionVault} from "../src/EvictionVault.sol";

contract EvictionVaultTest is Test {
    EvictionVault public vault;

    address[] public owners;

    address public owner1;
    address public owner2;
    address public owner3;

    address public user1;
    address public user2;

    uint256 public threshold = 2;

    function setUp() public {
        owner1 = makeAddr("owner1");
        owner2 = makeAddr("owner2");
        owner3 = makeAddr("owner3");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        owners.push(owner1);
        owners.push(owner2);
        owners.push(owner3);

        vault = new EvictionVault{value: 1 ether}(owners, threshold);
    }

    function test_InitialState() public {
        assertEq(vault.totalVaultValue(), 1 ether);
        assertEq(vault.threshold(), 2);
        assertTrue(vault.isOwner(owner1));
        assertFalse(vault.isOwner(user1));
    }

    function test_Deposit() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vault.deposit{value: 0.5 ether}();

        assertEq(vault.balances(user1), 0.5 ether);
        assertEq(vault.totalVaultValue(), 1.5 ether);
    }

    function test_Withdraw() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vault.deposit{value: 1 ether}();

        vm.prank(user1);
        vault.withdraw(0.5 ether);

        assertEq(vault.balances(user1), 0.5 ether);
        assertEq(vault.totalVaultValue(), 1.5 ether);
    }

    // --- Multi-Sig Tests ---

    function test_MultiSigWorkflow() public {
        address recipient = address(0x999);
        bytes memory data = "";

        // 1. Submit
        vm.prank(owner1);
        vault.submitTransaction(recipient, 0.1 ether, data);

        // 2. Confirm (Owner 2)
        vm.prank(owner2);
        vault.confirmTransaction(0);

        // Check timelock
        (, , , , , , uint256 executionTime) = vault.transactions(0);
        assertTrue(executionTime > 0);

        // 3. Execute (Fail because of timelock)
        vm.prank(owner1);
        vm.expectRevert("Transaction not ready to execute");
        vault.executeTransaction(0);

        // 4. Warp time and Execute
        vm.warp(block.timestamp + 1 hours + 1);
        uint256 initialBalance = recipient.balance;

        vm.prank(owner1);
        vault.executeTransaction(0);

        assertEq(recipient.balance, initialBalance + 0.1 ether);
    }

    // --- Merkle Claim Tests ---

    function test_MerkleClaim() public {
        uint256 claimAmount = 0.5 ether;
        // Generate leaf for user1
        bytes32 leaf = keccak256(abi.encodePacked(user1, claimAmount));

        // For a tree with 1 leaf, the root is the leaf and proof is empty
        vm.prank(owner1);
        vault.setMerkleRoot(leaf);

        bytes32[] memory proof = new bytes32[](0);

        uint256 initialBal = user1.balance;
        vm.prank(user1);
        vault.claim(proof, claimAmount);

        assertEq(user1.balance, initialBal + claimAmount);
        assertTrue(vault.claimed(user1));
    }

    // --- Security & Emergency ---

    function test_EmergencyWithdraw() public {
        // Vault has 1 ether initial
        // User1 deposits 1 ether
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vault.deposit{value: 1 ether}();

        assertEq(address(vault).balance, 2 ether);

        uint256 ownerInitialBal = owner1.balance;

        // Owner calls emergency withdraw - should drain EVERYTHING
        vm.prank(owner1);
        vault.emergencyWithdrawAll();

        assertEq(address(vault).balance, 0);
        assertEq(owner1.balance, ownerInitialBal + 2 ether);

        // Note: paused() check removed as it was commented out in the contract
    }

    function test_PauseProtection() public {
        vm.prank(owner1);
        vault.pause();

        vm.prank(user1);
        vm.expectRevert("paused");
        vault.withdraw(100);
    }
}
