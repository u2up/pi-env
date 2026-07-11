#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
cd "$repo_root"

# shellcheck source=tests/lib/test-helpers.sh
. "$repo_root/tests/lib/test-helpers.sh"

# User docs should present pienv as the canonical namespace while retaining
# compatibility language for the existing commands and state/environment names.
test_grep '`pienv` is the canonical user-facing command namespace' README.md
test_grep 'does not deprecate, warn on, hide, or remove `pi-env`' README.md
test_grep 'Operational state paths such as `.pi-env/`' README.md
test_grep 'environment variables such as' README.md

test_grep '^| `pienv coord status \[options\]` | `agent-coord-status \[options\]` |$' README.md
test_grep '^| `pienv roles serial \[options\]` | `pi-serial-roles \[options\]` |$' README.md
test_grep '^| `pienv install \[options\]` | `install-non-nix \[options\]` |$' README.md
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

if grep -q '^PI_ENV_BWRAP_[^#]* pi-env\($\|[[:space:]]#\)' README.md; then
  test_fail 'per-project override examples should prefer pienv'
fi
if grep -q '^\(bootstrap-coordination\|agent-coord-init\|agent-coord-clone\|agent-coord-new\|agent-coord-push\|agent-coord-list\|agent-coord-upgrade-rules\)' README.md; then
  test_fail 'coordination setup examples should prefer pienv coord commands'
fi

echo 'PIENV-ISS-20260711-092200-004 pienv documentation tests passed'
