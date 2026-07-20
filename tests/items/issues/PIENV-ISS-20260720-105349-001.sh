#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
cd "$repo_root"

# shellcheck source=../../lib/test-helpers.sh
source tests/lib/test-helpers.sh

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

bash scripts/pienv --help >"$tmpdir/help.out"

test_grep 'pienv \[launcher options\] \[pi args\.\.\.\]' "$tmpdir/help.out"
test_grep 'pienv run \[launcher options\] \[pi args\.\.\.\]' "$tmpdir/help.out"
test_grep 'pienv \[launcher options\] --raw -- \[pi args\.\.\.\]' "$tmpdir/help.out"
test_grep 'pienv raw -- \[pi args\.\.\.\]' "$tmpdir/help.out"
test_grep 'pienv shell \[launcher options\] \[shell args\.\.\.\]' "$tmpdir/help.out"
test_grep '--runtime host|nix|auto' "$tmpdir/help.out"
test_grep '--flake REF' "$tmpdir/help.out"
test_grep '--devshell NAME' "$tmpdir/help.out"
test_grep 'PI_ENV_RUNTIME' "$tmpdir/help.out"
test_grep 'PI_ENV_FLAKE' "$tmpdir/help.out"
test_grep 'PI_ENV_NIX_DEVSHELL' "$tmpdir/help.out"
test_grep 'CLI options win over environment values' "$tmpdir/help.out"
test_grep 'Coordination,' "$tmpdir/help.out"
test_grep 'recipe, install, uninstall, and sandbox commands have separate option sets' "$tmpdir/help.out"

bash scripts/pienv completion bash >"$tmpdir/completion.bash"
bash -n "$tmpdir/completion.bash"

cat >>"$tmpdir/completion-check.sh" <<'CHECK'
source "$1"
assert_completion() {
  local expected="$1"
  shift
  COMP_WORDS=(pienv "$@")
  COMP_CWORD=$((${#COMP_WORDS[@]} - 1))
  _pienv
  case " ${COMPREPLY[*]} " in
    *" $expected "*) ;;
    *) printf 'missing completion %s for pienv %s; got: %s\n' "$expected" "$*" "${COMPREPLY[*]}" >&2; exit 1 ;;
  esac
}
assert_no_completion() {
  local unexpected="$1"
  shift
  COMP_WORDS=(pienv "$@")
  COMP_CWORD=$((${#COMP_WORDS[@]} - 1))
  _pienv
  case " ${COMPREPLY[*]} " in
    *" $unexpected "*) printf 'unexpected completion %s for pienv %s; got: %s\n' "$unexpected" "$*" "${COMPREPLY[*]}" >&2; exit 1 ;;
  esac
}
assert_completion --runtime --
assert_completion --runtime run --
assert_completion --runtime shell --
assert_completion --flake run --
assert_completion --devshell shell --
assert_no_completion --runtime raw --
assert_no_completion --flake raw --
assert_no_completion auto raw --runtime a
assert_no_completion --runtime coord --
assert_no_completion --runtime sandbox --
assert_no_completion --runtime recipe --
assert_no_completion auto coord --runtime a
CHECK
bash "$tmpdir/completion-check.sh" "$tmpdir/completion.bash"

mkdir -p "$tmpdir/bin" "$tmpdir/support"
cp scripts/pienv "$tmpdir/support/pienv"
chmod +x "$tmpdir/support/pienv"
cat >"$tmpdir/bin/pi-env" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
for arg in "$@"; do
  printf 'arg=%s\n' "$arg"
done >"$PIENV_RAW_CAPTURE"
STUB
chmod +x "$tmpdir/bin/pi-env"
PIENV_RAW_CAPTURE="$tmpdir/raw.args" PATH="$tmpdir/bin:$PATH" \
  "$tmpdir/support/pienv" raw --runtime host -- foo
printf '%s\n' \
  'arg=--raw' \
  'arg=--runtime' \
  'arg=host' \
  'arg=--' \
  'arg=foo' >"$tmpdir/expected-raw.args"
test_eq "$(cat "$tmpdir/expected-raw.args")" "$(cat "$tmpdir/raw.args")" \
  'pienv raw must remain thin pi-env --raw parity dispatcher'

PIENV_RAW_CAPTURE="$tmpdir/raw-launcher.args" PATH="$tmpdir/bin:$PATH" \
  "$tmpdir/support/pienv" --runtime host --raw -- foo
printf '%s\n' \
  'arg=--runtime' \
  'arg=host' \
  'arg=--raw' \
  'arg=--' \
  'arg=foo' >"$tmpdir/expected-raw-launcher.args"
test_eq "$(cat "$tmpdir/expected-raw-launcher.args")" "$(cat "$tmpdir/raw-launcher.args")" \
  'top-level raw launcher options must remain available before --raw'

test_note 'PIENV-ISS-20260720-105349 top-level help, completion, and raw parity are covered'
