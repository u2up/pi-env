#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
cd "$repo_root"
. tests/lib/test-helpers.sh

# Keep these checks tied to the issue acceptance criteria instead of exact
# README section titles. The onboarding flow has been reorganized over time, but
# it must still document both direct and project-integrated workflows.
test_grep 'Direct use' README.md
test_grep '/pienv "Inspect this repo"' README.md
test_grep 'pienv raw -- --model' README.md
test_grep 'Flake integration' README.md
test_grep 'pin pi-env' README.md
test_grep 'project-specific Nix dependencies' README.md
test_grep '^nix develop$' README.md
test_grep '^pienv$' README.md
test_grep 'Use direct mode' README.md
test_grep 'Use project-integrated mode' README.md
test_grep 'mounted at `/workspace`' README.md
test_grep 'PI_ENV_ROLE_MANAGER_AUTO=0' README.md
test_grep 'loads the Nix-packaged role manager by' role-manager/README.md
test_grep 'PI_ENV_ROLE_MANAGER_AUTO=0' role-manager/README.md
if grep -q 'not enabled by default\|disabled by default' README.md role-manager/README.md; then
  test_fail 'role-manager docs still claim default loading is disabled'
fi

echo "getting started documentation tests passed"
