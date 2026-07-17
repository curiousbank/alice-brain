#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

cat >"${TMP_DIR}/ollama" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  pull)
    printf '%s\n' "${2:?model is required}" >>"${OLLAMA_CALLS_FILE:?}"
    ;;
  list)
    ;;
  *)
    exit 64
    ;;
esac
SH
chmod +x "${TMP_DIR}/ollama"

DEFAULT_CALLS="${TMP_DIR}/default-calls"
OLLAMA_CALLS_FILE="${DEFAULT_CALLS}" \
  PATH="${TMP_DIR}:${PATH}" \
  "${ROOT}/bin/install_baseline_models" >/dev/null

printf '%s\n' "qwen3:8b" >"${TMP_DIR}/expected-default"
cmp "${TMP_DIR}/expected-default" "${DEFAULT_CALLS}"

OPTIONAL_CALLS="${TMP_DIR}/optional-calls"
OLLAMA_CALLS_FILE="${OPTIONAL_CALLS}" \
  PATH="${TMP_DIR}:${PATH}" \
  INSTALL_EMBEDDING_MODEL=1 \
  INSTALL_VISION_MODEL=1 \
  INSTALL_GLM_OCR=1 \
  "${ROOT}/bin/install_baseline_models" >/dev/null

printf '%s\n' \
  "qwen3:8b" \
  "qwen3-embedding:4b" \
  "qwen3-vl:8b" \
  "glm-ocr:bf16" >"${TMP_DIR}/expected-optional"
cmp "${TMP_DIR}/expected-optional" "${OPTIONAL_CALLS}"

echo "baseline model installer tests passed"
