#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
export PI_ENV_COORD_LIB="$repo_root/scripts/agent-coord-lib.sh"
export PI_ENV_COORD_TEMPLATE_DIR="$repo_root/pi-skill-templates/agent-coordination"
export PATH="$repo_root/scripts:$PATH"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export HOME="$tmp/home"
mkdir -p "$HOME"
git config --global user.name "Coordination Test"
git config --global user.email "coordination-test@example.invalid"
unset PI_COORD_ROOT PI_COORD_WORKSPACE PI_COORD_DIR PI_COORD_AGENT_ID \
  PI_COORD_PROJECT PI_COORD_PROJECT_KEY PI_COORD_ROLE PI_COORD_REMOTE_URL

print_project="$tmp/print-project"
mkdir -p "$print_project"
git -C "$print_project" init -q
bootstrap-coordination \
  --project-root "$print_project" \
  --project print-demo \
  --project-key PRINT \
  --agent-id agent-a \
  --print-only >"$tmp/print-plan.txt"
grep -F "Root:         $print_project/.pi-env/agent-remotes" \
  "$tmp/print-plan.txt" >/dev/null
grep -F "Clone dir:    $print_project/.pi-env/coordination" \
  "$tmp/print-plan.txt" >/dev/null
test ! -e "$print_project/.pi-env"

init_project="$tmp/init-project"
mkdir -p "$init_project"
git -C "$init_project" init -q
cd "$init_project"
agent-coord-init \
  --project init-demo \
  --project-key INIT \
  --agent-id agent-a >/dev/null

test -d "$init_project/.pi-env/agent-remotes/init-demo-coordination.git"
test -f "$init_project/.pi-env/coordination/AGENTS.md"
grep -Fx '/.pi-env/' "$init_project/.git/info/exclude" >/dev/null

clone_project="$tmp/clone-project"
mkdir -p "$clone_project"
git -C "$clone_project" init -q
cd "$clone_project"
agent-coord-clone \
  --remote "$init_project/.pi-env/agent-remotes/init-demo-coordination.git" >/dev/null

test -f "$clone_project/.pi-env/coordination/AGENTS.md"
grep -Fx '/.pi-env/' "$clone_project/.git/info/exclude" >/dev/null

legacy_project="$tmp/legacy-project"
mkdir -p "$legacy_project/agent-remotes" "$legacy_project/coordination"
git -C "$legacy_project" init -q
legacy_root="$(cd "$legacy_project" && . "$PI_ENV_COORD_LIB" && coord_default_root)"
legacy_dir="$(cd "$legacy_project" && . "$PI_ENV_COORD_LIB" && coord_default_dir)"
test "$legacy_root" = "$legacy_project/agent-remotes"
test "$legacy_dir" = "$legacy_project/coordination"

printf 'PIENV-ISS-20260620-113310-001 passed\n'
