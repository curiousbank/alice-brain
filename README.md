# Alice Brain

Alice Brain is a private local AI worker node for a distributed AI network controlled by SUN/PB.

The node does not expose itself publicly. It opens outbound SSH tunnels, polls token-protected worker endpoints, runs local Ollama models, creates a result artifact, and sends that artifact back to SUN. SUN validates the result, stores files in the approved Backblaze location, updates the frontend database, and later accounts for MAZA bakes.

This is the worker-node side of an AI token bridge: local machines can provide useful compute without receiving production database access, wallet keys, or storage credentials.

## Trust Model

- SUN/PB is the controller, queue, storage gate, payment accountant, and policy authority.
- The Oven Registry is the Pinball web interface for enrolling worker ovens, issuing scoped worker tokens, checking node health, and assigning payout addresses.
- Alice Brain is an untrusted worker node.
- Worker nodes only receive scoped job payloads.
- Worker nodes cannot choose Backblaze keys, write production records, or pay themselves.
- Completion is a request, not proof of work. SUN decides whether a file is accepted.
- MAZA bakes are counted only after SUN accepts the result.
- RoRe, the Rotary Relay, is the Redis/file control-plane for agent messages and health. It is not the file transport and not the payment ledger.

## Baseline Models

Install Ollama and the baseline models:

```sh
brew install ollama
ollama serve

ollama pull qwen3-embedding:4b
ollama pull qwen3:8b
ollama pull qwen3-vl:8b
```

Optional OCR booster for report media scans:

```sh
ollama pull glm-ocr:bf16
```

Baseline roles:

- `qwen3-embedding:4b` retrieves local/job context.
- `qwen3:8b` writes and repairs most local work.
- `qwen3-vl:8b` inspects images and rendered report pages.
- `glm-ocr:bf16` is optional for explicit OCR extraction when a job enables OCR.

## Oven Registry

The Oven Registry is the Pinball-side setup page for distributed AI worker nodes:

```text
https://313.cash/ai
```

It should make node setup simple without weakening the trust model:

- create a node record and stable `ALICE_NODE_ID`,
- collect the node operator's public `MAZA_ADDRESS`,
- show the public faucet/source address as an example,
- issue scoped worker tokens automatically for the default safe lanes,
- require operator approval for elevated or private job lanes,
- generate a local `.env` bundle for the operator to save on their machine,
- show SSH tunnel commands and model install commands,
- show node health from worker `/status` endpoints and RoRe heartbeats,
- show accepted Bake counts and hourly payout status.

The Oven Registry should not store private wallet keys, seed phrases, SSH private keys, Backblaze credentials, OpenAI keys, or production database credentials. It stores public payout addresses and scoped worker credentials only.

Public visitors see aggregate oven health only. Exact node names, worker models, token tools, and the registered oven list are hidden unless you are looking at your own ovens or you are an approved operator.

## New Node Quickstart

1. Clone this repo.
2. Install Ollama and the baseline models.
3. Create or copy a public MAZA payout address.
4. Log in at `https://pinball.cash`.
5. Open `https://313.cash/ai`.
6. Register an oven with your node name, stable `ALICE_NODE_ID`, and public `MAZA_ADDRESS`.
7. Copy the one-time setup bundle into `.env`.
9. Start the private SSH tunnels supplied by the operator.
10. Run `./bin/alice_node_status`.
11. Start the approved worker lane.

Do not expect production worker tokens from GitHub. Default scoped tokens are issued by the Oven Registry after login, are shown once, and are stored server-side only as HMAC digests. Elevated/private lanes still require operator approval.

## Configure A Node

Copy the env template and keep the real file out of git:

```sh
cp .env.example .env
chmod 600 .env
```

Required values:

```sh
ALICE_NODE_ID=alice-yourname-01
MAZA_ADDRESS=
DOPE_REPORT_WORKER_BASE_URL=http://127.0.0.1:8182
DOPE_REPORT_WORKER_ID=alice-yourname-reports-01
DOPE_REPORT_WORKER_TOKEN=
AUTOS_WORKER_BASE_URL=http://127.0.0.1:3333
AUTOS_WORKER_ID=alice-yourname-autos-01
AUTOS_WORKER_TOKEN=
```

Use the Oven Registry setup bundle for worker tokens. Do not invent tokens and do not commit tokens. If you need an elevated/private lane, ask the SUN/PB operator to approve that scope.

## MAZA Address

Each node should set a public MAZA payout address:

```sh
MAZA_ADDRESS=your_public_maza_address_here
```

Example public faucet/source address:

```sh
EXAMPLE_MAZA_ADDRESS=MCU8e7DdJ8D2on5fBQfb4jTn2qX4DGiikw
```

That example is useful for local testing and documentation. Real worker nodes should replace `MAZA_ADDRESS` with their own public payout address before asking SUN/PB to count bakes.

If you do not have one:

1. Go to `https://pinball.cash`.
2. Create an account or log in.
3. Open your crypto/profile or wallet area.
4. Create or copy your MAZA address.
5. Paste the public address into `.env` as `MAZA_ADDRESS`.

Do not put wallet private keys, seed phrases, node wallet files, or RPC passwords in this repo.

## Secure Connection

Use outbound SSH tunnels. Example:

```sh
ssh -N -L 8182:127.0.0.1:8182 sun-dev
ssh -N -L 3333:127.0.0.1:3333 sun-dev
```

The host alias and tunnel ports must come from the operator or the Oven Registry setup bundle. Do not expose worker ports publicly.

For RoRe Redis health and agent messages:

```sh
ssh -N -L 6389:127.0.0.1:6379 sun-dev
export AGENT_BRIDGE_REDIS_URL=redis://127.0.0.1:6389/15
```

Redis must remain private and localhost-bound on SUN. Do not expose Redis publicly.

## Run

Check node readiness:

```sh
./bin/alice_node_status
```

Install baseline models:

```sh
./bin/install_baseline_models
```

Run a report worker:

```sh
set -a
source .env
set +a
./bin/dope_market_report_worker
```

Check RoRe:

```sh
./bin/agent_bridge status --role alice
./bin/agent_bridge health --role alice
```

## Bake Accounting

Alice Brain includes `MAZA_ADDRESS` and a `bake` object in completed report manifests. SUN/PB should count bakes only after:

- the worker token is valid,
- the file validates,
- the file is stored under a SUN-approved Backblaze key,
- the production record is updated,
- the bake has not already been counted.

Hourly MAZA payouts should be grouped by address and paid by PB/Thumper from accepted bakes only. The preferred shape is one hourly batch transaction with one summed output per active MAZA address. See `docs/bakes.md`.

The payout builder must normalize duplicate rows before sending. If the same `maza_address` appears more than once in the same closed payout window, PB should add the amounts together and create one payment output for that address inside the hourly batch transaction.

## Safety

- Never commit `.env`, tokens, API keys, SSH keys, Redis credentials, logs, report files, manifests, or local indexes.
- Do not run Thumper on worker nodes.
- Do not hold production MAZA wallet keys on worker nodes.
- Do not connect worker nodes directly to production databases.
- Do not expose a public HTTP listener from Alice Brain.
- Prefer local models for low-cost/private work and let SUN decide if cloud fallback is allowed.
