#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
export PI_ENV_COORD_LIB="$repo_root/scripts/agent-coord-lib.sh"
export PI_ENV_COORD_TEMPLATE_DIR="$repo_root/pi-skill-templates/agent-coordination"
export PATH="$repo_root/scripts:$PATH"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export HOME="$tmp/home"
unset PI_COORD_ROOT PI_COORD_WORKSPACE PI_COORD_DIR PI_COORD_AGENT_ID PI_COORD_PROJECT PI_COORD_PROJECT_KEY
mkdir -p "$HOME" "$tmp/seed"
git config --global user.name "Coordination Test"
git config --global user.email "coordination-test@example.invalid"

cd "$tmp/seed"
agent-coord-init \
  --root "$tmp/remotes" \
  --workspace demo \
  --agent-id seed-agent \
  --project pi-env >/dev/null

item_path="$(agent-coord-new \
  --coord-dir coordination \
  --project pi-env \
  "Exercise concurrent claim handling" | tail -n 1)"
item_id="$(grep '^id: ' "coordination/$item_path" | sed 's/^id: //')"
agent-coord-push \
  --coord-dir coordination \
  -m "Add concurrent claim test item" >/dev/null

cd "$tmp"
agent-coord-clone \
  --root "$tmp/remotes" \
  --workspace demo \
  --dir agent-a >/dev/null
agent-coord-clone \
  --root "$tmp/remotes" \
  --workspace demo \
  --dir agent-b >/dev/null

agent-coord-claim \
  --coord-dir agent-a \
  --agent-id agent-a \
  "$item_id" >/dev/null

if agent-coord-claim \
  --coord-dir agent-b \
  --agent-id agent-b \
  --no-pull \
  "$item_id" >/dev/null 2>&1; then
  printf 'expected stale push claim to fail\n' >&2
  exit 1
fi

git -C agent-b fetch origin >/dev/null
git -C agent-b reset --hard origin/main >/dev/null

if agent-coord-claim \
  --coord-dir agent-b \
  --agent-id agent-b \
  "$item_id" >/dev/null 2>&1; then
  printf 'expected owned claim to fail\n' >&2
  exit 1
fi

if agent-coord-close \
  --coord-dir agent-b \
  --agent-id agent-b \
  "$item_id" >/dev/null 2>&1; then
  printf 'expected close by non-owner to fail\n' >&2
  exit 1
fi

closed_path="$(agent-coord-close \
  --coord-dir agent-a \
  --agent-id agent-a \
  --result "Closed by owning agent." \
  "$item_id" | tail -n 1)"

test -f "agent-a/$closed_path"
grep -q '^status: closed$' "agent-a/$closed_path"
grep -q '^owner: agent-a$' "agent-a/$closed_path"

agent-coord-pull --coord-dir agent-b >/dev/null
test -f "agent-b/$closed_path"
grep -q '^status: closed$' "agent-b/$closed_path"

printf 'subject length check\n' >agent-b/workspace/decisions/subject-length.md
long_subject="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
if agent-coord-push \
  --coord-dir agent-b \
  -m "$long_subject" >/dev/null 2>&1; then
  printf 'expected long commit subject to fail\n' >&2
  exit 1
fi

git -C agent-b reset --hard HEAD >/dev/null
git -C agent-b clean -fd >/dev/null

printf 'agent coordination concurrency tests passed\n'
