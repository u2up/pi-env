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

unset PI_COORD_ROOT PI_COORD_WORKSPACE PI_COORD_DIR PI_COORD_AGENT_ID PI_COORD_PROJECT PI_COORD_PROJECT_KEY
mkdir -p "$tmp/default-root"
cd "$tmp/default-root"
git init -q
agent-coord-init \
  --workspace default-demo \
  --agent-id agent-a \
  --project pi-env \
  --bare-only >/dev/null
test -d "$tmp/default-root/agent-remotes/default-demo-coordination.git"
test ! -e "$HOME/agent-remotes/default-demo-coordination.git"

if [ -d /workspace ] && [ "$(realpath -m /workspace)" = "$(realpath -m "$repo_root")" ]; then
  workspace_default_root="$(cd "$repo_root" && unset PI_COORD_ROOT && . "$PI_ENV_COORD_LIB" && coord_default_root)"
  test "$workspace_default_root" = "/workspace/agent-remotes"
fi

bootstrap_project_dir="$tmp/bootstrap-project"
mkdir -p "$bootstrap_project_dir"
git -C "$bootstrap_project_dir" init -q
git -C "$bootstrap_project_dir" remote add origin git@example.invalid:example/other-project.git
cd "$tmp"
bootstrap_plan="$tmp/bootstrap-plan.txt"
PI_COORD_WORKSPACE=stale-workspace \
PI_COORD_DIR="$tmp/stale-coordination" \
PI_COORD_PROJECT=stale-project \
PI_COORD_PROJECT_KEY=STALE \
bootstrap-coordination \
  --project-root "$bootstrap_project_dir" \
  --root "$tmp/bootstrap-remotes" \
  --agent-id agent-b \
  --no-status >"$bootstrap_plan" 2>/dev/null

test -d "$tmp/bootstrap-remotes/other-project-coordination.git"
test -f "$bootstrap_project_dir/coordination/AGENTS.md"
test -d "$bootstrap_project_dir/coordination/projects/other-project/issues/open"
grep -q '^workspace: other-project$' "$bootstrap_project_dir/coordination/WORKSPACE.md"
grep -q '^item_key: OTHERPROJECT$' "$bootstrap_project_dir/coordination/projects/other-project/PROJECT.md"
grep -q "Clone dir:    $bootstrap_project_dir/coordination" "$bootstrap_plan"
grep -q 'export PI_COORD_WORKSPACE=other-project' "$bootstrap_plan"

bootstrap_remote="$tmp/bootstrap-remotes/other-project-coordination.git"
bootstrap_head="$(git -C "$bootstrap_project_dir/coordination" rev-parse HEAD)"
git -C "$bootstrap_project_dir/coordination" remote remove origin
rm -rf "$bootstrap_remote"
bootstrap-coordination \
  --project-root "$bootstrap_project_dir" \
  --root "$tmp/bootstrap-remotes" \
  --agent-id agent-b \
  --no-status >/dev/null

test -d "$bootstrap_remote"
test "$(git --git-dir="$bootstrap_remote" rev-parse main)" = "$bootstrap_head"
test "$(git -C "$bootstrap_project_dir/coordination" remote get-url origin)" = "$bootstrap_remote"

rm -rf "$bootstrap_remote"
bootstrap-coordination \
  --project-root "$bootstrap_project_dir" \
  --root "$tmp/bootstrap-remotes" \
  --agent-id agent-b \
  --no-status >/dev/null

test -d "$bootstrap_remote"
test "$(git --git-dir="$bootstrap_remote" rev-parse main)" = "$bootstrap_head"

print_only_project_dir="$tmp/print-only-project"
mkdir -p "$print_only_project_dir"
git -C "$print_only_project_dir" init -q
git -C "$print_only_project_dir" remote add origin https://example.invalid/org/printed-project.git
cd "$tmp"
bootstrap-coordination \
  --project-root "$print_only_project_dir" \
  --root "$tmp/print-only-remotes" \
  --print-only >/dev/null

test ! -e "$tmp/print-only-remotes"
test ! -e "$print_only_project_dir/coordination"

bare_only_project_dir="$tmp/bare-only-project"
mkdir -p "$bare_only_project_dir"
git -C "$bare_only_project_dir" init -q
git -C "$bare_only_project_dir" remote add origin https://example.invalid/org/bare-project.git
cd "$tmp"
bootstrap-coordination \
  --project-root "$bare_only_project_dir" \
  --root "$tmp/bare-only-remotes" \
  --bare-only \
  --no-status >/dev/null

test -d "$tmp/bare-only-remotes/bare-project-coordination.git"
test ! -e "$bare_only_project_dir/coordination"

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
