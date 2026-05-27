# Alice / CC Context Cache

Alice is the local hardware and software stack for αὐτός. CC is the Context Cache running on Alice.

CC is the local Context Cache for αὐτός. It handles low-cost recall, local FAQ/guide answers, recent conversation context, and repetitive prompt work before PB spends frontier OpenAI tokens.

## Production Shape

```text
Telegram / PB / Chicle creates AutosMessage
  -> PB marks eligible free prompts for CC
  -> Alice polls SUN through /autos_worker/next
  -> CC answers with local Ollama
  -> Alice posts answer back to PB
  -> PB sends Telegram reply or updates the private Chicle UI
```

No public tunnel to Alice is required. CC makes outbound requests only.

## Model Lanes

Free web/Telegram prompts can route to CC when enabled:

```bash
AUTOS_LOCAL_WORKER_ENABLED=1
AUTOS_LOCAL_MODEL="llama3.2:3b"
AUTOS_FREE_MODEL="gpt-5.4"
AUTOS_FREE_REASONING="xhigh"
```

Paid prompt-power stays on the server-side frontier lane:

```bash
AUTOS_PAID_MODEL="gpt-5.5"
AUTOS_PAID_REASONING="xhigh"
```

Keep `AUTOS_LOCAL_WORKER_ENABLED` unset or `0` until Alice is online.

## SUN / PB Token

Create one long shared token on SUN and the Mac:

```bash
export AUTOS_WORKER_TOKEN="replace-with-long-random-secret"
```

The worker endpoints return `503` if `AUTOS_WORKER_TOKEN` is missing and `401` if the token does not match.

## Alice Setup

Install Ollama and pull a small local model:

```bash
brew install ollama
ollama serve
ollama pull llama3.2:3b
```

From a PB checkout on Alice:

```bash
export AUTOS_WORKER_BASE_URL="http://sun-dev:3333"
export AUTOS_WORKER_TOKEN="same-long-random-secret-from-sun"
export AUTOS_WORKER_ID="alice-cc-01"
export AUTOS_LOCAL_MODEL="llama3.2:3b"
./bin/autos_cc_worker
```

If Alice is away from the LAN, use the public route:

```bash
export AUTOS_WORKER_BASE_URL="https://313.cash"
```

Optional fallback if local Ollama fails:

```bash
export OPENAI_API_KEY="sk-proj-..."
export AUTOS_WORKER_OPENAI_FALLBACK=1
export AUTOS_WORKER_OPENAI_MODEL="gpt-5.4"
export AUTOS_WORKER_OPENAI_REASONING="xhigh"
```

## Notes

- CC is read-only.
- CC never receives paid prompt-power jobs in this first version.
- CC does not need direct database access.
- PB remains responsible for Telegram delivery, Chicle broadcasts, billing, and audit records.
