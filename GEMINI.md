# GEMINI.MD: AI Collaboration Guide

This document provides essential context for AI models interacting with this project. Adhering to these guidelines will ensure consistency and maintain code quality.

## 1. Project Overview & Purpose

* **Primary Goal:** This project is a secure and gas-efficient smart contract for processing payments using multiple stablecoins. It supports EIP-2771 meta-transactions, allowing for gas-less transactions from the user's perspective.
* **Business Domain:** Fintech, specifically in the domain of cryptocurrency payments and decentralized applications (dApps).

## 2. Core Technologies & Stack

* **Languages:** Solidity ^0.8.29
* **Frameworks & Runtimes:** Foundry (includes Forge, Cast, Anvil, Chisel)
* **Databases:** Not applicable (blockchain-based).
* **Key Libraries/Dependencies:** OpenZeppelin Contracts (v4.x)
* **Package Manager(s):** Git submodules for dependencies (e.g., openzeppelin-contracts, forge-std).

## 3. Architectural Patterns

* **Overall Architecture:** The project follows a standard smart contract architecture, with a core contract (`StablecoinPaymentGateway.sol`) that inherits from OpenZeppelin's secure and tested contracts (`Ownable`, `ReentrancyGuard`). It's designed to be deployed as a standalone contract on an Ethereum-compatible blockchain.
* **Directory Structure Philosophy:**
    * `/src`: Contains the primary source code for the smart contract.
    * `/script`: Holds deployment scripts for the smart contract.
    * `/test`: Contains tests for the smart contract.
    * `/lib`: Contains git submodules for dependencies like OpenZeppelin Contracts and Forge-Std.
    * `/out`: Contains the compiled contract artifacts.
    * `/broadcast`: Contains deployment logs.
    * `/cache`: Contains cached data from the build process.

## 4. Coding Conventions & Style Guide

* **Formatting:** The project uses `forge fmt` for code formatting. The style is consistent with the default Solidity style guide.
* **Naming Conventions:**
    * `contracts`: PascalCase (`StablecoinPaymentGateway`)
    * `functions`: camelCase (`manageToken`, `pay`)
    * `variables`: camelCase (`trustedForwarder`)
    * `events`: PascalCase (`TokenManaged`, `PaymentProcessed`)
* **API Design:** The smart contract exposes functions for managing tokens, processing payments, and withdrawing fees. It also includes view functions for retrieving information about the contract's state.
* **Error Handling:** The contract uses `require` statements for input validation and access control. It also uses custom errors for more gas-efficient error handling.

## 5. Key Files & Entrypoints

* **Main Entrypoint(s):** `src/StablecoinPaymentGateway.sol` is the core smart contract.
* **Configuration:** `foundry.toml` is the main configuration file for the Foundry toolchain.
* **CI/CD Pipeline:** `.github/workflows/test.yml` defines the continuous integration pipeline.

## 6. Development & Testing Workflow

* **Local Development Environment:**
    1. Install Foundry.
    2. Run `anvil` to start a local blockchain node.
    3. Use `forge build` to compile the contracts.
    4. Use `forge test` to run the tests.
* **Testing:** Tests are written in Solidity and run using the Foundry framework. The main test file is `test/StablecoinPaymentGateway.t.sol`. To run tests, use the command `forge test`.
* **CI/CD Process:** The CI pipeline is triggered on every push and pull request. It runs the following checks:
    1. `forge fmt --check`: Checks for code formatting.
    2. `forge build --sizes`: Builds the contracts and checks their sizes.
    3. `forge test -vvv`: Runs the tests with verbose output.

## 7. Specific Instructions for AI Collaboration

* **Contribution Guidelines:** There is no `CONTRIBUTING.md` file, but based on the project structure and CI/CD pipeline, any new code should be accompanied by corresponding tests and should pass the formatting and build checks.
* **Infrastructure (IaC):** Not applicable.
* **Security:** Be mindful of security best practices for smart contracts. Do not hardcode secrets or keys. Ensure any changes to the contract logic are secure and vetted.
* **Dependencies:** New dependencies should be added as git submodules in the `lib` directory.
* **Commit Messages:** There is no explicit commit message convention, but it's recommended to follow the Conventional Commits specification (e.g., `feat:`, `fix:`, `docs:`).
