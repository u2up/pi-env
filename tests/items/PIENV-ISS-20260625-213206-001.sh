#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$repo_root"
. tests/lib/test-helpers.sh

export PI_ENV_COORD_LIB="$repo_root/scripts/agent-coord-lib.sh"
export PI_ENV_COORD_TEMPLATE_DIR="$repo_root/pi-skill-templates/agent-coordination"
export PATH="$repo_root/scripts:$PATH"

unset PI_COORD_ROOT PI_COORD_WORKSPACE PI_COORD_DIR PI_COORD_AGENT_ID PI_COORD_PROJECT PI_COORD_PROJECT_KEY PI_COORD_ROLE

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export HOME="$tmp/home"
mkdir -p "$HOME" "$tmp/project"
git config --global user.name "Task Type Test"
git config --global user.email "task-type-test@example.invalid"

git -C "$tmp/project" init -q
cd "$tmp/project"
agent-coord-init \
  --project task-type-test \
  --agent-id agent-a >/dev/null
coord_dir="$tmp/project/.pi-env/coordination"

for unsupported_item_type in task tasks; do
  if agent-coord-new --coord-dir "$coord_dir" \
    --type "$unsupported_item_type" "Unsupported task item type" \
    >"$tmp/new-$unsupported_item_type.out" \
    2>"$tmp/new-$unsupported_item_type.err"; then
    test_fail "agent-coord-new accepted --type $unsupported_item_type"
  fi
  test_grep \
    "--type $unsupported_item_type is not a coordination item type; use --type issue --issue-type task" \
    "$tmp/new-$unsupported_item_type.err"

  if agent-coord-list --coord-dir "$coord_dir" "$unsupported_item_type" \
    >"$tmp/list-$unsupported_item_type.out" \
    2>"$tmp/list-$unsupported_item_type.err"; then
    test_fail "agent-coord-list accepted item type $unsupported_item_type"
  fi
  test_grep \
    "$unsupported_item_type is not a coordination item type; use issues --issue-type task" \
    "$tmp/list-$unsupported_item_type.err"
done

for issue_type_alias in task tasks; do
  issue_path="$(agent-coord-new \
    --coord-dir "$coord_dir" \
    --agent-id agent-a \
    --type issue \
    --issue-type "$issue_type_alias" \
    "Task issue category: $issue_type_alias" | tail -n 1)"
  test_file_exists "$coord_dir/$issue_path"
  test_grep '^type: issue$' "$coord_dir/$issue_path"
  test_grep '^issue_type: task$' "$coord_dir/$issue_path"
  case "$issue_path" in
    issues/open/*.yaml) ;;
    *) test_fail "unexpected task issue path: $issue_path" ;;
  esac

done

printf 'PIENV-ISS-20260625-213206-001 passed\n'
