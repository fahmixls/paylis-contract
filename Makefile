# ===========================
#  Env / RPC aliases
# ===========================
ANVIL_RPC      := http://localhost:8545
SEPOLIA_RPC    := https://rpc.sepolia-api.lisk.com
MAINNET_RPC    := https://rpc.api.lisk.com

# Default to Anvil
RPC_URL        ?= $(ANVIL_RPC)

# ===========================
#  Build & Test
# ===========================
.PHONY: build test clean snapshot

build:
	forge build

test:
	forge test -vv

clean:
	forge clean

snapshot:
	forge snapshot

# ===========================
#  Local deployment
# ===========================
.PHONY: anvil
anvil:
	anvil --chain-id 31337 --accounts 10

.PHONY: deploy-anvil
deploy-anvil: RPC_URL=$(ANVIL_RPC)
deploy-anvil: deploy

# ===========================
#  Public testnet / mainnet
# ===========================
.PHONY: deploy-sepolia
deploy-sepolia: RPC_URL=$(SEPOLIA_RPC)
deploy-sepolia: deploy

.PHONY: deploy-mainnet
deploy-mainnet: RPC_URL=$(MAINNET_RPC)
deploy-mainnet: deploy

# ===========================
#  Shared deploy recipe
# ===========================
.PHONY: deploy
deploy:
	@echo "Deploying to $(RPC_URL)"
	forge script script/Deploy.s.sol:DeployGateway \
		--rpc-url $(RPC_URL) \
		--private-key ${PRIVATE_KEY} \
		--broadcast \
		--verify \
		-vv

# ===========================
#  Verify only (if needed)
# ===========================
.PHONY: verify
verify:
	@echo "Manual verification not implemented yet"
