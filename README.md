# Alice Brain

Alice Brain is a private local AI worker node for a distributed AI network controlled by SUN/PB.

The node does not expose itself publicly. It polls token-protected PB/AUTOS worker endpoints over outbound HTTPS, runs local Ollama models, creates a result artifact, and sends that artifact back to SUN/PB. SUN/PB validates the result, updates the frontend database, and later accounts for MAZA bakes.

This is the worker-node side of an AI token bridge: local machines can provide useful compute without receiving production database access, wallet keys, or storage credentials.

## System Requirements

Alice Brain is designed for local-first AI work. It can run on modest hardware for text jobs, but a good oven should have enough memory and disk for Ollama models, logs, and generated artifacts.

Minimum practical node:

- macOS 13+ on Apple Silicon, or a modern Linux/Windows machine that can run Ollama.
- 16 GB RAM for light PB/AUTOS text jobs with one local model active at a time.
- 25 GB free disk after OS/app overhead.
- Stable outbound internet access to `https://313.cash`.
- `git`, `curl`, `bash` or `zsh`, Ruby, and Ollama.

Recommended baseline oven:

- Apple Silicon Mac or equivalent PC with 32 GB RAM or more.
- 50 GB free disk for the baseline model set, logs, reports, and cache growth.
- Always-on power/network if the node should earn bakes reliably.
- Ollama running locally at `http://127.0.0.1:11434`.
- The baseline models installed:
  - `qwen3-embedding:4b`
  - `qwen3:8b`
  - `qwen3-vl:8b`

Report, vision, and heavier local testing:

- 32 GB RAM is the supported target for baseline report/vision workflows.
- 64 GB RAM is better for multiple workers, long-context jobs, or heavier experimental models.
- Reserve 75-100 GB free disk if you plan to test additional LLMs, OCR models, or many generated DOCX/PDF artifacts.
- Optional OCR/model extras should be pulled only when the job lane needs them.

Network and security requirements:

- No inbound public port is required.
- Default worker traffic is outbound HTTPS polling to Pinball.
- RoRe/Redis access, if approved, must stay private through SSH/local tunnels.
- Never put wallet private keys, seed phrases, SSH private keys, Backblaze credentials, OpenAI keys, database credentials, or RPC passwords in this repo.

## Mac One-Click Setup

On macOS, open this file from Finder:

```text
Pinball Oven Setup.command
```

The launcher will:

- open `https://313.cash/ai`,
- wait for you to paste the one-time Oven Registry setup bundle from a logged-in Pinball account,
- save it to `.env` with private file permissions,
- install or verify the baseline Ollama models,
- check the PB/AUTOS worker status endpoint,
- optionally start `./bin/autos_cc_worker`.

The setup bundle is shown once by PB. The repo does not include production tokens.

## Trust Model

- SUN/PB is the controller, queue, storage gate, payment accountant, and policy authority.
- The Oven Registry is the Pinball web interface for enrolling worker ovens, issuing scoped worker tokens, checking node health, and assigning payout addresses.
- Alice Brain is an untrusted worker node.
- Worker nodes only receive scoped job payloads.
- Worker nodes cannot write production records or pay themselves.
- Completion is a request, not proof of work. SUN/PB decides whether work is accepted.
- MAZA bakes are counted only after SUN/PB accepts paid PB/AUTOS work.
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
- `qwen3-vl:8b` inspects images, OCR-like visual content, and rendered report pages.
- `glm-ocr:bf16` is optional and not required for the baseline oven.

## Oven Registry

The Oven Registry is the Pinball-side setup page for distributed AI worker nodes:

```text
https://313.cash/ai
```

If the dedicated host is routed, `https://ai.313.cash` should land on the same PB `/ai` registry experience.

It should make node setup simple without weakening the trust model:

- create a node record and stable `ALICE_NODE_ID`,
- collect the node operator's public `MAZA_ADDRESS`,
- show the public faucet/source address as an example,
- issue scoped worker tokens automatically for the default safe lanes,
- require operator approval for elevated or private job lanes,
- generate a local `.env` bundle for the operator to save on their machine,
- show SSH tunnel commands and model install commands,
- show node health from worker `/status` endpoints and RoRe heartbeats,
- show paid Bake counts and 30-minute payout status.

The Oven Registry should not store private wallet keys, seed phrases, SSH private keys, Backblaze credentials, OpenAI keys, or production database credentials. It stores public payout addresses and scoped worker credentials only.

Public visitors see aggregate oven health only. Exact node names, worker models, token tools, and the registered oven list are hidden unless you are looking at your own ovens or you are an approved operator.

### Oven name and worker identity

The name a person types on PB `/ai` is the starting point for that Mac's public worker identity. For example, Ethan's Mac can be named `askalice.autos`, while another operator can choose any other stable name.

PB normalizes the entered Oven Name into a unique `node_id`:

