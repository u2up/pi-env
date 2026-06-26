#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
cd "$repo_root"
. tests/lib/test-helpers.sh

flake=flake.nix
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

script="$tmpdir/pi-bwrap"
awk '
  /pkgs\.writeShellScriptBin "pi-bwrap"/ { in_script = 1; next }
  in_script && index($0, sprintf("        %c%c;", 39, 39)) == 1 { exit }
  in_script {
    sub(/^          /, "")
    gsub(/\047\047\$\{/, "${")
    gsub(/\$\{runtimePath\}/, "/tmp/pi-env-runtime/bin")
    gsub(/\$\{defaultTools\}/, "read,bash,edit,write,grep,find,ls")
    gsub(/\$\{pkgs\.[^}]*\}/, "/nix/store/pi-env-test")
    gsub(/exec \/nix\/store\/pi-env-test\/bin\/bwrap/, "exec \"$PI_ENV_TEST_FAKE_BWRAP\"")
    print
  }
' "$flake" >"$script"
chmod +x "$script"

fixed_grep() {
  local needle path
  needle="$1"
  path="$2"
  grep -Fq -- "$needle" "$path" || test_fail "expected $path to contain: $needle"
}

assert_no_line() {
  local line path
  line="$1"
  path="$2"
  if grep -Fxq -- "$line" "$path"; then
    test_fail "expected $path not to contain exact line: $line"
  fi
}

assert_setenv() {
  local path name value
  path="$1"
  name="$2"
  value="$3"
  awk -v name="$name" -v value="$value" '
    prev2 == "--setenv" && prev1 == name && $0 == value { found = 1 }
    { prev2 = prev1; prev1 = $0 }
    END { exit(found ? 0 : 1) }
  ' "$path" || test_fail "expected $path to set $name=$value"
}

assert_bind() {
  local path source target
  path="$1"
  source="$2"
  target="$3"
  awk -v source="$source" -v target="$target" '
    prev2 == "--bind" && prev1 == source && $0 == target { found = 1 }
    { prev2 = prev1; prev1 = $0 }
    END { exit(found ? 0 : 1) }
  ' "$path" || test_fail "expected $path to bind $source at $target"
}

project_hash() {
  printf '%s' "$(realpath -m "$1")" | sha256sum | awk '{print $1}' | cut -c1-16
}

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
  local project capture cwd
  project="$1"
  capture="$2"
  cwd="$3"
  shift 3
  mkdir -p "$project" "$cwd"
  (
    cd "$cwd"
    unset PI_COORD_ROOT PI_COORD_REMOTE_URL PI_COORD_DIR \
      PI_BWRAP_COORDINATION_DIR PI_BWRAP_STATE_DIR
    env \
      HOME="$tmpdir/home" \
      XDG_STATE_HOME="$tmpdir/xdg-state" \
      PATH="$fakebin:$PATH" \
      PI_ENV_TEST_FAKE_BWRAP="$tmpdir/fake-bwrap" \
      PI_ENV_TEST_CAPTURE="$capture" \
      PI_BWRAP_PROJECT_ROOT="$project" \
      PI_BWRAP_IMPORT_COMMON=0 \
      PI_BWRAP_IMPORT_EXTENSIONS=0 \
      PI_BWRAP_IMPORT_GIT_CONFIG=0 \
      PI_BWRAP_IMPORT_AUTH=0 \
      PI_BWRAP_IMPORT_SESSIONS=0 \
      "$@" "$script" -- --version
  )
}

fixed_grep 'Use $PWD/.pi-env/state only as explicit project-local opt-in' "$script"
fixed_grep 'PI_BWRAP_STATE_DIR=$PWD/.pi-env/state' README.md
fixed_grep 'PI_COORD_ROOT=.pi-env/agent-remotes' "$script"

prefer_project="$tmpdir/prefer-project"
mkdir -p \
  "$prefer_project/.pi-env/coordination/.git" \
  "$prefer_project/coordination/.git"
touch \
  "$prefer_project/.pi-env/coordination/AGENTS.md" \
  "$prefer_project/coordination/AGENTS.md"
prefer_capture="$tmpdir/prefer-capture"
run_harness "$prefer_project" "$prefer_capture" "$prefer_project"
assert_setenv "$prefer_capture" PI_COORD_DIR /workspace/.pi-env/coordination
assert_no_line /workspace/coordination "$prefer_capture"

local_project="$tmpdir/local-project"
mkdir -p "$local_project/.pi-env/agent-remotes" "$local_project/subdir"
local_capture="$tmpdir/local-capture"
run_harness "$local_project" "$local_capture" "$local_project/subdir" \
  PI_COORD_ROOT=.pi-env/agent-remotes \
  PI_BWRAP_STATE_DIR="$tmpdir/local-state"
assert_bind "$local_capture" "$local_project" /workspace
assert_setenv "$local_capture" PI_COORD_ROOT /workspace/.pi-env/agent-remotes
assert_no_line "$local_project/.pi-env/agent-remotes" "$local_capture"
assert_no_line /agent-remotes "$local_capture"

