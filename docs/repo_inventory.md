# Alice Brain Repo Inventory

Last reviewed: 2026-06-06

Alice Brain currently contains both the public PB/AUTOS oven baseline and private operator extensions used by the current SUN/Alice setup. This inventory keeps cleanup safe while the repo is being prepared for broader sharing.

## Public Baseline To Keep

These files are part of the shareable worker-node product:

- `README.md`: oven setup, trust model, baseline model list, MAZA address guidance.
- `.env.example`: safe example variables only.
- `Pinball Oven Setup.command`: macOS one-click launcher.
- `bin/pinball_oven_setup`: interactive local setup helper.
- `bin/autos_cc_worker`: outbound PB/AUTOS worker for question/answer and embedding jobs.
- `bin/alice_context_cache.rb`: local context cache and embedding search for worker answers.
- `bin/alice_node_status`: local health/status check.
- `bin/install_baseline_models`: baseline Ollama model helper.
- `bin/agent_bridge`, `bin/alice_bridge_*`, `bin/cg_bridge_*`: RoRe/Rotary Relay control-plane tools.
- `bridge/README.md`, `bridge/README.redis.md`: bridge protocol notes.
- `context/autos_pinball.md`: public Pinball/AUTOS context.
- `docs/security.md`, `docs/worker_protocol.md`, `docs/bakes.md`, `docs/product_positioning.md`, `docs/model_lab.md`, `docs/cc_context_cache.md`: protocol, security, and product docs.

## Private Extensions To Preserve But Split Later

These are active or recently active for the current DOPE workflow. They should not be deleted during cleanup, but they should be split into a private extension before making a clean public release:

- `bin/dope_market_report_worker`: private DOPE report DOCX/Canva worker, vision/OCR/page QA, report validation, and report upload client.
- `bin/dope_canva_handoff`: local Canva packet helper for DOPE report output.
- `context/dope_printshop.md`: private DOPE `/ask` printshop context.
- `context/dope_strategy_proposal_style.md`: private DOPE strategy proposal style memory.
- DOPE-specific branches inside `bin/autos_cc_worker`, `bin/autos_cc_watch`, `bin/autos_watch_feed_mirror`, and `bin/alice_context_cache.rb`.

The current public setup path should default to PB/AUTOS only. The DOPE report extension is useful, but it contains customer-workflow assumptions that should not be bundled as the default public oven story.

## Generated Or Local-Only Artifacts

These should stay out of git:

- `.env`, `.env.*` except `.env.example`.
- worker logs, RoRe runtime logs, `bridge/*.jsonl`, bridge last-id files.
- `reports/`, generated DOCX/PDF/PNG/WAV files, report manifests.
- Python `__pycache__`, Ruby bundle state, Node modules.
- local preservation files such as `*.bak-*` and `*.bad-scp-dir-*/`.

## Current Runtime Notes

- SUN runs the bridge watcher from this repo with `cg-alice-bridge-watch.service`.
- The normal public worker lane should use outbound HTTPS to `https://pinball.cash`.
- Worker nodes must not hold production wallet keys, Backblaze credentials, database credentials, or public inbound services.
- MAZA payout accounting belongs to SUN/PB after accepted work, not to the worker node.

## Safe Cleanup Plan

1. Keep all current DOPE worker files until the active Alice report worker has a verified replacement or a private extension repo.
2. Keep all RoRe tools because the bridge is part of the current product.
3. Ignore generated files instead of deleting them during active tuning.
4. Before public release, split private DOPE files and scrub examples so no private client/process details are included by default.