- `askalice.autos` stays `askalice.autos`.
- `Jane Studio Mac` becomes `jane-studio-mac`.
- If a name is already taken, PB adds a numeric suffix.

The one-time setup bundle writes that same id into the local Alice Brain `.env` as `ALICE_NODE_ID`, `AI_OVEN_NODE_ID`, and `AUTOS_WORKER_ID`. `bin/autos_cc_worker` reads `AUTOS_WORKER_ID`, polls PB over outbound HTTPS, and sends it as `X-Autos-Worker-Id`.

The scoped worker token is the authority. PB stores only token digests, ties the token to the registered `AiOvenNode`, and uses the worker id/name for display, routing, health, and queue visibility.

Where the flow lives:

- PB model: `AiOvenNode` stores `name`, `node_id`, public MAZA payout address, scopes, token digest, and heartbeat metadata.
- PB controller: `AiOvenNodesController` creates the oven record, generates the setup bundle, and rotates/revokes tokens.
- PB worker API: `AutosWorkerController` accepts outbound worker status, claims, and completions from Alice Brain.
- PB dashboard snapshot: `AiOvenRegistrySnapshot` merges registered ovens, worker telemetry, and live queue status for `/ai`.
- Alice Brain setup: `bin/pinball_oven_setup` saves the PB setup bundle into `.env`.
- Alice Brain status: `bin/alice_node_status` verifies the local `.env` can reach PB.
- Alice Brain worker: `bin/autos_cc_worker` claims jobs and submits completed artifacts.

## New Node Quickstart

1. Clone this repo.
2. Install Ollama and the baseline models.
3. Create or copy a public MAZA payout address.
4. Log in at `https://313.cash`.
5. Open `https://313.cash/ai`.
6. Register an oven with the name you want that Mac to use, such as `askalice.autos`, `jane-studio-mac`, or any other stable unit name.
7. Copy the one-time setup bundle into `.env`, or let `Pinball Oven Setup.command` do it.
8. Run `./bin/alice_node_status`.
9. Start the approved worker lane with `./bin/autos_cc_worker`.

Do not expect production worker tokens from GitHub. Default scoped tokens are issued by the Oven Registry after login, are shown once, and are stored server-side only as HMAC digests. Elevated/private lanes still require operator approval.

## Configure A Node

Copy the env template and keep the real file out of git:

```sh
cp .env.example .env
chmod 600 .env
```

Required values:

```sh
ALICE_NODE_ID=my-oven-name
MAZA_ADDRESS=
AUTOS_WORKER_BASE_URL=https://313.cash
AUTOS_BRAIN_BASE_URL=https://313.cash
AUTOS_WORKER_ID=my-oven-name
AUTOS_WORKER_QUEUE=all
AUTOS_WORKER_TOKEN=
```

Use the Oven Registry setup bundle for the real ids and worker tokens. Do not invent tokens and do not commit tokens. If you need an elevated/private lane, ask the SUN/PB operator to approve that scope.

Worker queue modes:

- `all`: claim any PB/AUTOS job. This is the default for compatibility.
- `web`: claim non-Telegram PB/AUTOS jobs.
- `telegram`: claim only Telegram PB/AUTOS jobs.
- `sms` or `comms`: claim only DVE SMS response draft jobs. This lane skips embedding pulls so live SMS replies do not wait behind vector-sync work.
- `embeddings`: claim only embedding/vector storage jobs.

To run a dedicated Telegram worker beside the normal worker:

```sh
cd ~/Desktop/alice-brain
set -a
source .env
set +a
AUTOS_WORKER_ID=alice-telegram-01 AUTOS_WORKER_QUEUE=telegram AUTOS_WORKER_POLL_SECONDS=1 ./bin/autos_cc_worker
```

To run a dedicated DOPE/DVE SMS response worker beside the normal worker:

```sh
cd ~/Desktop/alice-brain
set -a
source .env
set +a
AUTOS_WORKER_ID=alice-dope-sms-01 AUTOS_WORKER_QUEUE=sms AUTOS_WORKER_POLL_SECONDS=1 AUTOS_CC_EMBEDDING_WORKER_ENABLED=0 ./bin/autos_cc_worker
```

For production-style use, install the dedicated SMS worker as a supervised service instead of leaving it in a terminal:

```sh
cd ~/Desktop/alice-brain
./bin/install_dope_sms_worker_service
```

On macOS this creates a LaunchAgent named `com.curiousbank.alice-brain.dope-sms-worker`. The installer copies a private runtime copy to `~/.local/share/alice-brain-runtime` so launchd does not need Desktop or Documents permissions. Re-run the installer after pulling worker changes. On Linux it creates a user systemd service named `dope-sms-worker.service`. Both run `bin/start_dope_sms_worker`, which forces the worker queue to `sms`, disables embedding pulls on that process, and respects your normal `.env` `AUTOS_WORKER_BASE_URL` unless `DVE_SMS_WORKER_BASE_URL` is explicitly set.

