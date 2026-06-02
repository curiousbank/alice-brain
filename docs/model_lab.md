# Alice Model Lab

SUN/CG selected five local Ollama models to experiment with on Alice.

## Pull Order

1. `qwen3:30b` — primary heavy DOPE report brain, 19GB, 256K context.
2. `qwen3.6:27b` — latest Qwen candidate, 17GB, 256K context. Retest because Ollama now lists the tag.
3. `gemma4:e4b` — fast business prose/multimodal candidate, 9.6GB, 128K context.
4. `granite4.1:8b` — enterprise RAG/structured JSON/extraction candidate, 5.3GB, 128K context.
5. `devstral-small-2:24b` — local coding/agent engineering candidate, 15GB, 384K context.

## Fallbacks

- `gpt-oss:20b` if we want an OpenAI open-weight local comparison or Devstral is too heavy.
- `qwen3.5:27b` if `qwen3.6:27b` still fails after update/retry.
- `glm-4.7-flash` only after confirming Alice has the required Ollama version.

## Rules

- Keep `qwen3:8b` as the safe production default until benchmarks prove another model is better.
- Explicit report model choices must hard-fail if missing; do not silently fallback.
- Pull one model at a time, run `ollama list`, then benchmark one AM report and one client report before promoting to DOPE UI.
- Stop pulls if disk or memory pressure becomes unsafe.
