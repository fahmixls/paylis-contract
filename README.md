# Gasless ERC20 Payment Forwarder

A gasless meta-transaction payment forwarder for ERC20 tokens on EVM-compatible chains, built with Foundry.

This project implements a payment forwarder that allows users to send ERC20 tokens without needing ETH for gas fees. Transactions are relayed by a third party, who pays for the gas. The forwarder also supports split payments, where a fee is automatically deducted for the service provider.

## Features

- **Gasless Transactions (Meta-Transactions)**: Implements EIP-712 to allow users to sign messages off-chain, which are then relayed by a gas-paying forwarder.
- **Batch Transfers**: Process multiple meta-transactions in a single on-chain transaction to save gas.
- **Split Payments**: Execute payments where a fee is sent to the contract owner and the remaining amount is forwarded to the recipient.
- **Token Whitelisting**: The contract owner can control which ERC20 tokens are supported.
- **Fee Management**: The owner can withdraw accumulated fees from split payments.
- **Security**: Built on OpenZeppelin's secure contracts, including `Ownable`, `Pausable`, and `ReentrancyGuard`.
- **Batch Split Payments**: Process multiple split payments in a single transaction.
- **Emergency Functions**: The contract can be paused, and the owner can perform an emergency withdrawal of funds.

## Project Structure

```
.
├── src/
│   ├── PaymentForwarder.sol  # The main forwarder contract
│   └── mocks/                # Mock ERC20 tokens for testing
│       ├── MockUSDC.sol
│       └── MockIDRX.sol
├── script/
│   └── DeployScript.s.sol    # Deployment script for the forwarder
├── test/
│   └── ...                   # (Directory for tests)
├── deploy.sh                 # Convenience script for deployment
└── foundry.toml              # Foundry configuration
```

## Quick Start

### 1. Prerequisites

- [Foundry](https://getfoundry.sh/)

### 2. Setup Environment

Clone the repository and create a `.env` file from the example:

```bash
git clone <repository-url>
cd <repository-directory>
cp .env.example .env
```

Edit the `.env` file and add your details:

```
# Required for deployment and testing
PRIVATE_KEY=your_wallet_private_key
LISK_SEPOLIA_RPC_URL=https://rpc.sepolia-api.lisk.com
OWNER_ADDRESS=your_owner_address
```

### 3. Install Dependencies

Install the necessary libraries using Foundry:

```bash
forge install
```

### 4. Compile Contracts

```bash
forge build
```

### 5. Run Tests

Execute the test suite to ensure everything is working correctly:

```bash
forge test
```

### 6. Deploy

Deploy the `PaymentForwarder` contract to the Lisk Sepolia testnet (or your configured network) using the deployment script.

This command will broadcast the transaction, and if successful, it will write the deployed contract address to `deployed-addresses.txt`.

```bash
./deploy.sh
```

After deployment, the address of the `PaymentForwarder` will be printed to the console and saved in the `deployed-addresses.txt` file.

## How It Works

### Meta-Transactions

1.  **User**: Signs a message off-chain containing the transaction details (from, to, token, amount, nonce, deadline). This signature is generated according to the EIP-712 standard.
2.  **Relayer**: Receives the signed message and submits it to the `batchTransfer` function of the `PaymentForwarder` contract. The relayer pays the gas fee for this on-chain transaction.
3.  **Contract**: Verifies the signature. If valid, it executes the token transfer from the user's address to the recipient's address.

### Split Payments

1.  **User**: Signs a message for a split payment, including details like the total amount and the fee.
2.  **Relayer**: Submits the signed message to the `executeSplitPayment` function.
3.  **Contract**: Verifies the signature. It then transfers the `total` amount from the user to the contract. The `fee` amount is kept in the contract as an accumulated fee, and the remaining amount is sent to the recipient.

## Environment Variables

-   `PRIVATE_KEY`: The private key of the account that will be used to deploy the contracts and act as the initial owner.
-   `LISK_SEPOLIA_RPC_URL`: The RPC endpoint for the Lisk Sepolia testnet.
-   `OWNER_ADDRESS`: The address that will be the owner of the deployed contract. This address will have administrative privileges, such as whitelisting tokens and withdrawing fees.