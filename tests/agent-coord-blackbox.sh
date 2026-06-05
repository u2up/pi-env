#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
export PI_ENV_COORD_LIB="$repo_root/scripts/agent-coord-lib.sh"
export PI_ENV_COORD_TEMPLATE_DIR="$repo_root/pi-skill-templates/agent-coordination"
export PATH="$repo_root/scripts:$PATH"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export HOME="$tmp/home"
mkdir -p "$HOME" "$tmp/workspace"
git config --global user.name "Coordination Test"
git config --global user.email "coordination-test@example.invalid"

cd "$tmp/workspace"
agent-coord-init \
  --root "$tmp/remotes" \
  --workspace demo \
  --agent-id agent-a \
  --project pi-env >/dev/null

test -d "$tmp/remotes/demo-coordination.git"
test -f coordination/AGENTS.md
test -f coordination/docs/SYNC_PROTOCOL.md
test -f coordination/docs/ITEM_FORMAT.md
test -f coordination/.pi/skills/agent-coordination/SKILL.md
test -d coordination/projects/pi-env/issues/open
git -C coordination config --get pull.rebase | grep -qx true
git -C coordination config --get rebase.autoStash | grep -qx true

cd "$tmp"
agent-coord-clone \
  --root "$tmp/remotes" \
  --workspace demo \
  --dir clone >/dev/null

test -f clone/AGENTS.md
test -f clone/docs/SYNC_PROTOCOL.md

git -C clone rev-parse --verify HEAD >/dev/null

action_path="$(cd "$tmp/workspace" && agent-coord-new \
  --coord-dir coordination \
  --project pi-env \
  "Document pi config behavior" | tail -n 1)"

test -f "$tmp/workspace/coordination/$action_path"
grep -q '^id: PI-ENV-[0-9]\{8\}-[0-9]\{6\}$' \
  "$tmp/workspace/coordination/$action_path"
grep -q '^status: open$' "$tmp/workspace/coordination/$action_path"
grep -q '^project: pi-env$' "$tmp/workspace/coordination/$action_path"
grep -q '^# Document pi config behavior$' \
  "$tmp/workspace/coordination/$action_path"

item_id="$(grep '^id: ' "$tmp/workspace/coordination/$action_path" | sed 's/^id: //')"

agent-coord-status --coord-dir "$tmp/workspace/coordination" >/dev/null
agent-coord-push \
  --coord-dir "$tmp/workspace/coordination" \
  -m "Add coordination test item" >/dev/null

agent-coord-claim \
  --coord-dir "$tmp/workspace/coordination" \
  --agent-id agent-a \
  "$item_id" >/dev/null

grep -q '^status: claimed$' "$tmp/workspace/coordination/$action_path"
grep -q '^owner: agent-a$' "$tmp/workspace/coordination/$action_path"

closed_path="$(agent-coord-close \
  --coord-dir "$tmp/workspace/coordination" \
  --agent-id agent-a \
  --result "Completed in test." \
  "$item_id" | tail -n 1)"

test -f "$tmp/workspace/coordination/$closed_path"
grep -q '^status: closed$' "$tmp/workspace/coordination/$closed_path"
grep -q '^closed: 20' "$tmp/workspace/coordination/$closed_path"

printf 'agent coordination blackbox tests passed\n'
