#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd -P)"
export PI_ENV_COORD_LIB="$repo_root/scripts/agent-coord-lib.sh"
export PATH="$repo_root/scripts:$PATH"

agent-coord-lint \
  --coord-dir "$repo_root/coordination" \
  --project-root "$repo_root" \
  --require-done-or-closed >/dev/null

printf 'PIENV-REQ-20260607-221657-001 passed\n'
