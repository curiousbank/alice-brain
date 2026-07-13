# Public Release Checklist

Use this before publishing Alice Brain as a node anyone can clone.

## Required

- No real secrets in tracked files.
- `.env.example` contains placeholders only.
- Setup docs use outbound HTTPS polling by default.
- No production database, Backblaze, wallet, Redis, or SSH private credentials are required on the worker node.
- One-time setup bundles are generated from Pinball `/ai` and stored locally with `chmod 600`.
- Worker tokens are scoped, stored on SUN/PB as digests, and revocable.
- Worker completions are accepted only after SUN/PB validates worker identity, lane, artifact, and manifest.
- MAZA payouts are batched by SUN/PB from accepted bakes only.

## Baseline Models

The public baseline should stay small and clear:

- `qwen3-embedding:4b`
- `qwen3:8b`
- `qwen3-vl:8b`

Optional:

- `glm-ocr:bf16`

## Keep Private Or Optional

- DOPE market report worker.
- DOPE Canva handoff helper.
- DOPE printshop and strategy proposal context.
- Any customer-specific report examples, manifests, generated files, local logs, or Backblaze paths.

## Smoke Test

1. Fresh clone on a Mac.
2. Open `Pinball Oven Setup.command`.
3. Register an oven at `https://pinball.cash/ai`.
4. Paste the setup bundle.
5. Verify the script rejects private-key-looking text.
6. Verify Ollama models are installed.
7. Verify `bin/alice_node_status` reaches the PB/AUTOS status endpoint.
8. Verify the node can poll a safe test job.
9. Verify a completed job creates an accepted bake only on SUN/PB.
