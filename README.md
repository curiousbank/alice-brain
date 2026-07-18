# Alice Brain

Alice Brain is the outbound-only worker for Pinball AI Ovens. A node polls a
scoped HTTPS queue, runs approved Ollama models locally, and submits an answer or
embedding for controller-side validation. Worker nodes never receive production
database credentials, storage credentials, or wallet private keys.

This repository is the public PB/AUTOS baseline. Customer-specific report,
messaging, and operator extensions are intentionally maintained outside this
repository.

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

Supported queues are `all`, `web`, `telegram`, `embeddings`, and `sms_bot`.
Queue scope is enforced by the controller token as well as the worker header.
The `sms_bot` lane accepts only private SMS drafting jobs. It does not run
embeddings or add the repository's public Pinball product context to customer
conversations.

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
- Rotary Relay remains behind the authenticated controller. Ovens report
  capabilities over HTTPS and never receive direct Redis access.

See [docs/security.md](docs/security.md) and
[docs/worker_protocol.md](docs/worker_protocol.md) for the full trust model.
Rotary Relay coordination is maintained separately at
[curiousbank/rotary-relay](https://github.com/curiousbank/rotary-relay).

## Tests

```sh
ruby -Itest -e 'Dir["test/**/*_test.rb"].sort.each { |file| require File.expand_path(file) }'
bash -n bin/pinball_oven_setup bin/install_baseline_models "Pinball Oven Setup.command"
bash test/setup_bundle_test.sh
python3 -m py_compile bin/alice_node_status
```
