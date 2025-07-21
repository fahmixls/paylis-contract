# Stablecoin Payment Gateway (EIP-2771)

A secure and gas-efficient smart contract for processing payments using multiple stablecoins, with support for:

- EIP-2771 meta-transactions (via trusted forwarder)
- Custom per-token fee configuration (fixed + percentage)
- Fee withdrawal for contract owner
- Reentrancy protection and overflow safety

Supports integration into decentralized applications (dApps) where users can pay with USDC, USDT, or other ERC-20 stablecoins.

---

## ✨ Features

- 🔐 Owner-controlled token management and fee settings
- 💰 Per-token fixed + percentage-based fees
- 🧾 Transparent event logging for all major operations
- 🔁 Meta-transaction support with `_msgSender()` override
- 🧱 Optimized with `unchecked` increments and gas-efficient logic
- 🛡️ Reentrancy-safe using `ReentrancyGuard`
- 📜 Fully compatible with OpenZeppelin contracts

---

## 🛠️ Foundry Workflow

**Foundry** is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.

It includes:

- **Forge** — Ethereum testing framework
- **Cast** — CLI tool for blockchain interaction
- **Anvil** — Local Ethereum node
- **Chisel** — Solidity REPL

📚 Documentation: [https://book.getfoundry.sh](https://book.getfoundry.sh)

---

## 🔧 Usage

### Build Contracts

```bash
forge build
```

### Run Tests

```bash
forge test
```

### Format Code

```bash
forge fmt
```

### Snapshot Gas Usage

```bash
forge snapshot
```

### Start Local Node

```bash
anvil
```

---

## 🚀 Deployment

Replace values with your actual RPC URL and private key:

```bash
forge script script/StablecoinPaymentGateway.s.sol:DeployScript \
  --rpc-url <your_rpc_url> \
  --private-key <your_private_key> \
  --broadcast
```

Ensure that `DeployScript` contains constructor args like the `trustedForwarder`.

---

## 🧪 Interact with Cast

Example: Get owner of the contract

```bash
cast call <contract_address> "owner()(address)" --rpc-url <your_rpc_url>
```

---

## 🗂️ Contract Structure Overview

### Constructor

```solidity
constructor(address trustedForwarder)
```

### Key Functions

#### `manageToken`

Add or update token configuration

#### `pay`

Process a payment, automatically calculates and deducts fee

#### `withdrawFees`

Withdraw accumulated platform fees (only owner)

#### `calculateFee`

Returns the total fee for a given amount

#### `getAllActiveTokens`

Returns all tokens that are currently active

---

## 📦 Dependencies

- OpenZeppelin Contracts (v4.x)
- Solidity ^0.8.29

---

## 📜 License

MIT
