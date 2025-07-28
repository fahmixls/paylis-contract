# EIP-2771 Payment Gateway

A meta-transaction enabled payment gateway with forwarder for Lisk Sepolia.

## Quick Start

1. **Setup Environment**

   ```bash
   cp .env.example .env
   # Edit .env with your actual values
   ```

2. **Install Dependencies**

   ```bash
   forge install
   ```

3. **Deploy Mock Tokens (Optional)**

   ```bash
   ./deploy-mocks.sh
   ```

   Copy the displayed addresses to your `.env` file.

4. **Deploy Main Contracts**
   ```bash
   ./deploy.sh
   ```

## Contracts

- **MinimalForwarder**: EIP-2771 compatible forwarder for meta-transactions
- **PaymentGateway**: Main payment gateway that accepts ERC-20 tokens with configurable fees
- **MockERC20**: Simple mock tokens for testing (USDC, IDRX)

## Environment Variables

```bash
# Required
PRIVATE_KEY=your_private_key_here
LISK_SEPOLIA_RPC_URL=https://rpc.sepolia-api.lisk.com
OWNER_ADDRESS=0x...
FEE_COLLECTOR_ADDRESS=0x...

# Mock token addresses
MOCK_USDC_ADDRESS=0x...
MOCK_IDRX_ADDRESS=0x...
```

## Deployment Commands

```bash
# Deploy mock tokens first
forge script script/DeployMocks.s.sol --rpc-url $LISK_SEPOLIA_RPC_URL --broadcast --verify

# Deploy main contracts
forge script script/Deploy.s.sol --rpc-url $LISK_SEPOLIA_RPC_URL --broadcast --verify

# Or use the convenience script
./deploy.sh
```

## Features

- **EIP-2771 Meta-Transactions**: Users can have their transactions sponsored
- **Configurable Fees**: Fee taken as basis points (0-10000 bps)
- **Multi-Token Support**: Owner can activate/deactivate ERC-20 tokens
- **Fee Collection**: Accumulated fees can be swept by owner
- **Gas Optimized**: Minimal storage and efficient operations
