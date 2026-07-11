#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

scripts=(
  tests/pi-env-coord-blackbox.sh
  tests/pi-env-coord-concurrency.sh
  tests/pi-env-coord-lint.sh
  tests/pi-env-coord-root-layout.sh
  tests/pi-env-coord-repo.sh
  tests/pi-env-coord-generate-requirements.sh
  tests/pi-env-coord-generate-requirements-coverage.sh
  tests/flake-package-boundary.sh
  tests/design-covers.sh
  tests/pi-env-install-non-nix.sh
  tests/pienv-dispatcher.sh
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