external_project="$tmpdir/external-project"
external_root="$tmpdir/external-remotes"
mkdir -p "$external_root"
external_capture="$tmpdir/external-capture"
run_harness "$external_project" "$external_capture" "$external_project" \
  PI_COORD_ROOT="$external_root"
assert_bind "$external_capture" "$external_root" /agent-remotes
assert_setenv "$external_capture" PI_COORD_ROOT /agent-remotes

legacy_project="$tmpdir/legacy-project"
mkdir -p "$legacy_project/agent-remotes" "$legacy_project/coordination/.git"
touch "$legacy_project/coordination/AGENTS.md"
legacy_capture="$tmpdir/legacy-capture"
run_harness "$legacy_project" "$legacy_capture" "$legacy_project" \
  PI_COORD_ROOT="$legacy_project/agent-remotes"
assert_setenv "$legacy_capture" PI_COORD_ROOT /workspace/agent-remotes
assert_no_line PI_COORD_DIR "$legacy_capture"
assert_no_line /workspace/coordination "$legacy_capture"
assert_no_line "$legacy_project/agent-remotes" "$legacy_capture"

explicit_legacy_coord_capture="$tmpdir/explicit-legacy-coord-capture"
run_harness "$legacy_project" "$explicit_legacy_coord_capture" "$legacy_project" \
  PI_COORD_DIR=coordination
assert_setenv "$explicit_legacy_coord_capture" PI_COORD_DIR /workspace/coordination

workspace_env_capture="$tmpdir/workspace-env-capture"
run_harness "$local_project" "$workspace_env_capture" "$local_project" \
  PI_COORD_WORKSPACE=legacy-workspace
assert_no_line PI_COORD_WORKSPACE "$workspace_env_capture"

if [ -d /workspace/agent-remotes ]; then
  compat_project="$tmpdir/compat-project"
  compat_capture="$tmpdir/compat-capture"
  run_harness "$compat_project" "$compat_capture" "$compat_project"
  assert_no_line /workspace/agent-remotes "$compat_capture"

  modern_project="$tmpdir/modern-project"
  modern_capture="$tmpdir/modern-capture"
  mkdir -p "$modern_project/.pi-env/agent-remotes"
  run_harness "$modern_project" "$modern_capture" "$modern_project"
  assert_no_line /workspace/agent-remotes "$modern_capture"

  modern_coord_project="$tmpdir/modern-coord-project"
  modern_coord_capture="$tmpdir/modern-coord-capture"
  mkdir -p "$modern_coord_project/.pi-env/coordination/.git"
  run_harness "$modern_coord_project" "$modern_coord_capture" "$modern_coord_project"
  assert_no_line /workspace/agent-remotes "$modern_coord_capture"
fi

state_project="$tmpdir/default-state-project"
state_capture="$tmpdir/default-state-capture"
xdg_state="$tmpdir/custom-xdg-state"
run_harness "$state_project" "$state_capture" "$state_project" \
  XDG_STATE_HOME="$xdg_state"
default_state="$xdg_state/pi-env/$(project_hash "$state_project")"
test_dir_exists "$default_state/home/.pi/agent"
assert_bind "$state_capture" "$default_state/home" /home/pi
assert_bind "$state_capture" "$default_state/agent" /home/pi/.pi/agent
assert_no_line "$state_project/.pi-env/state/home" "$state_capture"
[ ! -e "$state_project/.pi-env/state" ] || \
  test_fail "default state unexpectedly used $state_project/.pi-env/state"

fallback_project="$tmpdir/fallback-state-project"
fallback_capture="$tmpdir/fallback-state-capture"
fallback_home="$tmpdir/fallback-home"
run_harness "$fallback_project" "$fallback_capture" "$fallback_project" \
  XDG_STATE_HOME= \
  HOME="$fallback_home"
fallback_state="$fallback_home/.local/state/pi-env/$(project_hash "$fallback_project")"
test_dir_exists "$fallback_state/home/.pi/agent"
assert_bind "$fallback_capture" "$fallback_state/home" /home/pi
assert_no_line "$fallback_project/.pi-env/state/home" "$fallback_capture"

explicit_project="$tmpdir/explicit-state-project"
explicit_capture="$tmpdir/explicit-state-capture"
explicit_state="$explicit_project/.pi-env/state"
run_harness "$explicit_project" "$explicit_capture" "$explicit_project" \
  PI_BWRAP_STATE_DIR="$explicit_state"
test_dir_exists "$explicit_state/home/.pi/agent"
test_dir_exists "$explicit_state/agent/sessions"
assert_bind "$explicit_capture" "$explicit_state/home" /home/pi
assert_bind "$explicit_capture" "$explicit_state/agent" /home/pi/.pi/agent
assert_bind "$explicit_capture" "$explicit_state/cache" /home/pi/.cache

printf 'PIENV-ISS-20260620-113313-001 passed\n'
