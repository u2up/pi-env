#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
cd "$repo_root"

# shellcheck source=tests/lib/test-helpers.sh
. "$repo_root/tests/lib/test-helpers.sh"

# User docs should present pienv as the canonical namespace while documenting
# the hard rename to pi-env-prefixed lower-level commands. State paths and
# environment variable names are intentionally unchanged.
test_grep '`pienv` is the canonical user-facing command namespace' README.md
test_grep 'The old non-prefixed names' README.md
test_grep 'are intentionally not compatibility entrypoints' README.md
test_grep 'Operational state paths such' README.md
test_grep 'as `.pi-env/` and environment variables such as' README.md

test_grep '^| `pienv coord status \[options\]` | `pi-env-coord-status \[options\]` |$' README.md
test_grep '^| `pienv roles serial \[options\]` | `pi-env-serial-roles \[options\]` |$' README.md
test_grep '^| `pienv install \[options\]` | `pi-env-install-non-nix \[options\]` |$' README.md
test_grep 'pienv completion bash' designs/pienv-command-namespace.md

test_grep '^pienv help$' README.md
test_grep '^pienv help coord$' README.md
test_grep '^pienv help coord status$' README.md
test_grep '^pienv coord status --help$' README.md
test_grep '^pienv completion bash$' README.md
test_grep '^source <(pienv completion bash)$' README.md

test_grep '^pienv -- shell$' README.md
test_grep '^pienv -- coord status$' README.md
test_grep '^pienv sandbox shell -- -l$' README.md

test_grep 'Host runtime is' README.md
test_grep 'unpinned and uses admitted host tools' README.md
test_grep 'Nix runtime is reproducible and pinned' README.md

test_grep '^pienv raw -- --model' README.md
test_grep '^pienv$' README.md
test_grep '^PI_ENV_BWRAP_PROJECT_ROOT=/path/to/repo pienv' README.md
test_grep '^pienv coord bootstrap' README.md
test_grep '^pienv coord init$' README.md
test_grep '^pienv coord clone$' README.md
test_grep '^pienv coord new --repo-id pi-env --type issue --category bug' README.md
test_grep '^pienv coord push -m "Add PIENV documentation item"$' README.md
test_grep '^pienv coord status$' README.md
test_grep '^pienv coord rules upgrade --preview$' README.md
test_grep '^PI_ENV_ROLE_MANAGER_AUTO=0 pienv$' README.md
test_grep '^pienv sandbox install -l "\$PI_ENV_ROLE_MANAGER_PACKAGE"$' README.md
test_grep '^pienv sandbox install -l "\$(readlink -f result)"$' README.md
test_grep '^pienv roles serial --sleep 30$' README.md
test_grep '^pienv roles serial --once$' README.md
test_grep '^pienv roles serial --issue ISSUE-1 --issue ISSUE-2 --max-jobs 2$' README.md

if grep -q '^PI_ENV_BWRAP_[^#]* pi-env\($\|[[:space:]]#\)' README.md; then
  test_fail 'per-project override examples should prefer pienv'
fi
if grep -q '^\(pi-env-bootstrap-coordination\|pi-env-coord-init\|pi-env-coord-clone\|pi-env-coord-new\|pi-env-coord-push\|pi-env-coord-list\|pi-env-coord-upgrade-rules\)' README.md; then
  test_fail 'coordination setup examples should prefer pienv coord commands'
fi
if grep -q '^PI_ENV_ROLE_MANAGER_AUTO=0 pi-env\($\|[[:space:]]\)' README.md; then
  test_fail 'role-manager opt-out examples should prefer pienv'
fi
if grep -q '^pi-env-bwrap install ' README.md; then
  test_fail 'role-manager install examples should prefer pienv sandbox'
fi
if grep -q '^pi-env-serial-roles\($\|[[:space:]]\)' README.md; then
  test_fail 'serial role examples should prefer pienv roles serial'
fi

echo 'PIENV-ISS-20260711-092200-004 pienv documentation tests passed'
