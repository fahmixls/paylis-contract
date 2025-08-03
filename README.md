# Gasless ERC20 Payment Forwarder

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Powered by Foundry](https://img.shields.io/badge/Powered%20by-Foundry-orange.svg)](https://getfoundry.sh/)

A gasless meta-transaction payment forwarder for ERC20 tokens on EVM-compatible chains, built with Foundry.

This project implements a payment forwarder that allows users to send ERC20 tokens without needing ETH for gas fees. Transactions are relayed by a third party, who pays for the gas. The forwarder also supports split payments, where a fee is automatically deducted for the service provider.

## Table of Contents

- [Gasless ERC20 Payment Forwarder](#gasless-erc20-payment-forwarder)
  - [Table of Contents](#table-of-contents)
  - [Workflow](#workflow)
  - [Features](#features)
  - [Supported Networks](#supported-networks)
  - [Project Structure](#project-structure)
  - [Core Functions](#core-functions)
    - [For Users (via Relayer)](#for-users-via-relayer)
    - [For Owner](#for-owner)
    - [View Functions](#view-functions)
  - [How It Works](#how-it-works)
    - [Meta-Transactions](#meta-transactions)
    - [Split Payments](#split-payments)
  - [Integration Guide](#integration-guide)
  - [Quick Start](#quick-start)
    - [1. Prerequisites](#1-prerequisites)
    - [2. Setup Environment](#2-setup-environment)
    - [3. Install Dependencies](#3-install-dependencies)
    - [4. Compile Contracts](#4-compile-contracts)
    - [5. Run Tests](#5-run-tests)
    - [6. Deploy](#6-deploy)
  - [Environment Variables](#environment-variables)
  - [Security](#security)
  - [Contributing](#contributing)
  - [License](#license)

## Workflow

Here is a diagram illustrating the meta-transaction flow:

```
   +----------------+                            +-----------------+                            +------------------------+
   |      User      |                            |     Relayer     |                            | PaymentForwarder.sol   |
   +----------------+                            +-----------------+                            +------------------------+
           |                                              |                                              |
           | 1. Create Meta-Transaction                  |                                              |
           |    (from, to, token, amount, nonce, deadline)|                                              |
           |                                              |                                              |
           | 2. Sign transaction with private key (EIP-712)|                                              |
           |--------------------------------------------->| 3. Receive signed transaction                |
           |                                              |                                              |
           |                                              | 4. Submit transaction to the blockchain      |
           |                                              |    (pays for gas)                            |
           |                                              |--------------------------------------------->| 5. Verify Signature
           |                                              |                                              |    - Recovers signer address
           |                                              |                                              |    - Checks nonce
           |                                              |                                              |    - Checks deadline
           |                                              |                                              |
           |                                              |                                              | 6. If valid, execute transfer:
           |                                              |                                              |    token.transferFrom(from, to, amount)
           |                                              |                                              |
           |                                              |                                              | 7. Emit event
           |                                              |                                              |
```

## Features

- **Gasless Transactions (Meta-Transactions)**: Implements EIP-712 to allow users to sign messages off-chain, which are then relayed by a gas-paying forwarder.
- **Batch Transfers**: Process multiple meta-transactions in a single on-chain transaction to save gas.
- **Split Payments**: Execute payments where a fee is sent to the contract owner and the remaining amount is forwarded to the recipient.
- **Batch Split Payments**: Process multiple split payments in a single transaction.
- **Token Whitelisting**: The contract owner can control which ERC20 tokens are supported.
- **Fee Management**: The owner can withdraw accumulated fees from split payments.
- **Security**: Built on OpenZeppelin's secure contracts, including `Ownable`, `Pausable`, and `ReentrancyGuard`.
- **Emergency Functions**: The contract can be paused, and the owner can perform an emergency withdrawal of funds.

## Supported Networks

This contract is designed to be deployed on any EVM-compatible chain. It has been tested on the following networks:

- Lisk Sepolia

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

## Core Functions

### For Users (via Relayer)

- `batchTransfer(MetaTxWithSig[] calldata _metaTxWithSig, uint256 gas)`: Executes a batch of standard meta-transactions.
- `executeSplitPayment(SplitPaymentWithSig calldata _payment)`: Executes a single split payment.
- `batchSplitPayment(SplitPaymentWithSig[] calldata _payments, uint256 gas)`: Executes a batch of split payments.

### For Owner

- `whitelistToken(IERC20 _token)`: Whitelists a new ERC20 token for use in the forwarder.
- `removeTokenFromWhitelist(IERC20 _token)`: Removes a token from the whitelist.
- `withdrawFees(IERC20 _token)`: Withdraws accumulated fees for a specific token.
- `withdrawAllFees(IERC20[] calldata _tokens)`: Withdraws all accumulated fees for multiple tokens.
- `pause()`: Pauses the contract, disabling transfers and payments.
- `unpause()`: Unpauses the contract.
- `emergencyWithdraw(IERC20 _token, uint256 _amount)`: Allows the owner to withdraw any amount of a token from the contract in an emergency.

### View Functions

- `getNonce(address _account)`: Returns the current nonce for an address.
- `getAccumulatedFees(IERC20 _token)`: Returns the amount of fees collected for a specific token.
- `isTokenWhitelisted(IERC20 _token)`: Checks if a token is whitelisted.

## How It Works

### Meta-Transactions

The core of the gasless functionality is EIP-712, which allows for typed message signing.

1.  **User**: The user constructs a `MetaTx` struct with the transaction details:
    - `from`: The user's address.
    - `to`: The recipient's address.
    - `token`: The ERC20 token contract address.
    - `amount`: The amount of tokens to send.
    - `nonce`: A sequential number to prevent replay attacks. The user's first nonce is 0.
    - `deadline`: A Unix timestamp after which the transaction is no longer valid.
2.  **Signature**: The user signs this struct using their private key.
3.  **Relayer**: A third-party service (the relayer) takes this signed message and calls the `batchTransfer` function on the `PaymentForwarder` contract, paying the gas fee.
4.  **Contract**: The contract uses `ECDSA.recover` to derive the signer's address from the message and signature. It checks that the signer matches the `from` address and that the nonce is correct. If everything is valid, it executes the `transferFrom` on the specified token contract.

### Split Payments

Split payments work similarly, but with a different struct (`SplitPayment`) that includes a `fee` field.

- `total`: The total amount to be transferred from the user.
- `fee`: The portion of the `total` that will be kept by the contract as a service fee.

When `executeSplitPayment` is called, the contract transfers the `total` amount from the user to itself. It then sends `total - fee` to the final recipient and stores the `fee` in its internal balance, which can be withdrawn by the owner.

## Integration Guide

To interact with the `PaymentForwarder`, you need to create an EIP-712 signature. Here is an example using `ethers.js`:

```javascript
import { ethers } from "ethers";

async function signMetaTransaction(signer, forwarderContract, to, tokenAddress, amount) {
    const from = await signer.getAddress();
    const nonce = await forwarderContract.getNonce(from);
    const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now

    const domain = {
        name: "PaymentMetaTx",
        version: "1",
        chainId: (await signer.provider.getNetwork()).chainId,
        verifyingContract: forwarderContract.address,
    };

    const types = {
        MetaTx: [
            { name: "from", type: "address" },
            { name: "to", type: "address" },
            { name: "token", type: "address" },
            { name: "amount", type: "uint256" },
            { name: "nonce", type: "uint256" },
            { name: "deadline", type: "uint256" },
        ],
    };

    const value = {
        from,
        to,
        token: tokenAddress,
        amount,
        nonce,
        deadline,
    };

    const signature = await signer._signTypedData(domain, types, value);

    return {
        metaTx: value,
        signature,
    };
}

// Usage:
// const provider = new ethers.providers.Web3Provider(window.ethereum);
// const signer = provider.getSigner();
// const forwarderContract = new ethers.Contract(forwarderAddress, forwarderAbi, signer);
// const signedTx = await signMetaTransaction(signer, forwarderContract, recipientAddress, tokenAddress, amount);
//
// // Now, a relayer can call:
// // forwarderContract.connect(relayer).batchTransfer([signedTx], gasOptions);
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

Execute the test suite to ensure everything is working correctly. The tests cover all core functionalities, including meta-transactions, split payments, batching, and owner-only functions.

```bash
forge test
```

### 6. Deploy

Deploy the `PaymentForwarder` contract to the Lisk Sepolia testnet (or your configured network) using the deployment script.

This command will broadcast the transaction, and if successful, it will write the deployed contract address to `deployed-addresses.txt`.

**Note**: The `deploy.sh` script is a convenience wrapper around the `forge script` command.

```bash
./deploy.sh
```

After deployment, the address of the `PaymentForwarder` will be printed to the console and saved in the `deployed-addresses.txt` file.

**Note:** After deployment, you may want to verify the contract on a block explorer. You can use Foundry's `forge verify-contract` command for this.

## Environment Variables

-   `PRIVATE_KEY`: The private key of the account that will be used to deploy the contracts and act as the initial owner.
-   `LISK_SEPOLIA_RPC_URL`: The RPC endpoint for the Lisk Sepolia testnet.
-   `OWNER_ADDRESS`: The address that will be the owner of the deployed contract. This address will have administrative privileges, such as whitelisting tokens and withdrawing fees.

## Security

This contract is built with security in mind:

- **Owner-only Functions**: Critical functions like `whitelistToken` and `withdrawFees` are restricted to the contract owner using OpenZeppelin's `Ownable`.
- **Re-entrancy Protection**: The main transaction functions use the `nonReentrant` modifier from OpenZeppelin's `ReentrancyGuard` to prevent re-entrancy attacks.
- **Pausable**: The contract can be paused by the owner in case of an emergency, using OpenZeppelin's `Pausable`.
- **Nonce System**: A nonce is used for each transaction to prevent replay attacks.
- **Deadline**: Each transaction has a deadline to prevent the execution of old, signed messages.
- **EIP-712**: Follows the EIP-712 standard for typed data signing, which provides clarity to users about what they are signing.

## Contributing

Contributions are welcome! Please feel free to open an issue or submit a pull request.

1.  Fork the repository.
2.  Create a new branch (`git checkout -b feature/your-feature`).
3.  Make your changes.
4.  Commit your changes (`git commit -m 'Add some feature'`).
5.  Push to the branch (`git push origin feature/your-feature`).
6.  Open a pull request.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.