If the public DOPE hostname is blocked or has TLS trouble from the worker machine, use the private SSH tunnel mode:

```sh
DVE_SMS_TUNNEL_ENABLED=1
DVE_SMS_TUNNEL_SSH_TARGET=sun-dev
DVE_SMS_TUNNEL_PORT=18182
DVE_SMS_WORKER_BASE_URL=http://127.0.0.1:18182
```

With tunnel mode enabled, the installer also starts `com.curiousbank.alice-brain.dope-worker-tunnel` on macOS or `dope-worker-tunnel.service` on Linux.

The SMS worker still needs Ollama running locally and the baseline models installed:

```sh
ollama pull qwen3:8b
ollama pull qwen3:30b
ollama pull qwen3-embedding:8b-q4_K_M
```

## Prompt For A Setup AI

Use this prompt with Codex or another local AI helper on the machine you want to turn into an oven:

```text
You are setting up this computer as a Pinball AI Oven using the Alice Brain repo.

Goal:
Create a private outbound-only worker node. Do not expose local ports publicly. Do not commit secrets.

Steps:
0. Confirm the machine meets the README system requirements. A 32 GB Mac or equivalent PC is the recommended baseline.
1. Clone or open the Alice Brain repo.
2. On macOS, open `Pinball Oven Setup.command`; otherwise run `./bin/pinball_oven_setup`.
3. Install Ollama if prompted.
4. Pull only the baseline models:
   - qwen3-embedding:4b
   - qwen3:8b
   - qwen3-vl:8b
5. Go to https://313.cash, create/log into a member account, then open https://313.cash/ai.
6. Register an oven with a stable node name and a public MAZA payout address.
7. Copy the one-time Oven Registry setup bundle when the setup script asks for it.
8. Verify .env contains ALICE_NODE_ID, AI_OVEN_NODE_TOKEN or PINBALL_OVEN_TOKEN, MAZA_ADDRESS, AUTOS_WORKER_BASE_URL, AUTOS_WORKER_ID, and AUTOS_WORKER_TOKEN.
9. Run ./bin/alice_node_status.
10. Start the approved PB/AUTOS worker process.

Safety:
- Never print or commit tokens.
- Never add wallet private keys, seed phrases, SSH private keys, Backblaze credentials, OpenAI keys, or production database credentials.
- Never run Thumper on this worker node.
- Treat SUN/PB as the only controller, validator, storage gate, and payment accountant.
```

## MAZA Address

Each node should set a public MAZA payout address:

```sh
MAZA_ADDRESS=your_public_maza_address_here
```

Example public faucet/source address:

```sh
EXAMPLE_MAZA_ADDRESS=MNHxyG4ZRD5acR9HAjfWnSFBHMKmCvTGLD
```

That example is useful for local testing and documentation. Real worker nodes should replace `MAZA_ADDRESS` with their own public payout address before asking SUN/PB to count bakes.

If you do not have one:

1. Go to `https://313.cash`.
2. Create an account or log in.
3. Open your crypto/profile or wallet area.
4. Create or copy your MAZA address.
5. Paste the public address into `.env` as `MAZA_ADDRESS`.

Do not put wallet private keys, seed phrases, node wallet files, or RPC passwords in this repo.

## Secure Connection

The default PB/AUTOS oven lane uses outbound HTTPS:

```sh
AUTOS_WORKER_BASE_URL=https://313.cash
```

The node never opens an inbound port. Scoped tokens come from the logged-in Oven Registry page at `https://313.cash/ai`.

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

Run the PB/AUTOS worker:

```sh
set -a
source .env
set +a
./bin/autos_cc_worker
```

Check RoRe:

```sh
./bin/agent_bridge status --role alice
./bin/agent_bridge health --role alice
```

## Bake Accounting

Alice Brain includes `MAZA_ADDRESS` and scoped worker identity in PB/AUTOS completions. SUN/PB should count bakes only after:

- the worker token is valid,
- the worker ID matches the registered oven,
- the worker actually claimed the message,
- the paid PB/AUTOS answer validates and is accepted,
- the bake has not already been counted.

MAZA payouts should be grouped by address and paid by PB/Thumper from accepted bakes only. The preferred shape is one 30-minute batch transaction with one summed output per active MAZA address. See `docs/bakes.md`.

The payout builder must normalize duplicate rows before sending. If the same `maza_address` appears more than once in the same closed payout window, PB should add the amounts together and create one payment output for that address inside the 30-minute batch transaction.

## Safety

- Never commit `.env`, tokens, API keys, SSH keys, Redis credentials, logs, report files, manifests, or local indexes.
- Do not run Thumper on worker nodes.
- Do not hold production MAZA wallet keys on worker nodes.
- Do not connect worker nodes directly to production databases.
- Do not expose a public HTTP listener from Alice Brain.
- Prefer local models for low-cost/private work and let SUN decide if cloud fallback is allowed.
