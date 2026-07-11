#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
cd "$repo_root"

fake_root="$(mktemp -d)"
trap 'rm -rf "$fake_root"' EXIT
mkdir -p "$fake_root/bin" "$fake_root/host-tools" "$fake_root/state"

cat >"$fake_root/fake-bwrap" <<'FAKE_BWRAP'
#!/usr/bin/env bash
: "${PI_ENV_TEST_BWRAP_TRACE:?}"
printf '%s\n' "$@" >"$PI_ENV_TEST_BWRAP_TRACE"
FAKE_BWRAP
chmod +x "$fake_root/fake-bwrap"
: >"$fake_root/host-tools/bash"
: >"$fake_root/host-tools/env"
chmod +x "$fake_root/host-tools/bash" "$fake_root/host-tools/env"

run_host_shell() {
  PI_ENV_RUNTIME_PATH=/nix/store/fake/bin \
  PI_ENV_BWRAP_BWRAP="$fake_root/fake-bwrap" \
  PI_ENV_BWRAP_BASH="$fake_root/host-tools/bash" \
  PI_ENV_BWRAP_ENV="$fake_root/host-tools/env" \
  PI_ENV_BWRAP_STATE_DIR="$fake_root/state" \
  PI_ENV_BWRAP_EPHEMERAL_HOME=1 \
  PI_ENV_BWRAP_IMPORT_COMMON=0 \
  PI_ENV_BWRAP_IMPORT_EXTENSIONS=0 \
  PI_ENV_BWRAP_IMPORT_GIT_CONFIG=0 \
  PI_ENV_BWRAP_IMPORT_AUTH=0 \
  PI_ENV_BWRAP_IMPORT_SESSIONS=0 \
  PI_ENV_TEST_BWRAP_TRACE="$fake_root/host.trace" \
  ./pi-env-shell --runtime host -- -lc 'printf host-shell' >/dev/null
}

run_host_shell
if grep -qx -- '--tools' "$fake_root/host.trace" || grep -qx -- '--continue' "$fake_root/host.trace"; then
  echo "pi-env-shell --runtime host must delegate to pi-env-bwrap shell mode" >&2
  exit 1
fi
tail -n 2 "$fake_root/host.trace" | grep -Fx -- '-lc' >/dev/null
tail -n 1 "$fake_root/host.trace" | grep -Fx -- 'printf host-shell' >/dev/null

cat >"$fake_root/fake-pi-env-bwrap" <<'FAKE_PI_ENV_BWRAP'
#!/usr/bin/env bash
: "${PI_ENV_TEST_LAUNCHER_TRACE:?}"
printf 'pi-env-bwrap\n' >"$PI_ENV_TEST_LAUNCHER_TRACE"
printf '%s\n' "$@" >>"$PI_ENV_TEST_LAUNCHER_TRACE"
FAKE_PI_ENV_BWRAP
chmod +x "$fake_root/fake-pi-env-bwrap"

PI_ENV_PI_ENV_BWRAP="$fake_root/fake-pi-env-bwrap" \
PI_ENV_TEST_LAUNCHER_TRACE="$fake_root/wired-nix.trace" \
./pi-env-shell --runtime nix -- -lc 'printf nix-shell'
mapfile -t wired_nix <"$fake_root/wired-nix.trace"
[ "${wired_nix[0]}" = "pi-env-bwrap" ]
[ "${wired_nix[1]}" = "--shell" ]
[ "${wired_nix[2]}" = "--" ]
[ "${wired_nix[3]}" = "-lc" ]
[ "${wired_nix[4]}" = "printf nix-shell" ]

PATH="$fake_root:$PATH" \
PI_ENV_PI_ENV_BWRAP="$fake_root/fake-pi-env-bwrap" \
PI_ENV_TEST_LAUNCHER_TRACE="$fake_root/auto.trace" \
./pi-env-shell --runtime auto -- -i
mapfile -t auto_trace <"$fake_root/auto.trace"
[ "${auto_trace[0]}" = "pi-env-bwrap" ]
[ "${auto_trace[1]}" = "--shell" ]
[ "${auto_trace[2]}" = "--" ]
[ "${auto_trace[3]}" = "-i" ]

cat >"$fake_root/bin/nix" <<'FAKE_NIX'
#!/usr/bin/env bash
: "${PI_ENV_TEST_NIX_TRACE:?}"
printf 'PI_ENV_RUNTIME=%s\n' "${PI_ENV_RUNTIME-}" >"$PI_ENV_TEST_NIX_TRACE"
printf '%s\n' "$@" >>"$PI_ENV_TEST_NIX_TRACE"
FAKE_NIX
chmod +x "$fake_root/bin/nix"

env -u PI_ENV_PI_START -u PI_ENV_PI_ENV_BWRAP \
PATH="$fake_root/bin:$PATH" \
PI_ENV_RUNTIME=host \
PI_ENV_TEST_NIX_TRACE="$fake_root/nix-recurse.trace" \
./pi-env-shell --runtime nix --flake "$fake_root/flake-ref" -- -lc 'printf recurse'
mapfile -t nix_recurse <"$fake_root/nix-recurse.trace"
[ "${nix_recurse[0]}" = "PI_ENV_RUNTIME=nix" ]
[ "${nix_recurse[1]}" = "develop" ]
[ "${nix_recurse[2]}" = "$fake_root/flake-ref" ]
[ "${nix_recurse[3]}" = "-c" ]
[ "${nix_recurse[4]}" = "pi-env-shell" ]
[ "${nix_recurse[5]}" = "-lc" ]
[ "${nix_recurse[6]}" = "printf recurse" ]

REPO_ROOT="$repo_root" node --input-type=module <<'NODE'
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const root = process.env.REPO_ROOT;
const flake = readFileSync(join(root, "flake.nix"), "utf8");
const install = readFileSync(join(root, "scripts/pi-env-install-non-nix"), "utf8");
assert.match(flake, /pi-env-shell = piEnvShell;/);
assert.match(flake, /program = "\$\{piEnvShell\}\/bin\/pi-env-shell";/);
assert.match(flake, /command -v pi-env-shell >\/dev\/null/);
assert.match(install, /pi-env-shell/);
assert.match(install, /pi-env\|pi-env-shell\) install_wrapper "\$name" pi-env-launcher ;;/);
NODE
