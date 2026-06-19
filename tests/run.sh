#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

scripts=(
  tests/agent-coord-blackbox.sh
  tests/agent-coord-concurrency.sh
  tests/agent-coord-lint.sh
  tests/agent-coord-root-layout.sh
  tests/agent-coord-generate-requirements.sh
  tests/agent-coord-generate-requirements-coverage.sh
  tests/flake-package-boundary.sh
  tests/design-covers.sh
  tests/coordination-items-closed-or-done.sh
  tests/role-manager-package.sh
  tests/role-manager-schema.sh
  tests/role-manager-loader.sh
  tests/role-manager-commands.sh
)

for script in "${scripts[@]}"; do
  printf '==> %s\n' "$script"
  "$script"
done

if [ -d tests/items ]; then
  while IFS= read -r script; do
    [ -n "$script" ] || continue
    printf '==> %s\n' "$script"
    "$script"
  done < <(find tests/items -type f -name '*.sh' | sort)
fi

printf 'all tests passed\n'
