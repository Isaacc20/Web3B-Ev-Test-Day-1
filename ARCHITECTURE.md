# ARES Treasury Execution System (TES) – System Architecture

## Overview

The **ARES Treasury Execution System (TES)** is a modular governance system used to manage and execute treasury actions securely.

Instead of relying on only one approval mechanism (like simple DAO voting or a basic multisig), ARES combines **multiple approval layers**:

1. Community governance (token holder voting)
2. Cryptographic authorization (multisig signatures)
3. Controlled execution of treasury actions

This layered approach helps reduce the risk of a single failure point.  
Even if one layer is compromised, the treasury funds are still protected by the other layers.

---

# System Structure

The system is built using a **linear inheritance structure**, where each module adds new functionality.

Each layer handles a specific responsibility:


IGovernance
↓
Governance
↓
MultiSig
↓
Execution


This separation makes the system easier to maintain and reduces the attack surface of each component.

---

# Modules

## 1. Interface Layer (`IGovernance`)

This layer defines the **core data structure used by the entire system**.

The main structure is the `Proposal` struct.

A proposal represents a treasury action that moves through the governance pipeline.

Example information stored in a proposal:

- target contract address
- ETH value (if sending ETH)
- calldata for contract interactions
- token address (for ERC20 transfers)
- proposal status

Because all modules use the same struct, proposals can move through the system consistently.

---

## 2. Governance Layer (`Governance`)

This module manages the **community decision-making process**.

### Proposing

Users must hold a minimum number of governance tokens before creating a proposal.

This prevents spam proposals and ensures proposers have some stake in the protocol.

### Voting

The system uses a **1-person-1-vote model**.

Even though users must hold a minimum token balance to vote, every voter has equal weight.

This reduces the influence of large token holders ("governance whales").

### State Tracking

This module stores proposals in a `mapping` and manages their lifecycle.

Example proposal states:


Pending → Active → Passed → Failed


Only proposals that pass the voting phase can continue to the next step.

---

## 3. Authentication Layer (`MultiSig`)

This module acts as an additional **security layer after governance approval**.

Even if a proposal passes the community vote, it still needs approval from trusted signers.

### Owner Management

The system defines a group of **owners** who act as trusted signers.

A minimum number of owner approvals (threshold) is required.

Example:


3 out of 5 owners must approve a proposal


### EIP-712 Signatures

Owners can approve proposals **off-chain using cryptographic signatures**.

This is implemented using **EIP-712 structured data signing**.

Benefits:

- cheaper gas usage
- strong cryptographic verification
- easier signature validation

### Replay Protection

The system prevents signature reuse using:

- **Domain Separator** (ties signatures to a specific contract and chain)
- **Owner nonces** (each signature can only be used once)

This protects against signature replay attacks.

---

## 4. Execution Layer (`Execution`)

This is the final module in the system.

It is responsible for **actually executing approved treasury actions**.

It also **holds the treasury funds**.

### Supported Operations

The execution module can perform:

- ETH transfers
- ERC20 token transfers
- arbitrary contract calls
- contract upgrades (if applicable)

### Safety Checks

Before executing any action, the system verifies:


Proposal.status == Approved


If the proposal is not approved, execution is rejected.

This ensures only properly authorized proposals can move funds.

---

# Security Boundaries

ARES enforces security through **three main boundaries**.

---

## 1. Economic Boundary

Access to governance actions is controlled by the **Governance Token**.

Users must hold a minimum token balance to:

- create proposals
- vote on proposals

This ensures participants have economic stake in the system.

---

## 2. Temporal Boundary

The system enforces a **fixed voting period**.


VOTING_PERIOD


This guarantees that:

- proposals cannot be rushed
- the community has time to review proposals
- voters can react to malicious proposals

---

## 3. Administrative Boundary

Even after governance approval, proposals still require **multisig authorization**.

This prevents a situation where:

- a malicious governance vote
- flash-loan voting manipulation

could immediately drain the treasury.

Both governance and multisig approval are required.

---

# Trust Assumptions

Although the system is designed to reduce trust, some assumptions still exist.

---

## Owner Integrity

The system assumes that a majority of multisig owners will act honestly.

Example assumption:


At least 2/3 of multisig owners will not collude maliciously.


---

## Token Distribution

The governance model assumes that token supply is not heavily concentrated.

If a malicious actor controls too many tokens, they could create many wallets and influence voting.

---

## External Contract Safety

For arbitrary contract calls, the system assumes that:

- target contracts are not malicious
- proposal calldata is reviewed by the community during voting

Community members should review proposals carefully before voting.

---

# Summary

The ARES Treasury Execution System combines multiple security layers to protect treasury funds:

- governance voting
- multisig authorization
- controlled execution logic
- structured proposal lifecycle

This approach reduces the risk of both economic attacks and smart contract exploits.