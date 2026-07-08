#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
cd "$repo_root"
. tests/lib/test-helpers.sh

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

script="$tmpdir/pi-bwrap"
cp scripts/pi-bwrap "$script"
chmod +x "$script"
test_grep 'PI_COORD_REMOTE' "$script"
test_grep '/agent-remotes' "$script"

fakebin="$tmpdir/fakebin"
mkdir -p "$fakebin"
cat >"$fakebin/pi" <<'FAKE_PI'
#!/usr/bin/env bash
exit 99
FAKE_PI
chmod +x "$fakebin/pi"

cat >"$tmpdir/fake-bwrap" <<'FAKE_BWRAP'
#!/usr/bin/env bash
set -euo pipefail
: "${PI_ENV_TEST_CAPTURE:?}"
: >"$PI_ENV_TEST_CAPTURE"
while [ "$#" -gt 0 ]; do
  printf '%s\n' "$1" >>"$PI_ENV_TEST_CAPTURE"
  shift
done
FAKE_BWRAP
chmod +x "$tmpdir/fake-bwrap"

run_harness() {
  local project capture
  project="$1"
  capture="$2"
  shift 2
  mkdir -p "$project"
  (
    cd "$project"
    unset PI_COORD_ROOT PI_COORD_REMOTE PI_COORD_REMOTE_URL PI_COORD_DIR
    env \
      PATH="$fakebin:$PATH" \
      PI_ENV_RUNTIME_PATH="$tmpdir/runtime/bin" \
      PI_BWRAP_BWRAP="$tmpdir/fake-bwrap" \
      PI_ENV_TEST_FAKE_BWRAP="$tmpdir/fake-bwrap" \
      PI_ENV_TEST_CAPTURE="$capture" \
      PI_BWRAP_PROJECT_ROOT="$project" \
      PI_BWRAP_STATE_DIR="$tmpdir/state-$(basename "$capture")" \
      PI_BWRAP_IMPORT_COMMON=0 \
      PI_BWRAP_IMPORT_EXTENSIONS=0 \
      PI_BWRAP_IMPORT_GIT_CONFIG=0 \
      PI_BWRAP_IMPORT_AUTH=0 \
      PI_BWRAP_IMPORT_SESSIONS=0 \
      "$@" "$script" -- --version
  )
}

assert_no_grep() {
  local pattern path
  pattern="$1"
  path="$2"
  if grep -q -- "$pattern" "$path"; then
    test_fail "expected $path not to match: $pattern"
  fi
}

project_local="$tmpdir/project-local"
mkdir -p "$project_local/.pi-env/agent-remotes"
local_capture="$tmpdir/local-capture"
run_harness "$project_local" "$local_capture" \
  PI_COORD_ROOT=.pi-env/agent-remotes

test_grep '^--bind$' "$local_capture"
test_grep "^$project_local$" "$local_capture"
test_grep '^/workspace$' "$local_capture"
test_grep '^PI_COORD_ROOT$' "$local_capture"
test_grep '^/workspace/.pi-env/agent-remotes$' "$local_capture"
assert_no_grep '^/agent-remotes$' "$local_capture"

external_root="$tmpdir/external-remotes"
mkdir -p "$external_root"
external_capture="$tmpdir/external-capture"
run_harness "$tmpdir/external-project" "$external_capture" \
  PI_COORD_ROOT="$external_root"

test_grep '^--dir$' "$external_capture"
test_grep '^/agent-remotes$' "$external_capture"
test_grep "^$external_root$" "$external_capture"
test_grep '^PI_COORD_ROOT$' "$external_capture"
test_grep '^/agent-remotes$' "$external_capture"

remote_capture="$tmpdir/remote-capture"
run_harness "$tmpdir/url-project" "$remote_capture" \
  PI_COORD_REMOTE_URL='https://git.example.invalid/pi-env-coordination.git'

test_grep '^PI_COORD_REMOTE_URL$' "$remote_capture"
test_grep '^https://git.example.invalid/pi-env-coordination.git$' "$remote_capture"
assert_no_grep '^/agent-remotes$' "$remote_capture"
assert_no_grep '^/workspace/agent-remotes$' "$remote_capture"

config_local_project="$tmpdir/config-local-project"
mkdir -p "$config_local_project/.pi-env/agent-remotes"
cat >"$config_local_project/.pi-env-coordination.yaml" <<'YAML'
version: 1
coordination_remote: .pi-env/agent-remotes/config-local-coordination.git
YAML
config_local_capture="$tmpdir/config-local-capture"
run_harness "$config_local_project" "$config_local_capture"
test_grep '^PI_COORD_REMOTE$' "$config_local_capture"
test_grep '^/workspace/.pi-env/agent-remotes/config-local-coordination.git$' "$config_local_capture"

