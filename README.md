# PaymentGateway

A minimal, **EIP-2771** meta-transaction compatible payment gateway that:

- Accepts **any ERC-20** token the owner activates
- Charges a **configurable fee** (in basis-points) at call-time
- Accumulates fees in-contract and lets the owner **sweep** them to an immutable fee collector
- Is **re-entrancy protected** and **ownable**

---

📦 Repository layout

```
.
├── src/
│   └── PaymentGateway.sol       # Main contract
├── script/
│   └── DeployPaymentGateway.s.sol
├── test/
│   ├── PaymentGateway.t.sol
│   └── mocks/
│       └── MockERC20.sol
├── Makefile
├── README.md
└── foundry.toml
```

---

🛠️ Quick start (Foundry)

1. Install dependencies

   ```bash
   make install
   ```

2. Compile

   ```bash
   make build
   ```

3. Run all tests

   ```bash
   make test
   ```

4. Lint & format
   ```bash
   make fmt
   ```

---

🚀 Deployment

Create a `.env` file (never commit it):

```bash
PRIVATE_KEY=0xYOUR_PRIVATE_KEY
RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_ALCHEMY_KEY
OWNER=0xYourOwnerAddress          # optional, defaults to deployer
FEE_COLLECTOR=0xYourTreasury      # optional, defaults to OWNER
```

Deploy:

```bash
make deploy
```

Dry-run only:

```bash
make deploy-dry
```

---

🧪 Testing

The test-suite (`test/PaymentGateway.t.sol`) covers:

- Admin token management (`manageToken`, `toggleTokenActive`)
- Happy-path & edge-case payments (inactive token, fee too high, zero amounts, etc.)
- Fee accumulation & sweeping
- View helpers (`getAllActive`, `getAccumulatedFees`)
- Re-entrancy guard sanity checks

Run with traces:

```bash
forge test -vvv
```

---

⚙️ Environment variables

| Variable        | Default  | Purpose                          |
| --------------- | -------- | -------------------------------- |
| `PRIVATE_KEY`   | —        | Deployer key (required)          |
| `RPC_URL`       | —        | Target chain RPC endpoint        |
| `OWNER`         | deployer | Contract owner                   |
| `FEE_COLLECTOR` | `OWNER`  | Address that receives swept fees |

---

📜 Makefile targets

| Target            | Description                  |
| ----------------- | ---------------------------- |
| `make help`       | Show all commands            |
| `make install`    | `forge install` dependencies |
| `make build`      | Compile contracts            |
| `make test`       | Run full test suite          |
| `make fmt`        | Format Solidity & JS         |
| `make clean`      | Remove cache & artifacts     |
| `make deploy`     | Build, test, deploy & verify |
| `make deploy-dry` | Simulate deployment          |

---

🔐 Security notes

- The `feeCollector` is **immutable** and **cannot be changed** after deployment.
- The owner can activate/deactivate tokens and sweep fees, but cannot alter fee percentages (they are supplied per call).
- All external entry-points use `nonReentrant`.

---

License
MIT
