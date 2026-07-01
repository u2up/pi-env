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

fakebin="$tmpdir/fakebin"
mkdir -p "$fakebin"

cat >"$fakebin/pi" <<'FAKE_PI'
#!/usr/bin/env bash
echo 'fake pi should not run outside bwrap' >&2
exit 99
FAKE_PI
chmod +x "$fakebin/pi"

cat >"$fakebin/bwrap" <<'FAKE_BWRAP'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$PI_ENV_TEST_BWRAP_ARGS"
FAKE_BWRAP
chmod +x "$fakebin/bwrap"

capture="$tmpdir/bwrap-args"
PATH="$fakebin:$PATH" \
  PI_ENV_HOST_RUNTIME=1 \
  PI_ENV_TEST_BWRAP_ARGS="$capture" \
  PI_BWRAP_PROJECT_ROOT="$repo_root" \
  PI_BWRAP_IMPORT_COMMON=0 \
  PI_BWRAP_IMPORT_EXTENSIONS=0 \
  PI_BWRAP_IMPORT_GIT_CONFIG=0 \
  PI_BWRAP_IMPORT_AUTH=0 \
  PI_BWRAP_IMPORT_SESSIONS=0 \
  ./pi-env --raw -- --help

test_file_exists "$capture"

sandbox_path="$(awk 'prev == "--setenv" && $0 == "PATH" { getline; print; exit } { prev = $0 }' "$capture")"
[ -n "$sandbox_path" ] || test_fail 'fake bwrap capture did not include sandbox PATH'
case "$sandbox_path" in
  :*|*::*|*:)
    test_fail "host runtime sandbox PATH contains an empty entry: $sandbox_path"
    ;;
esac

test_grep '^--symlink$' "$capture"
if grep -qx 'bash' "$capture"; then
  test_fail 'host runtime used unresolved bash as a bwrap symlink or exec target'
fi
if ! grep -Eq '^/.*/bash$|^/[^/]*/bash$' "$capture"; then
  test_fail 'host runtime did not pass an absolute bash path to bwrap'
fi
if ! grep -qx -- '--ro-bind-try' "$capture"; then
  test_fail 'host runtime did not add read-only host tool/library binds'
fi

echo 'host runtime launcher fake-bwrap test passed'
