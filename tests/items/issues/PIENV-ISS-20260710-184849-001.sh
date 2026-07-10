#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
cd "$repo_root"
. tests/lib/test-helpers.sh

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

[ ! -e scripts/pi-start ] || test_fail 'scripts/pi-start should be removed'
test_grep 'pi-env = piEnv;' flake.nix
test_grep 'pi-env-shell = piEnvShell;' flake.nix
if grep -Eq 'mkPiStart|PI_ENV_PI_START|pi-start = piStart|program = "\$\{piStart\}/bin/pi-start"' flake.nix; then
  test_fail 'flake still exposes pi-start wiring'
fi
if grep -Eq '(^|[[:space:]])pi-start($|[[:space:]])|PI_ENV_PI_START' scripts/install-non-nix; then
  test_fail 'non-Nix installer still installs pi-start'
fi

fake_bwrap="$tmpdir/pi-bwrap"
cat >"$fake_bwrap" <<'FAKE_BWRAP'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$PI_ENV_TEST_CAPTURE"
FAKE_BWRAP
chmod +x "$fake_bwrap"

capture="$tmpdir/default.args"
PI_ENV_RUNTIME=auto \
PI_ENV_PI_ENV_BWRAP="$fake_bwrap" \
PI_ENV_TEST_CAPTURE="$capture" \
./pi-env --model test/model 'hello world'

test_grep '^--tools$' "$capture"
test_grep '^read,bash,edit,write,grep,find,ls$' "$capture"
test_grep '^--continue$' "$capture"
test_grep '^-e$' "$capture"
test_grep "^$repo_root/role-manager$" "$capture"
test_grep '^--model$' "$capture"
test_grep '^test/model$' "$capture"
test_grep '^hello world$' "$capture"

custom_capture="$tmpdir/custom.args"
PI_ENV_RUNTIME=auto \
PI_ENV_PI_ENV_BWRAP="$fake_bwrap" \
PI_ENV_BWRAP_DEFAULT_TOOLS='bash,grep' \
PI_ENV_ROLE_MANAGER_AUTO=0 \
PI_ENV_TEST_CAPTURE="$custom_capture" \
./pi-env 'prompt'
test_grep '^bash,grep$' "$custom_capture"
if grep -Fx -- '-e' "$custom_capture" >/dev/null 2>&1; then
  test_fail 'PI_ENV_ROLE_MANAGER_AUTO=0 should disable role-manager injection'
fi

raw_capture="$tmpdir/raw.args"
PI_ENV_RUNTIME=auto \
PI_ENV_PI_ENV_BWRAP="$fake_bwrap" \
PI_ENV_TEST_CAPTURE="$raw_capture" \
./pi-env --raw -- --model raw/model prompt
if grep -Fx -- '--tools' "$raw_capture" >/dev/null 2>&1 || grep -Fx -- '--continue' "$raw_capture" >/dev/null 2>&1; then
  test_fail 'raw mode should not inject default startup arguments'
fi
test_grep '^--$' "$raw_capture"
test_grep '^--model$' "$raw_capture"
test_grep '^raw/model$' "$raw_capture"

shell_capture="$tmpdir/shell.args"
PI_ENV_RUNTIME=auto \
PI_ENV_PI_ENV_BWRAP="$fake_bwrap" \
PI_ENV_TEST_CAPTURE="$shell_capture" \
./pi-env-shell -- -lc true
if grep -Fx -- '--tools' "$shell_capture" >/dev/null 2>&1 || grep -Fx -- '--continue' "$shell_capture" >/dev/null 2>&1; then
  test_fail 'pi-env-shell should delegate to shell mode without startup defaults'
fi
test_grep '^--shell$' "$shell_capture"
test_grep '^--$' "$shell_capture"
test_grep '^-lc$' "$shell_capture"

echo 'PIENV-ISS-20260710-184849-001 pi-start removal tests passed'
