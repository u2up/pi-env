#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
cd "$repo_root"

# shellcheck source=tests/lib/test-helpers.sh
. "$repo_root/tests/lib/test-helpers.sh"

# User-facing startup guidance must name pienv as the canonical agent
# namespace, while retaining existing entrypoints as compatibility behavior
# sources. pi-start may only appear in explicit removal/migration tests and
# requirements notes.
test_grep '^pienv help$' README.md
test_grep '^pienv completion bash$' README.md
test_grep '^pienv sandbox --help$' README.md
test_grep '^pienv$' README.md
test_grep 'pienv raw -- --model' README.md
test_grep '`pienv shell` owns runtime selection' README.md
test_grep 'sandbox layer instead of using the default startup policy' README.md
test_grep 'loads the Nix-packaged role manager by' role-manager/README.md
test_grep 'PI_ENV_ROLE_MANAGER_AUTO=0 pi-env' role-manager/README.md

test_grep 'mkPiEnv' REQUIREMENTS.md
test_grep 'mkPiEnvShell' REQUIREMENTS.md
if grep -F 'mkPiStart' REQUIREMENTS.md .pi-env/coordination/requirements/*.yaml >/dev/null 2>&1; then
  test_fail 'requirements still document mkPiStart'
fi

if grep -RIn --exclude-dir=.git --exclude='PIENV-ISS-20260710-184852-001.sh' \
  -E '(^|[^[:alnum:]_-])pi-start([^[:alnum:]_-]|$)' \
  README.md role-manager designs examples pi-env pi-env-shell scripts/install-non-nix flake.nix tests/*.sh \
  tests/items/issues 2>/dev/null \
  | grep -Ev 'intentionally removes|scripts/install-non-nix:[0-9]+:  pi-start|removed_command_names|command -v pi-start|stale legacy wrapper|stale pi-start wrapper|\[ ! -e .*pi-start|pi-start should not be installed|should be removed|still exposes|still installs|survived reinstall|left stale|pi-start removal tests passed|leaked into pi-core|leaked into pi-runtime|PIENV-ISS-20260710-184849-001' >/tmp/pi-env-stale-pi-start.$$; then
  cat /tmp/pi-env-stale-pi-start.$$ >&2
  rm -f /tmp/pi-env-stale-pi-start.$$
  test_fail 'stale user-facing pi-start guidance remains'
fi
rm -f /tmp/pi-env-stale-pi-start.$$

echo 'PIENV-ISS-20260710-184852-001 documentation pi-start removal tests passed'
