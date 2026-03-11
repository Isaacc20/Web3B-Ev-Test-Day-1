# ARES: Treasury Execution System (TES)

ARES is a governance and treasury management protocol that allows a community to safely manage shared funds on-chain.

The protocol provides a structured process for:

- creating treasury proposals  
- voting on those proposals  
- approving them with cryptographic signatures  
- executing actions like transfers or contract calls  

Instead of relying only on governance voting or only a multisig wallet, ARES combines **both systems** to reduce the risk of treasury attacks.

---

# Protocol Lifecycle

Every proposal in ARES must go through **five stages** before it can execute.


Create Proposal
↓
Voting
↓
MultiSig Approval
↓
Execution
↓
Final State


If a proposal fails at any stage, it stops and cannot continue.

---

# 1. Proposal Creation

To prevent spam proposals, only users with a minimum token balance can create proposals.

### Requirements

The proposer must hold **at least 1,000 ART tokens**.

### Types of Proposals

The system supports three main types of treasury actions.

**ProposeTransfer**

Used for simple transfers such as:

- sending ETH
- sending ERC20 tokens

Example:


transfer(token, recipient, amount)


---

**ProposeCall**

Allows the treasury to interact with other smart contracts.

This is useful when the treasury needs to:

- interact with DeFi protocols
- call functions on other contracts
- perform complex operations

Example:


call(targetContract, calldata)


---

**ProposeUpgrade**

Used when upgrading contracts that follow a **proxy upgrade pattern**.

Example use case:

- upgrading protocol logic
- updating treasury management contracts

---

### Result

Once created, the proposal enters the **Pending** state.

---

# 2. Voting (Economic Consensus)

After a proposal is created, the community can vote on it.

### Requirements

Voters must hold **at least 100 ART tokens**.

### Voting Model

ARES uses a **1-person-1-vote system**.

This means:

- each eligible voter has equal voting power
- large token holders cannot dominate governance

### Voting Duration

The voting period lasts **24 hours**.

### Finalizing the Vote

After the voting period ends, someone must call:


finalizeVoting(proposalId)


The proposal outcome is determined as follows:


If For > Against → Passed
Otherwise → Failed


Only proposals that **pass voting** move to the next stage.

---

# 3. Approval (Cryptographic Authorization)

Even if a proposal passes the community vote, it still requires approval from trusted signers.

This is handled by the **MultiSig module**.

### MultiSig Owners

A group of trusted owners is defined when the system is deployed.

### Approval Threshold

ARES currently uses:


2 out of 3 owner approvals


This threshold can be configured.

### Signature Methods

Owners can approve proposals in two ways:

**Direct transaction**

Owners submit an approval transaction directly on-chain.

**Off-chain signature**

Owners can sign approvals off-chain using **EIP-712 structured signatures**.

These signatures can later be submitted on-chain using:


approveBySignature(...)


This approach reduces gas costs.

### Result

Once the required number of approvals is reached:


Proposal status → Approved


---

# 4. Execution (Treasury Action)

After approval, the proposal can finally be executed.

Execution happens inside the **Execution contract**, which also holds the treasury funds.

### Execution Process

The system performs the following checks:

1. Verify proposal status is **Approved**
2. Update status to **Executed**
3. Perform the external call or transfer

Updating the status before the call helps prevent **reentrancy attacks**.

### Possible Execution Results

Execution may perform actions such as:

- transferring ETH
- transferring ERC20 tokens
- calling functions on other contracts
- upgrading contracts

Once execution completes, the proposal lifecycle ends.

---

# 5. Cancellation & Rejection

Some proposals may never reach execution.

### Failed Proposals

If a proposal fails the voting stage:


Status → Failed


Failed proposals cannot continue.

### Administrative Rejection

Even if a proposal passes voting, it may still fail if:

- multisig owners refuse to approve it

This acts as a safety mechanism against malicious governance decisions.

Future versions of the protocol may also include an explicit **Reject function**.

---

# Technical Stack

The protocol is built using common Ethereum development tools.

**Framework**

Foundry

**Libraries**

OpenZeppelin

Used for:

- ERC20 token implementation
- EIP-712 signature handling
- ECDSA signature recovery
- Nonce management

**Contract Architecture**


Governance
↓
MultiSig
↓
Execution


Each contract layer adds new functionality to the system.

---

# Deployment

The protocol can be deployed using the provided Forge deployment script.

Example command:


forge script script/ARESScript.s.sol:ExecutionScript
--rpc-url <YOUR_RPC>
--broadcast


Make sure the RPC URL is configured for the target network.

---

# Security

ARES includes several security mechanisms, including:

- multi-layer authorization
- replay protection for signatures
- reentrancy protection during execution
- governance thresholds for proposals and voting

For a detailed explanation of the protocol's security model, see: [SECUTIRY.md](SECURITY.md)