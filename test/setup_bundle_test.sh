#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../bin/pinball_oven_setup
source "${ROOT_DIR}/bin/pinball_oven_setup"

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/alice-brain-test.XXXXXX")"
trap 'rm -rf "${tmp_dir}"' EXIT

bundle="${tmp_dir}/bundle.env"
sanitized="${tmp_dir}/sanitized.env"
cat >"${bundle}" <<'EOF'
# Safety note: no wallet private keys belong here.
ALICE_NODE_ID=test-oven
MAZA_ADDRESS=publicaddress
AUTOS_WORKER_BASE_URL=https://313.cash
AUTOS_WORKER_TOKEN=scoped-token
AUTOS_LOCAL_MODEL=qwen3:8b
PRIVATE_REPORT_EMBEDDER_MODEL=qwen3-embedding:4b
EOF

bundle_has_safe_syntax "${bundle}"
bundle_has_required_values "${bundle}"
! secret_like_content "${bundle}"
write_sanitized_bundle "${bundle}" "${sanitized}"
grep -q '^ALICE_NODE_ID=test-oven$' "${sanitized}"
grep -q '^AUTOS_WORKER_TOKEN=scoped-token$' "${sanitized}"
! grep -q 'PRIVATE_REPORT' "${sanitized}"

malicious="${tmp_dir}/malicious.env"
printf '%s\n' 'ALICE_NODE_ID=$(touch /tmp/unsafe-alice-test)' >"${malicious}"
if bundle_has_safe_syntax "${malicious}"; then
  echo "malicious setup bundle was accepted" >&2
  exit 1
fi

echo "setup bundle tests passed"
