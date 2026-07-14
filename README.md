# Alice Brain

Alice Brain is the outbound-only worker for Pinball AI Ovens. A node polls a
scoped HTTPS queue, runs approved Ollama models locally, and submits an answer or
embedding for controller-side validation. Worker nodes never receive production
database credentials, storage credentials, or wallet private keys.

This repository is the public PB/AUTOS baseline. Customer-specific report,
messaging, and operator extensions are intentionally maintained outside this
repository.

## WHY ALICE?

AI compute should be useful without being powerful enough to own the application
that requested it. Alice Brain turns a Mac or Linux machine into a least-privileged
AI Oven: it receives one scoped job, runs an approved local model, returns a bounded
result, and lets the controller decide whether that result is accepted.

That separation provides four practical benefits:

- local Qwen/Ollama capacity can be added, removed, or upgraded independently;
- prompts and approved context can be processed locally without copying application
  credentials onto the oven;
- every result can report the actual node, model, output digest, and source job;
- a failed or untrusted oven can be paused or revoked without giving it database,
  storage, messaging, or wallet authority.

Alice is the compute plane, not the central brain of record. The name describes the
worker kit and runtime contract; authority remains with the controller.

## How the three projects fit

Alice Brain is designed to work with
[WIZWIKI](https://github.com/curiousbank/WIZWIKI) and
[Rotary Relay](https://github.com/curiousbank/rotary-relay):

- **WIZWIKI** is the application and controller. It owns organization data, approved
  knowledge, queues, policy, validation, audit records, and external-action gates.
- **Alice Brain** is the outbound-only execution plane. It polls scoped HTTPS work,
  runs local models, and submits answers, embeddings, or artifact metadata for
  controller-side validation.
- **Rotary Relay (RoRe)** is the optional private coordination plane. It carries node
  health, receipts, diagnostics, capability signals, and operator/agent coordination.
  It does not replace Alice's HTTPS job boundary or WIZWIKI's validation.

## Path to full potential

The public baseline is deliberately narrow. The next production milestones are:

1. finish per-oven, per-lane credentials with rotation, pause, and revocation;
2. add durable job leases, idempotent completion, retry limits, and dead-letter review;
3. attest model inventory and resource limits so scheduling matches real capacity;
4. isolate model execution with explicit filesystem, network, time, and memory budgets;
5. sign result receipts and expose controller-verified provenance and acceptance state;
6. connect RoRe health through a broker or per-node ACLs without granting raw Redis
   authority to an oven; and
7. keep payouts controller-side: close one 30-minute window, aggregate accepted Bakes
   by public address, and create at most one transaction output per address.

These are roadmap boundaries, not claims that the public worker implements every
milestone today.

## Requirements

- macOS 13+ on Apple Silicon, or a Linux system supported by Ollama
- 16 GB RAM for basic text work; 32 GB recommended
- 25 GB free disk
- Ruby 3.1+, Python 3.10+, Git, curl, and Ollama
- Outbound HTTPS access to `https://313.cash`

The baseline model set is:

- `qwen3:8b`
- `qwen3-embedding:4b`
- `qwen3-vl:8b`

## Quick Start

1. Clone this repository.
2. Log in at `https://313.cash/ai` and register an oven.
3. On macOS, open `Pinball Oven Setup.command`. On Linux, run
   `./bin/pinball_oven_setup`.
4. Paste the one-time setup bundle when prompted.
5. Verify the node with `./bin/alice_node_status`.
6. Start the worker with `./bin/autos_cc_worker`.

The worker reads `.env` as data. Do not `source .env` into a shell. The setup
script rejects shell metacharacters, private-key-looking content, and unknown
configuration keys.

## Configuration

Copy `.env.example` only when you are not using the Oven Registry bundle:

```sh
cp .env.example .env
chmod 600 .env
```

Required settings:

```text
ALICE_NODE_ID=my-oven-name
MAZA_ADDRESS=your-public-payout-address
AUTOS_WORKER_BASE_URL=https://313.cash
AUTOS_WORKER_ID=my-oven-name
AUTOS_WORKER_TOKEN=one-time-scoped-token
```

Supported queues are `all`, `web`, `telegram`, and `embeddings`. Queue scope is
enforced by the controller token as well as the worker header.

## Security Boundary

- The worker accepts only HTTPS controller URLs, except explicit loopback HTTP
  for local development.
- Completion, failure, and progress paths must remain on the configured
  controller origin.
- Ollama must remain on loopback unless remote Ollama access is explicitly
  enabled.
- Redirects are not followed, preventing bearer-token forwarding to another
  host.
- Job text is untrusted data. It is never passed to a shell.
- The controller validates all submitted work and decides whether a Bake is
  accepted.

See [docs/security.md](docs/security.md) and
[docs/worker_protocol.md](docs/worker_protocol.md) for the full trust model.
Rotary Relay coordination is maintained in its separate repository linked above.

## Tests

```sh
ruby -Itest -e 'Dir["test/**/*_test.rb"].sort.each { |file| require File.expand_path(file) }'
bash -n bin/pinball_oven_setup bin/install_baseline_models "Pinball Oven Setup.command"
bash test/setup_bundle_test.sh
python3 -m py_compile bin/alice_node_status
```
