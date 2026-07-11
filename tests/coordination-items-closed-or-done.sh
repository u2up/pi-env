#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
export PI_ENV_COORD_LIB="$repo_root/scripts/pi-env-coord-lib.sh"
export PATH="$repo_root/scripts:$PATH"

coord_dir="$repo_root/.pi-env/coordination"
if [ ! -d "$coord_dir" ]; then
  coord_dir="$repo_root/coordination"
fi

pi-env-coord-lint \
  --coord-dir "$coord_dir" \
  --project-root "$repo_root" \
  --require-done-or-closed
