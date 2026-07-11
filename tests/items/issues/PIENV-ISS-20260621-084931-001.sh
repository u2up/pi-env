#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
cd "$repo_root"
. tests/lib/test-helpers.sh

export PI_ENV_COORD_LIB="$repo_root/scripts/pi-env-coord-lib.sh"
export PI_ENV_COORD_TEMPLATE_DIR="$repo_root/pi-skill-templates/agent-coordination"
export PATH="$repo_root/scripts:$PATH"

assert_no_top_level_history() {
  local path
  path="$1"
  if grep -Eq '^(current|events|messages):' "$path"; then
    test_fail "unexpected issue-history field in $path"
  fi
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export HOME="$tmp/home"
mkdir -p "$HOME" "$tmp/project"
git config --global user.name "TODO Coordination Test"
git config --global user.email "todo-coordination@example.invalid"

cd "$tmp/project"
pi-env-coord-init \
  --root "$tmp/remotes" \
  --project pi-env \
  --agent-id agent-a \
  --dir .pi-env/coordination >/dev/null

test_dir_exists .pi-env/coordination/todos
test_grep '`TODO`: `todo`' .pi-env/coordination/docs/ITEM_FORMAT.md
test_grep '`TODO` for `todo`' .pi-env/coordination/AGENTS.md
test_grep '`TODO` for todo' .pi-env/coordination/.pi/skills/agent-coordination/SKILL.md

todo_path="$(pi-env-coord-new \
  --coord-dir .pi-env/coordination \
  --type todo \
  --testable no \
  --testability-note "Item test covers TODO creation." \
  "Example TODO" | tail -n 1)"

test_file_exists ".pi-env/coordination/$todo_path"
case "$todo_path" in
  todos/*.yaml) ;;
  *) test_fail "unexpected TODO path: $todo_path" ;;
esac

test_grep '^id: PIENV-TODO-[0-9]\{8\}-[0-9]\{6\}-001$' \
  ".pi-env/coordination/$todo_path"
test_grep '^type: todo$' ".pi-env/coordination/$todo_path"
test_grep '^status: active$' ".pi-env/coordination/$todo_path"
test_grep '^body: |-$' ".pi-env/coordination/$todo_path"
assert_no_top_level_history ".pi-env/coordination/$todo_path"

todo_id="$(grep '^id: ' ".pi-env/coordination/$todo_path" | sed 's/^id: //')"
todo_list="$(pi-env-coord-list --coord-dir .pi-env/coordination todos active)"
printf '%s\n' "$todo_list" \
  | grep -Eq "^$todo_id[[:space:]]+active[[:space:]]+Example TODO$" \
  || test_fail 'TODO item was not listed by todos active'

if pi-env-coord-new --coord-dir .pi-env/coordination --type tdo "Bad alias" \
  >"$tmp/tdo.out" 2>"$tmp/tdo.err"; then
  test_fail 'pi-env-coord-new accepted unsupported tdo alias'
fi
test_grep '--type tdo is not supported; use --type todo' "$tmp/tdo.err"

if pi-env-coord-list --coord-dir .pi-env/coordination tdo \
  >"$tmp/list-tdo.out" 2>"$tmp/list-tdo.err"; then
  test_fail 'pi-env-coord-list accepted unsupported tdo alias'
fi
test_grep 'item type must be issues, todos,' "$tmp/list-tdo.err"

printf 'PIENV-ISS-20260621-084931-001 passed\n'
