#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
. "$repo_root/tests/lib/test-helpers.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

fakebin="$tmpdir/bin"
install_bin="$tmpdir/install/bin"
project="$tmpdir/project"
mkdir -p "$fakebin" "$install_bin" "$project"
printf '{ outputs = { self }: {}; }\n' >"$project/flake.nix"
cp "$repo_root/scripts/pienv" "$install_bin/pienv"
cp "$repo_root/scripts/pi-env-launcher" "$install_bin/pi-env"
cp "$repo_root/scripts/pi-env-launcher" "$install_bin/pi-env-shell"
chmod +x "$install_bin/pienv" "$install_bin/pi-env" "$install_bin/pi-env-shell"

cat >"$fakebin/nix" <<'FAKE_NIX'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  eval)
    expr="${*: -1}"
    case "$expr" in
      *builtins.hasAttr*)
        if [ "${PI_ENV_TEST_HAS_AGENT:-0}" = "1" ]; then
          printf '1\n'
        else
          printf '0\n'
        fi
        exit 0
        ;;
      *builtins.currentSystem*) printf 'x86_64-linux\n'; exit 0 ;;
    esac
    exit 64
    ;;
  develop)
    {
      printf 'args:\n'
      for arg in "$@"; do
        printf '%s\n' "$arg"
      done
    } >"$PI_ENV_TEST_NIX_LOG"
    if [ "${2:-}" = "$PI_ENV_TEST_PROJECT#agent" ] && [ "${PI_ENV_TEST_FAIL_AGENT:-0}" = "1" ]; then
      echo 'agent shell failed to evaluate' >&2
      exit 42
    fi
    exit 0
    ;;
  *) exit 64 ;;
esac
FAKE_NIX
chmod +x "$fakebin/nix"

assert_develop_ref() {
  local expected_ref="$1"
  local log="$2"
  test_file_exists "$log"
  test_grep '^develop$' "$log"
  test_grep "^$expected_ref$" "$log"
}

agent_log="$tmpdir/agent.log"
(
  cd "$project"
  env -u PI_ENV_RUNTIME -u PI_ENV_FLAKE -u PI_ENV_NIX_DEVSHELL -u PI_ENV_NIX_RUNTIME_READY \
    PATH="$fakebin:$PATH" PI_ENV_TEST_PROJECT="$project" PI_ENV_TEST_HAS_AGENT=1 \
    PI_ENV_TEST_NIX_LOG="$agent_log" \
    "$install_bin/pienv" --runtime nix --raw -- --help
)
assert_develop_ref "$project#agent" "$agent_log"

shell_log="$tmpdir/shell.log"
(
  cd "$project"
  env -u PI_ENV_RUNTIME -u PI_ENV_FLAKE -u PI_ENV_NIX_DEVSHELL -u PI_ENV_NIX_RUNTIME_READY \
    PATH="$fakebin:$PATH" PI_ENV_TEST_PROJECT="$project" PI_ENV_TEST_HAS_AGENT=1 \
    PI_ENV_TEST_NIX_LOG="$shell_log" \
    "$install_bin/pi-env-shell" --runtime nix -- -lc true
)
assert_develop_ref "$project#agent" "$shell_log"
test_grep '^pi-env-shell$' "$shell_log"

fallback_log="$tmpdir/fallback.log"
(
  cd "$project"
  env -u PI_ENV_RUNTIME -u PI_ENV_FLAKE -u PI_ENV_NIX_DEVSHELL -u PI_ENV_NIX_RUNTIME_READY \
    PATH="$fakebin:$PATH" PI_ENV_TEST_PROJECT="$project" PI_ENV_TEST_HAS_AGENT=0 \
    PI_ENV_TEST_NIX_LOG="$fallback_log" \
    "$install_bin/pi-env" --runtime nix --raw -- --help
)
assert_develop_ref "$project" "$fallback_log"

fail_status=0
(
  cd "$project"
  env -u PI_ENV_RUNTIME -u PI_ENV_FLAKE -u PI_ENV_NIX_DEVSHELL -u PI_ENV_NIX_RUNTIME_READY \
    PATH="$fakebin:$PATH" PI_ENV_TEST_PROJECT="$project" PI_ENV_TEST_HAS_AGENT=1 \
    PI_ENV_TEST_FAIL_AGENT=1 PI_ENV_TEST_NIX_LOG="$tmpdir/failing-agent.log" \
    "$install_bin/pi-env" --runtime nix --raw -- --help >"$tmpdir/failing-agent.out" 2>&1
) || fail_status=$?
test_eq 42 "$fail_status" 'auto-discovered failing agent shell must not fall back to default'
assert_develop_ref "$project#agent" "$tmpdir/failing-agent.log"
test_grep 'agent shell failed to evaluate' "$tmpdir/failing-agent.out"

cli_default_log="$tmpdir/cli-default.log"
(
  cd "$project"
  env -u PI_ENV_RUNTIME -u PI_ENV_FLAKE -u PI_ENV_NIX_RUNTIME_READY \
    PATH="$fakebin:$PATH" PI_ENV_NIX_DEVSHELL=agent PI_ENV_TEST_PROJECT="$project" \
    PI_ENV_TEST_HAS_AGENT=1 PI_ENV_TEST_NIX_LOG="$cli_default_log" \
    "$install_bin/pi-env" --runtime nix --devshell default --raw -- --help
)
assert_develop_ref "$project" "$cli_default_log"

cli_precedence_log="$tmpdir/cli-precedence.log"
(
  cd "$project"
  env -u PI_ENV_RUNTIME -u PI_ENV_FLAKE -u PI_ENV_NIX_RUNTIME_READY \
    PATH="$fakebin:$PATH" PI_ENV_NIX_DEVSHELL=agent PI_ENV_TEST_PROJECT="$project" \
    PI_ENV_TEST_HAS_AGENT=1 PI_ENV_TEST_NIX_LOG="$cli_precedence_log" \
    "$install_bin/pi-env" --runtime nix --devshell custom --raw -- --help
)
assert_develop_ref "$project#custom" "$cli_precedence_log"

env_override_log="$tmpdir/env-override.log"
(
  cd "$project"
  env -u PI_ENV_RUNTIME -u PI_ENV_FLAKE -u PI_ENV_NIX_RUNTIME_READY \
    PATH="$fakebin:$PATH" PI_ENV_NIX_DEVSHELL=tools PI_ENV_TEST_PROJECT="$project" \
    PI_ENV_TEST_HAS_AGENT=1 PI_ENV_TEST_NIX_LOG="$env_override_log" \
    "$install_bin/pi-env" --runtime nix --raw -- --help
)
assert_develop_ref "$project#tools" "$env_override_log"

help_output="$($install_bin/pi-env --help)"
case "$help_output" in
  *'--devshell NAME'*'PI_ENV_NIX_DEVSHELL=NAME'*'NAME=default preserves'* ) ;;
  *) echo 'pi-env help did not document Nix devshell selection' >&2; exit 1 ;;
esac

printf 'PIENV-ISS-20260720-094624-001 tests passed\n'
