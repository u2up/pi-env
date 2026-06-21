#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$repo_root"
. tests/lib/test-helpers.sh

export PI_ENV_COORD_LIB="$repo_root/scripts/agent-coord-lib.sh"
export PI_ENV_COORD_TEMPLATE_DIR="$repo_root/pi-skill-templates/agent-coordination"
export PATH="$repo_root/scripts:$PATH"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export HOME="$tmp/home"
mkdir -p "$HOME" "$tmp/project"
git config --global user.name "List Notes TODO Test"
git config --global user.email "list-notes-todos@example.invalid"

unset PI_COORD_ROOT PI_COORD_WORKSPACE PI_COORD_DIR PI_COORD_AGENT_ID \
  PI_COORD_PROJECT PI_COORD_PROJECT_KEY PI_COORD_ROLE

cd "$tmp/project"
agent-coord-init \
  --root "$tmp/remotes" \
  --project pi-env \
  --agent-id agent-a \
  --dir coordination >/dev/null

help_text="$(agent-coord-list --help)"
printf '%s\n' "$help_text" | grep -q 'issues, todos, notes' \
  || test_fail 'agent-coord-list help did not mention notes and todos'

note_path="$(agent-coord-new \
  --coord-dir coordination \
  --type note \
  --status active \
  --testable no \
  --testability-note "Item test covers note list and cat behavior." \
  "Example note" | tail -n 1)"
todo_path="$(agent-coord-new \
  --coord-dir coordination \
  --type todo \
  --status open \
  --testable no \
  --testability-note "Item test covers TODO list and cat behavior." \
  "Example TODO" | tail -n 1)"

case "$note_path" in
  notes/*.yaml) ;;
  *) test_fail "unexpected note path: $note_path" ;;
esac
case "$todo_path" in
  todos/*.yaml) ;;
  *) test_fail "unexpected TODO path: $todo_path" ;;
esac

test_file_exists "coordination/$note_path"
test_file_exists "coordination/$todo_path"
test_grep '^type: note$' "coordination/$note_path"
test_grep '^status: active$' "coordination/$note_path"
test_grep '^type: todo$' "coordination/$todo_path"
test_grep '^status: open$' "coordination/$todo_path"

note_id="$(grep '^id: ' "coordination/$note_path" | sed 's/^id: //')"
todo_id="$(grep '^id: ' "coordination/$todo_path" | sed 's/^id: //')"

note_list="$(agent-coord-list --coord-dir coordination notes)"
printf '%s\n' "$note_list" \
  | grep -Eq "^$note_id[[:space:]]+active[[:space:]]+Example note$" \
  || test_fail 'notes list omitted the note item'

note_active_list="$(agent-coord-list --coord-dir coordination note active)"
printf '%s\n' "$note_active_list" \
  | grep -Eq "^$note_id[[:space:]]+active[[:space:]]+Example note$" \
  || test_fail 'note active list omitted the note item'
if agent-coord-list --coord-dir coordination note closed | grep -q "$note_id"; then
  test_fail 'note closed list included an active note'
fi

todo_list="$(agent-coord-list --coord-dir coordination todos)"
printf '%s\n' "$todo_list" \
  | grep -Eq "^$todo_id[[:space:]]+open[[:space:]]+Example TODO$" \
  || test_fail 'todos list omitted the TODO item'

todo_open_list="$(agent-coord-list --coord-dir coordination todo open)"
printf '%s\n' "$todo_open_list" \
  | grep -Eq "^$todo_id[[:space:]]+open[[:space:]]+Example TODO$" \
  || test_fail 'todo open list omitted the TODO item'
if agent-coord-list --coord-dir coordination todo active | grep -q "$todo_id"; then
  test_fail 'todo active list included an open TODO'
fi

test_eq "$(cat "coordination/$note_path")" \
  "$(agent-coord-cat --coord-dir coordination "$note_id")" \
  'agent-coord-cat did not print note YAML by ID'
test_eq "$note_path" \
  "$(agent-coord-cat --coord-dir coordination --path "${note_id%-001}")" \
  'agent-coord-cat did not resolve note unique prefix'

test_eq "$(cat "coordination/$todo_path")" \
  "$(agent-coord-cat --coord-dir coordination "$todo_id")" \
  'agent-coord-cat did not print TODO YAML by ID'
test_eq "$todo_path" \
  "$(agent-coord-cat --coord-dir coordination --path "${todo_id%-001}")" \
  'agent-coord-cat did not resolve TODO unique prefix'

printf 'PIENV-ISS-20260621-084933-001 passed\n'
