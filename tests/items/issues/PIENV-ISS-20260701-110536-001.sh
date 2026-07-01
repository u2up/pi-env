#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
cd "$repo_root"
. tests/lib/test-helpers.sh

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

original_path="$PATH"
fakebin="$tmpdir/fakebin"
mkdir -p "$fakebin"

cat >"$fakebin/nix" <<'FAKE_NIX'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$PI_ENV_TEST_NIX_ARGS"
FAKE_NIX
chmod +x "$fakebin/nix"

cat >"$fakebin/pi" <<'FAKE_PI'
#!/usr/bin/env bash
exit 0
FAKE_PI
chmod +x "$fakebin/pi"

cat >"$fakebin/bwrap" <<'FAKE_BWRAP'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$PI_ENV_TEST_BWRAP_ARGS"
FAKE_BWRAP
chmod +x "$fakebin/bwrap"

: >"$tmpdir/host-bash"
: >"$tmpdir/host-env"
chmod +x "$tmpdir/host-bash" "$tmpdir/host-env"

host_capture="$tmpdir/default-host-bwrap-args"
nix_capture="$tmpdir/default-host-nix-args"
PATH="$fakebin:$original_path" \
  PI_ENV_TEST_BWRAP_ARGS="$host_capture" \
  PI_ENV_TEST_NIX_ARGS="$nix_capture" \
  PI_BWRAP_BASH="$tmpdir/host-bash" \
  PI_BWRAP_ENV="$tmpdir/host-env" \
  PI_BWRAP_PROJECT_ROOT="$repo_root" \
  PI_BWRAP_IMPORT_COMMON=0 \
  PI_BWRAP_IMPORT_EXTENSIONS=0 \
  PI_BWRAP_IMPORT_GIT_CONFIG=0 \
  PI_BWRAP_IMPORT_AUTH=0 \
  PI_BWRAP_IMPORT_SESSIONS=0 \
  ./pi-env --raw -- --help

test_file_exists "$host_capture"
if [ -e "$nix_capture" ]; then
  test_fail 'direct checkout default runtime invoked nix develop'
fi

explicit_nix_capture="$tmpdir/explicit-nix-args"
PATH="$fakebin:$original_path" \
  PI_ENV_TEST_NIX_ARGS="$explicit_nix_capture" \
  ./pi-env --runtime nix --raw -- --help

test_file_exists "$explicit_nix_capture"
expected_nix="$(printf '%s\n' develop "$repo_root" -c pi-env --raw -- --help)"
actual_nix="$(<"$explicit_nix_capture")"
test_eq "$expected_nix" "$actual_nix" 'explicit --runtime nix did not invoke expected nix develop path'

precedence_capture="$tmpdir/precedence-nix-args"
PATH="$fakebin:$original_path" \
  PI_ENV_RUNTIME=host \
  PI_ENV_TEST_NIX_ARGS="$precedence_capture" \
  ./pi-env --runtime nix --help >/dev/null 2>&1 || true
# --help exits before runtime dispatch, so use a pi arg instead.
PATH="$fakebin:$original_path" \
  PI_ENV_RUNTIME=host \
  PI_ENV_TEST_NIX_ARGS="$precedence_capture" \
  ./pi-env --runtime nix --raw -- --version

test_file_exists "$precedence_capture"

if PI_ENV_RUNTIME=bogus ./pi-env --help >/dev/null 2>&1; then
  : # help is allowed before validating runtime for discoverability
fi
if PI_ENV_RUNTIME=bogus ./pi-env --raw -- --help >/dev/null 2>"$tmpdir/invalid.err"; then
  test_fail 'invalid PI_ENV_RUNTIME was accepted'
fi
test_grep 'invalid PI_ENV_RUNTIME value: bogus' "$tmpdir/invalid.err"

echo 'pi-env runtime mode selection test passed'
