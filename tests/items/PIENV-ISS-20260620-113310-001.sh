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

pi-serial-roles \
  --project-root "$init_project" \
  --agent-id agent-a \
  --sleep 0 \
  --max-idle-polls 1 \
  --dry-run \
  --pi-env true \
  --role-manager "$repo_root/role-manager" >"$tmp/serial.out"
grep -Fx 'selected role=none item=none' "$tmp/serial.out" >/dev/null

mkdir -p "$init_project/.pi-env/coordination/requirements" "$init_project/designs"
cat >"$init_project/.pi-env/coordination/requirements/INIT-FRQ-001.yaml" <<'EOF_REQ'
schema: coordination-item/v1
id: INIT-FRQ-001
type: requirement
status: active
project: init-demo
requirement_key: INIT-001
render_order: 1
body: |-
  # INIT-001 Default coverage smoke
EOF_REQ
cat >"$init_project/designs/default-coverage.md" <<'EOF_DESIGN'
# Default coverage smoke

## Covers

| Requirement | Coordination item |
|-------------|-------------------|
| INIT-001 | INIT-FRQ-001 |
EOF_DESIGN
agent-coord-generate-requirements-coverage \
  --project init-demo \
  --designs-dir "$init_project/designs" \
  --output "$tmp/coverage.md"
grep -F '| INIT-001 | INIT-FRQ-001 |' "$tmp/coverage.md" >/dev/null
agent-coord-generate-requirements \
  --project init-demo \
  --output "$tmp/requirements.md"
grep -F '# INIT-001 Default coverage smoke' "$tmp/requirements.md" >/dev/null

grep -F 'find it at `.pi-env/coordination`' \
  "$repo_root/pi-skill-templates/agent-coordination/SKILL.md" >/dev/null
! grep -F 'Find it at `./coordination`' \
  "$repo_root/pi-skill-templates/agent-coordination/SKILL.md" >/dev/null
! grep -F 'cd coordination && git pull --rebase' \
  "$repo_root/pi-skill-templates/agent-coordination/SKILL.md" >/dev/null
grep -F 'Fresh projects default to' "$repo_root/README.md" >/dev/null
grep -F '.pi-env/coordination' "$repo_root/README.md" >/dev/null

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
