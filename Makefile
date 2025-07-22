# ------------------------------------------------------------------------------
# Foundry / PaymentGateway project Makefile
# ------------------------------------------------------------------------------

# Read RPC and private key (required)
RPC_URL   ?= https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
PRIVATE_KEY ?= $(shell grep -E '^PRIVATE_KEY=' .env | cut -d '=' -f2)

# Default OWNER & FEE_COLLECTOR to the deployer address if not provided
DEPLOYER_ADDR := $(shell cast wallet address --private-key $(PRIVATE_KEY))
OWNER       ?= $(DEPLOYER_ADDR)
FEE_COLLECTOR ?= $(OWNER)

# Forwarder (set to 0x0 to disable)
TRUSTED_FORWARDER ?= 0x0000000000000000000000000000000000000000

# Script name/path helpers
SCRIPT_NAME := DeployPaymentGateway
SCRIPT_PATH := script/${SCRIPT_NAME}.s.sol:${SCRIPT_NAME}

# ------------------------------------------------------------------------------
# Default
# ------------------------------------------------------------------------------
.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ------------------------------------------------------------------------------
# Development
# ------------------------------------------------------------------------------
.PHONY: install
install: ## Install dependencies
	forge install

.PHONY: build
build: ## Compile contracts
	forge build

.PHONY: test
test: ## Run all tests
	forge test -vvv

.PHONY: snapshot
snapshot: ## Create gas snapshot
	forge snapshot

.PHONY: fmt
fmt: ## Lint / format code
	forge fmt

.PHONY: clean
clean: ## Clean build artifacts
	forge clean

# ------------------------------------------------------------------------------
# Deployment
# ------------------------------------------------------------------------------
.PHONY: deploy
deploy: build test ## Deploy to the configured chain
	@forge script $(SCRIPT_PATH) \
		--rpc-url $(RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--sig "run()" \
		--broadcast \
		--verify \
		-vvv

.PHONY: deploy-dry
deploy-dry: build ## Dry-run deployment (no broadcast)
	@forge script $(SCRIPT_PATH) \
		--rpc-url $(RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--sig "run()" \
		-vvv
