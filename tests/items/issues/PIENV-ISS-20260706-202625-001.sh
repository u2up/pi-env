#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
cd "$repo_root"

./pi-env-shell --help | grep -q 'pi-env-shell'
PI_ENV_SHELL_MODE=1 bash scripts/pi-env-launcher --help | grep -q 'pi-env-shell'
bash scripts/pi-bwrap --help | grep -q 'pi-bwrap --shell'

fake_root="$(mktemp -d)"
trap 'rm -rf "$fake_root"' EXIT
cat >"$fake_root/fake-bwrap" <<'FAKE_BWRAP'
#!/usr/bin/env bash
for arg in "$@"; do
  printf '%s\n' "$arg"
done >"$PI_ENV_TEST_BWRAP_TRACE"
FAKE_BWRAP
chmod +x "$fake_root/fake-bwrap"
PI_ENV_RUNTIME_PATH=/nix/store/fake/bin \
PI_ENV_BWRAP_BWRAP="$fake_root/fake-bwrap" \
PI_ENV_BWRAP_STATE_DIR="$fake_root/state" \
PI_ENV_BWRAP_EPHEMERAL_HOME=1 \
PI_ENV_BWRAP_IMPORT_COMMON=0 \
PI_ENV_BWRAP_IMPORT_EXTENSIONS=0 \
PI_ENV_BWRAP_IMPORT_GIT_CONFIG=0 \
PI_ENV_BWRAP_IMPORT_AUTH=0 \
PI_ENV_BWRAP_IMPORT_SESSIONS=0 \
PI_ENV_TEST_BWRAP_TRACE="$fake_root/trace" \
bash scripts/pi-bwrap --shell >/dev/null
if grep -qx -- '--tools' "$fake_root/trace" || grep -qx -- '--continue' "$fake_root/trace"; then
  echo "pi-bwrap --shell without bash args must not use default Pi args" >&2
  exit 1
fi
tail -n 1 "$fake_root/trace" | grep -qx -- '-l'

REPO_ROOT="$repo_root" node --input-type=module <<'NODE'
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const root = process.env.REPO_ROOT;
const readme = readFileSync(join(root, "README.md"), "utf8");
const flake = readFileSync(join(root, "flake.nix"), "utf8");
const coverage = readFileSync(join(root, "REQUIREMENTS_COVERAGE.md"), "utf8");
const requirements = readFileSync(join(root, "REQUIREMENTS.md"), "utf8");

assert.match(readme, /`pi-env-shell` owns runtime selection/);
assert.match(readme, /`pi-bwrap --shell \[--\] \[bash args\.\.\.\]`/);
assert.match(readme, /pi-env-shell --help/);
assert.match(flake, /pi-env-shell = piEnvShell;/);
assert.match(flake, /pi-env-shell --help >\/dev\/null/);
assert.match(requirements, /#### CMD-021 `pi-bwrap` shell mode/);
assert.match(requirements, /#### CMD-022 `pi-env-shell` runtime launcher/);
assert.match(coverage, /\| CMD-021 \| PIENV-FRQ-20260706-202632-001 \| designs\/launcher-layering\.md \|/);
assert.match(coverage, /\| CMD-022 \| PIENV-FRQ-20260706-202634-001 \| designs\/launcher-layering\.md \|/);
NODE
