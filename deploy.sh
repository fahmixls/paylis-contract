#!/bin/bash

# Deploy to Lisk Sepolia
echo "🚀 Deploying to Lisk Sepolia..."

# Check if .env exists
if [ ! -f .env ]; then
    echo "❌ .env file not found. Please copy .env.example to .env and configure it."
    exit 1
fi

# Load environment variables
source .env

# Validate required variables
if [ -z "$PRIVATE_KEY" ] || [ -z "$LISK_SEPOLIA_RPC_URL" ] || [ -z "$OWNER_ADDRESS" ] || [ -z "$FEE_COLLECTOR_ADDRESS" ]; then
    echo "❌ Missing required environment variables. Please check your .env file."
    exit 1
fi

# Deploy contracts
echo "📦 Deploying contracts..."
forge script script/Deploy.s.sol \
    --rpc-url $LISK_SEPOLIA_RPC_URL \
    --broadcast \
    --verify \
    -vvvv

if [ $? -eq 0 ]; then
    echo "✅ Deployment successful!"
    echo "📝 Copy the displayed addresses to your .env file or save them for later use"
else
    echo "❌ Deployment failed!"
    exit 1
fi
