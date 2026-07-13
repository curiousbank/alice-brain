# Alice Brain Model Baseline

This is the default model stack for a secure Alice Brain node.

## Required

```sh
ollama pull qwen3-embedding:4b
ollama pull qwen3:8b
ollama pull qwen3-vl:8b
```

Roles:

- `qwen3-embedding:4b` - local retrieval and context matching.
- `qwen3:8b` - default local writing, answering, repair, and report drafting.
- `qwen3-vl:8b` - visual media scan and finished-page QA.

## Optional OCR

```sh
ollama pull glm-ocr:bf16
```

Use this only when jobs enable explicit OCR extraction. `qwen3-vl:8b` remains the visual inspector.

## Policy

- Keep the default node small enough for a 32 GB Mac or equivalent PC.
- Report the actual model used in every completed manifest.
- Do not silently promote heavy local models into production lanes.
- Let SUN/PB decide which workers are trusted for which job classes.
- Keep OpenAI/frontier fallback as a SUN/PB policy decision, not a node decision.
