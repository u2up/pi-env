#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd -P)"
cd "$repo_root"
. tests/lib/test-helpers.sh

flake=flake.nix

test_grep 'PI_ENV_ROLE_MANAGER_AUTO' "$flake"
test_grep 'role_manager_args=(-e "$role_manager_package")' "$flake"
test_grep 'PI_ENV_ROLE_MANAGER_PACKAGE:-${roleManagerPackage}' "$flake"
test_grep 'role_manager_args\[@\]' "$flake"
test_grep 'pi-bwrap --tools "$tools" --continue' "$flake"
test_grep 'roleManagerPackage = mkRoleManagerPackage pkgs;' "$flake"

test_grep 'PI_ENV_ROLE_MANAGER_AUTO=0' README.md
test_grep 'loads it by' README.md
test_grep 'PI_ENV_ROLE_MANAGER_AUTO=0' role-manager/README.md

# The startup script should skip absent package paths by checking existence
# before appending Pi's per-run extension/package flag.
test_grep '\[ -e "$role_manager_package" \]' "$flake"

echo "pi-start role-manager default tests passed"
