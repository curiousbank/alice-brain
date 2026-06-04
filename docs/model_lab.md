# Alice Model Lab

SUN/CG switched DOPE market reports back to dynamic RAG dropdowns.

## Active Dropdowns

First dropdown: embedder

- `qwen3-embedding:0.6b`
- `qwen3-embedding:4b`
- `qwen3-embedding:8b-q4_K_M`

Second dropdown: Qwen writer model

- `qwen3:8b`
- `qwen3:30b`
- `qwen3.5:9b-mlx`
- `qwen3.6:27b-mlx`
- `qwen3.6:35b-mlx`

MLX model IDs are first-class selections. Do not rewrite `*-mlx` values to regular Ollama models. If a selected MLX model is unavailable, fail clearly or report the fallback in the manifest.

## Runtime Contract

DOPE sends:

- `ai_runtime.model_ladder = [selected_model, selected_model]`
- `ai_runtime.pipeline_mode = dynamic_two_round_rag`
- `ai_runtime.retry_context_strategy = vectorize_hubspot_facts_first_draft_and_quality_errors_before_second_round`

## Required Worker Behavior

Round 1:

- Run the selected embedder over HubSpot/account/media/report-contract data.
- Generate the first draft with the selected Qwen model.

Round 2:

- Build a second retrieval query from HubSpot facts, first draft copy, validation errors, and the retry note.
- Run the same selected embedder again against that second query.
- Rewrite with the same selected Qwen model.

Do not vectorize validation errors alone. Keep HubSpot facts in the retry vector so the report stays client-specific instead of merely validator-specific.
