# Alice Brain

Alice Brain is the private local context-cache worker for the Pinball/AUTOS system.

The purpose of Alice is to keep simple, repetitive, local-first AI work close to the operator machine while Pinball remains the production command center. Pinball queues approved AUTOS work, Alice polls through a private worker route, answers with a local model when appropriate, and leaves paid/frontier OpenAI work to the main application.

## What lives here

- `bin/autos_cc_worker` runs the local worker loop.
- `docs/cc_context_cache.md` documents the context-cache architecture.
- `.env.example` shows required local settings without secrets.

## Security rules

- Never commit `.env`, API keys, Telegram tokens, worker tokens, SSH keys, or production database credentials.
- Alice only talks to Pinball through authenticated worker routes.
- Paid/frontier model selection remains controlled by Pinball server policy.
- Local free answers are allowed only when Pinball explicitly queues them.

## Planned private remote

Target GitHub repo: `TIM3H3AD/alice-brain`
Visibility: private

