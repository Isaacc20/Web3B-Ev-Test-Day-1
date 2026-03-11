# ARES Treasury Execution System – Security Analysis

## Overview

The ARES treasury system is designed with multiple layers of security.  
The goal is to make sure **no single actor can control or drain the treasury**.

To achieve this, the system separates two approval mechanisms:

1. **Governance Approval** – Token holders vote on proposals.
2. **Cryptographic Authorization** – Approved signers must also authorize execution using signatures.

Because both layers are required, even if a large token holder manipulates voting, or an owner key gets compromised, the treasury cannot be drained without passing **both checks**.

---

# Major Attack Surfaces & Mitigations

## 1. Governance Attacks (Flash Loans & Whale Control)

### Threat

An attacker might try to gain temporary voting power to influence governance.  
This could happen by:

- taking a **flash loan** to temporarily hold many tokens
- purchasing a large amount of tokens to dominate voting

This could allow them to push a malicious proposal through governance.

### Mitigations

#### Snapshot Voting

The system is designed to support **snapshot voting** using `ERC20Votes`.

Snapshots record voting power at a specific block.  
This prevents attackers from borrowing tokens temporarily to manipulate votes.

#### 1-Person-1-Vote Model

Voting is **not proportional to token balance**.  
Instead, users only need to meet a **minimum token threshold** to vote.

This reduces the risk of a **plutocracy**, where the richest holders control governance.

#### Proposal Threshold

To submit a proposal, users must hold **at least 1000 ART tokens**.

This ensures that only participants with meaningful stake in the protocol can propose actions.

---

## 2. Authorization Forgery (Signature Attacks)

### Threat

Attackers may attempt to manipulate the signature system by:

- replaying old signatures
- using signatures across different chains
- modifying signature values (signature malleability)

### Mitigations

#### EIP-712 Domain Separation

All signatures use **EIP-712 structured signing**.

This binds every signature to:

- the treasury contract address
- the current blockchain `chainId`

Because of this, a signature created on one chain **cannot be reused on another chain**.

#### Nonce Management

Each signer has a **nonce**.

Every time a signature is used:

1. the nonce increments
2. the previous signature becomes invalid

This prevents **signature replay attacks**.

#### ECDSA Malleability Protection

The implementation uses OpenZeppelin’s `ECDSA.recover`.

This ensures signatures follow strict validation rules and prevents attackers from submitting alternate versions of the same signature.

---

## 3. Execution Risks (Reentrancy & Logic Issues)

### Threat

A malicious contract could attempt to exploit the execution function.

For example, it might try a **reentrancy attack** to repeatedly execute the same proposal before the state updates.

### Mitigations

#### Check-Effects-Interactions Pattern

Before interacting with external contracts, the system:

1. updates the proposal state to `Executed`
2. performs the external call

If a contract tries to re-enter execution, the system will reject it because the proposal is already executed.

#### Strict Proposal State Machine

Each proposal must move through a defined lifecycle.
Proposed
↓
Voting
↓
Passed
↓
Approved
↓
Executed


Proposals cannot skip states or bypass governance checks.

---