env_remote_parent="$tmpdir/env-remotes"
mkdir -p "$env_remote_parent"
env_remote_capture="$tmpdir/env-remote-capture"
run_harness "$tmpdir/env-remote-project" "$env_remote_capture" \
  PI_COORD_REMOTE="$env_remote_parent/env-coordination.git"
test_grep '^PI_COORD_REMOTE$' "$env_remote_capture"
test_grep '^/agent-remotes/env-coordination.git$' "$env_remote_capture"
test_grep "^$env_remote_parent$" "$env_remote_capture"

config_external_project="$tmpdir/config-external-project"
mkdir -p "$config_external_project" "$tmpdir/config-external-remotes/config-external.git/objects"
cat >"$config_external_project/.pi-env-coordination.yaml" <<YAML
version: 1
coordination_remote: $tmpdir/config-external-remotes/config-external.git
YAML
config_external_capture="$tmpdir/config-external-capture"
run_harness "$config_external_project" "$config_external_capture"
test_grep '^/workspace/.pi-env/agent-remotes$' "$config_external_capture"
test_grep "^$tmpdir/config-external-remotes$" "$config_external_capture"
test_grep '^/workspace/.pi-env/agent-remotes/config-external.git$' "$config_external_capture"

config_external_nonbare_project="$tmpdir/config-external-nonbare-project"
mkdir -p "$config_external_nonbare_project" "$tmpdir/config-external-nonbare-remotes/config-external.git"
cat >"$config_external_nonbare_project/.pi-env-coordination.yaml" <<YAML
version: 1
coordination_remote: $tmpdir/config-external-nonbare-remotes/config-external.git
YAML
config_external_nonbare_capture="$tmpdir/config-external-nonbare-capture"
run_harness "$config_external_nonbare_project" "$config_external_nonbare_capture"
assert_no_grep '^/workspace/.pi-env/agent-remotes$' "$config_external_nonbare_capture"
assert_no_grep "^$tmpdir/config-external-nonbare-remotes$" "$config_external_nonbare_capture"

home_capture="$tmpdir/home-safety-capture"
run_harness "$tmpdir/home-safety-project" "$home_capture" \
  PI_COORD_REMOTE_URL='ssh://git.example.invalid/pi-env.git'
assert_no_grep "^$HOME/.ssh$" "$home_capture"
assert_no_grep '/\.ssh$' "$home_capture"
assert_no_grep 'bind.*\.ssh' "$script"
assert_no_grep 'host_home.*--bind' "$script"

coord_project="$tmpdir/coord-project"
mkdir -p "$coord_project/.pi-env/coordination/.git"
touch "$coord_project/.pi-env/coordination/AGENTS.md"
coord_capture="$tmpdir/coord-capture"
run_harness "$coord_project" "$coord_capture"
test_grep '^PI_COORD_DIR$' "$coord_capture"
test_grep '^/workspace/.pi-env/coordination$' "$coord_capture"

compat_capture="$tmpdir/compat-capture"
run_harness "$tmpdir/compat-project" "$compat_capture"
assert_no_grep '^/workspace/agent-remotes$' "$compat_capture"

modern_coord_project="$tmpdir/modern-coord-project"
mkdir -p "$modern_coord_project/.pi-env/coordination"
modern_coord_capture="$tmpdir/modern-coord-capture"
run_harness "$modern_coord_project" "$modern_coord_capture"
assert_no_grep '^/workspace/agent-remotes$' "$modern_coord_capture"

modern_remotes_project="$tmpdir/modern-remotes-project"
mkdir -p "$modern_remotes_project/.pi-env/agent-remotes"
modern_remotes_capture="$tmpdir/modern-remotes-capture"
run_harness "$modern_remotes_project" "$modern_remotes_capture"
assert_no_grep '^/workspace/agent-remotes$' "$modern_remotes_capture"

legacy_remotes_project="$tmpdir/legacy-remotes-project"
mkdir -p "$legacy_remotes_project/agent-remotes"
legacy_remotes_capture="$tmpdir/legacy-remotes-capture"
run_harness "$legacy_remotes_project" "$legacy_remotes_capture"
assert_no_grep '^/workspace/agent-remotes$' "$legacy_remotes_capture"
assert_no_grep '^PI_COORD_ROOT$' "$legacy_remotes_capture"

echo "simple coordination remote mount tests passed"
