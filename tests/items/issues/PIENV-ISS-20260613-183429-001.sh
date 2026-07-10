#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
cd "$repo_root"
. tests/lib/test-helpers.sh

test_file_exists pi-env
test_grep "pi-env - run Pi through the pi-env launcher" <("./pi-env" --help)

set +e
missing_flake_output="$("$repo_root/pi-env" --flake 2>&1)"
missing_flake_status=$?
set -e
test_eq 2 "$missing_flake_status" 'pi-env --flake without an argument exits with usage error'
test_grep 'pi-env: --flake requires an argument' <(printf '%s\n' "$missing_flake_output")

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
fakebin="$tmpdir/bin"
mkdir -p "$fakebin" "$tmpdir/project"
cat >"$fakebin/pi-bwrap" <<'FAKE'
#!/usr/bin/env bash
{
  printf 'pi-bwrap\n'
  pwd
  printf '<%s>\n' "$@"
} >"$PI_ENV_CAPTURE"
FAKE
cat >"$fakebin/nix" <<'FAKE'
#!/usr/bin/env bash
{
  printf 'nix\n'
  printf '<%s>\n' "$@"
} >"$PI_ENV_CAPTURE"
FAKE
chmod +x "$fakebin"/*

capture="$tmpdir/capture"
(
  cd "$tmpdir/project"
  PI_ENV_CAPTURE="$capture" PATH="$fakebin:$PATH" PI_ENV_RUNTIME=auto \
    "$repo_root/pi-env" "hello prompt"
)
test_grep '^pi-bwrap$' "$capture"
test_grep "^$tmpdir/project$" "$capture"
test_grep '^<--tools>$' "$capture"
test_grep '^<read,bash,edit,write,grep,find,ls>$' "$capture"
test_grep '^<--continue>$' "$capture"
test_grep '^<-e>$' "$capture"
test_grep "^<$repo_root/role-manager>$" "$capture"
test_grep '^<hello prompt>$' "$capture"

(
  cd "$tmpdir/project"
  PI_ENV_CAPTURE="$capture" PATH="$fakebin:$PATH" PI_ENV_RUNTIME=auto \
    "$repo_root/pi-env" --raw -- --model example/model "prompt"
)
test_grep '^pi-bwrap$' "$capture"
test_grep '^<-->$' "$capture"
test_grep '^<--model>$' "$capture"
test_grep '^<example/model>$' "$capture"
test_grep '^<prompt>$' "$capture"

rm "$fakebin/pi-bwrap"
PI_ENV_CAPTURE="$capture" PATH="$fakebin:$PATH" PI_ENV_RUNTIME=nix \
  PI_ENV_FLAKE=env-flake "$repo_root/pi-env" "env prompt"
test_grep '^nix$' "$capture"
test_grep '^<develop>$' "$capture"
test_grep '^<env-flake>$' "$capture"
test_grep '^<-c>$' "$capture"
test_grep '^<pi-env>$' "$capture"
test_grep '^<env prompt>$' "$capture"

PI_ENV_CAPTURE="$capture" PATH="$fakebin:$PATH" PI_ENV_RUNTIME=nix \
  PI_ENV_FLAKE=env-flake "$repo_root/pi-env" --flake cli-flake "prompt"
test_grep '^nix$' "$capture"
test_grep '^<develop>$' "$capture"
test_grep '^<cli-flake>$' "$capture"
test_grep '^<-c>$' "$capture"
test_grep '^<pi-env>$' "$capture"
test_grep '^<prompt>$' "$capture"

test_grep 'mkPiEnv' flake.nix
test_grep 'pi-env = piEnv' flake.nix
test_grep 'program = "${piEnv}/bin/pi-env"' flake.nix
test_grep 'piEnv' flake.nix

echo "pi-env launcher tests passed"
