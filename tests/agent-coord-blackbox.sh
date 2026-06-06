#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
export PI_ENV_COORD_LIB="$repo_root/scripts/agent-coord-lib.sh"
export PI_ENV_COORD_TEMPLATE_DIR="$repo_root/pi-skill-templates/agent-coordination"
export PATH="$repo_root/scripts:$PATH"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export HOME="$tmp/home"
workspace_dir="$tmp/pi-env_test"
mkdir -p "$HOME" "$workspace_dir"
git config --global user.name "Coordination Test"
git config --global user.email "coordination-test@example.invalid"

cd "$workspace_dir"
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
grep -q '^item_key: PIENV$' coordination/projects/pi-env/PROJECT.md
grep -q '^item_key: PIENVTEST$' coordination/WORKSPACE.md
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

action_path="$(cd "$workspace_dir" && agent-coord-new \
  --coord-dir coordination \
  --project pi-env \
  "Document pi config behavior" | tail -n 1)"

test -f "$workspace_dir/coordination/$action_path"
grep -q '^id: PIENV-[0-9]\{8\}-[0-9]\{6\}$' \
  "$workspace_dir/coordination/$action_path"
grep -q '^status: open$' "$workspace_dir/coordination/$action_path"
grep -q '^project: pi-env$' "$workspace_dir/coordination/$action_path"
grep -q '^# Document pi config behavior$' \
  "$workspace_dir/coordination/$action_path"

explicit_key_path="$(cd "$workspace_dir" && agent-coord-new \
  --coord-dir coordination \
  --project other-project \
  --project-key 'my_key | test/foo\bar' \
  "Explicit project key item" | tail -n 1)"
grep -q '^id: MYKEYTESTFOOBAR-[0-9]\{8\}-[0-9]\{6\}$' \
  "$workspace_dir/coordination/$explicit_key_path"
grep -q '^item_key: MYKEYTESTFOOBAR$' \
  "$workspace_dir/coordination/projects/other-project/PROJECT.md"

workspace_item_path="$(cd "$workspace_dir" && agent-coord-new \
  --coord-dir coordination \
  --workspace-item \
  "Workspace coordination item" | tail -n 1)"
grep -q '^id: PIENVTEST-[0-9]\{8\}-[0-9]\{6\}$' \
  "$workspace_dir/coordination/$workspace_item_path"

item_id="$(grep '^id: ' "$workspace_dir/coordination/$action_path" | sed 's/^id: //')"

agent-coord-status --coord-dir "$workspace_dir/coordination" >/dev/null
agent-coord-push \
  --coord-dir "$workspace_dir/coordination" \
  -m "Add coordination test item" >/dev/null

agent-coord-claim \
  --coord-dir "$workspace_dir/coordination" \
  --agent-id agent-a \
  "$item_id" >/dev/null

grep -q '^status: claimed$' "$workspace_dir/coordination/$action_path"
grep -q '^owner: agent-a$' "$workspace_dir/coordination/$action_path"

closed_path="$(agent-coord-close \
  --coord-dir "$workspace_dir/coordination" \
  --agent-id agent-a \
  --result "Completed in test." \
  "$item_id" | tail -n 1)"

test -f "$workspace_dir/coordination/$closed_path"
grep -q '^status: closed$' "$workspace_dir/coordination/$closed_path"
grep -q '^closed: 20' "$workspace_dir/coordination/$closed_path"

head_before="$(git -C "$workspace_dir/coordination" rev-parse HEAD)"
agent-coord-upgrade-rules \
  --coord-dir "$workspace_dir/coordination" \
  --preview >/dev/null
head_after="$(git -C "$workspace_dir/coordination" rev-parse HEAD)"
test "$head_before" = "$head_after"
test -z "$(git -C "$workspace_dir/coordination" status --short)"

printf 'agent coordination blackbox tests passed\n'
