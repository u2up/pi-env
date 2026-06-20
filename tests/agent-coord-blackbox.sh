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

unset PI_COORD_ROOT PI_COORD_WORKSPACE PI_COORD_DIR PI_COORD_AGENT_ID PI_COORD_PROJECT PI_COORD_PROJECT_KEY PI_COORD_ROLE

project_git="$tmp/project-git"
mkdir -p "$project_git"
git -C "$project_git" init -q
git -C "$project_git" config user.name "Project User"
git -C "$project_git" config user.email "project@example.invalid"
PI_COORD_ROLE=architect git -C "$project_git" commit --allow-empty -m "Project commit" >/dev/null
test "$(git -C "$project_git" log -1 --format='%an <%ae>')" = "Project User <project@example.invalid>"

mkdir -p "$tmp/default-root"
cd "$tmp/default-root"
git init -q
agent-coord-init \
  --workspace default-demo \
  --agent-id agent-a \
  --bare-only >"$tmp/default-root.out" 2>"$tmp/default-root.err"
grep -q 'deprecated: --workspace is a compatibility alias; use --project instead' \
  "$tmp/default-root.err"
test -d "$tmp/default-root/.pi-env/agent-remotes/default-demo-coordination.git"
test ! -e "$HOME/agent-remotes/default-demo-coordination.git"
grep -Fxq '/.pi-env/' "$tmp/default-root/.git/info/exclude"

if [ -d /workspace ] && [ "$(realpath -m /workspace)" = "$(realpath -m "$repo_root")" ]; then
  workspace_default_root="$(cd "$repo_root" && unset PI_COORD_ROOT && . "$PI_ENV_COORD_LIB" && coord_default_root)"
  if [ -d "$repo_root/.pi-env/agent-remotes" ]; then
    test "$workspace_default_root" = "/workspace/.pi-env/agent-remotes"
  elif [ -d "$repo_root/agent-remotes" ]; then
    test "$workspace_default_root" = "/workspace/agent-remotes"
  else
    test "$workspace_default_root" = "/workspace/.pi-env/agent-remotes"
  fi
fi

fresh_default_project="$tmp/fresh-default-project"
mkdir -p "$fresh_default_project"
git -C "$fresh_default_project" init -q
cd "$fresh_default_project"
agent-coord-init \
  --project fresh-default \
  --agent-id agent-a >/dev/null

test -d "$fresh_default_project/.pi-env/agent-remotes/fresh-default-coordination.git"
test -f "$fresh_default_project/.pi-env/coordination/AGENTS.md"
grep -Fxq '/.pi-env/' "$fresh_default_project/.git/info/exclude"

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
test -f "$bootstrap_project_dir/.pi-env/coordination/AGENTS.md"
test -d "$bootstrap_project_dir/.pi-env/coordination/issues/open"
test ! -e "$bootstrap_project_dir/.pi-env/coordination/WORKSPACE.md"
test ! -e "$bootstrap_project_dir/.pi-env/coordination/workspace"
test ! -e "$bootstrap_project_dir/.pi-env/coordination/functional-requirements"
test ! -e "$bootstrap_project_dir/.pi-env/coordination/quality-requirements"
test ! -e "$bootstrap_project_dir/.pi-env/coordination/constraint-requirements"
test -d "$bootstrap_project_dir/.pi-env/coordination/requirements"
grep -q '^project: other-project$' "$bootstrap_project_dir/.pi-env/coordination/PROJECT.md"
grep -q '^item_key: OTHERPROJECT$' "$bootstrap_project_dir/.pi-env/coordination/PROJECT.md"
grep -q "Clone dir:    $bootstrap_project_dir/.pi-env/coordination" "$bootstrap_plan"
grep -Fxq '/.pi-env/' "$bootstrap_project_dir/.git/info/exclude"
grep -q 'export PI_COORD_PROJECT=other-project' "$bootstrap_plan"
! grep -q 'PI_COORD_WORKSPACE' "$bootstrap_plan"

bootstrap_remote="$tmp/bootstrap-remotes/other-project-coordination.git"
bootstrap_coord_dir="$bootstrap_project_dir/.pi-env/coordination"
bootstrap_remote_rel="$(realpath -m --relative-to="$bootstrap_coord_dir" "$bootstrap_remote")"
bootstrap_head="$(git -C "$bootstrap_coord_dir" rev-parse HEAD)"
test "$(git -C "$bootstrap_coord_dir" remote get-url origin)" = "$bootstrap_remote_rel"
git -C "$bootstrap_coord_dir" remote remove origin
rm -rf "$bootstrap_remote"
bootstrap-coordination \
  --project-root "$bootstrap_project_dir" \
  --root "$tmp/bootstrap-remotes" \
  --agent-id agent-b \
  --no-status >/dev/null

test -d "$bootstrap_remote"
test "$(git --git-dir="$bootstrap_remote" rev-parse main)" = "$bootstrap_head"
test "$(git -C "$bootstrap_coord_dir" remote get-url origin)" = "$bootstrap_remote_rel"

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
test ! -e "$print_only_project_dir/.pi-env/coordination"

fresh_print_project_dir="$tmp/fresh-print-project"
mkdir -p "$fresh_print_project_dir"
git -C "$fresh_print_project_dir" init -q
bootstrap-coordination \
  --project-root "$fresh_print_project_dir" \
  --print-only >"$tmp/fresh-print-plan.txt" 2>/dev/null
grep -q "Root:         $fresh_print_project_dir/.pi-env/agent-remotes" \
  "$tmp/fresh-print-plan.txt"
grep -q "Clone dir:    $fresh_print_project_dir/.pi-env/coordination" \
  "$tmp/fresh-print-plan.txt"
test ! -e "$fresh_print_project_dir/.pi-env"

server_print_project_dir="$tmp/server-print-project"
mkdir -p "$server_print_project_dir"
git -C "$server_print_project_dir" init -q
server_print_remote="$tmp/server-print.git"
bootstrap-coordination \
  --project-root "$server_print_project_dir" \
  --root "$tmp/server-print-remotes" \
  --remote "$server_print_remote" \
  --print-only >"$tmp/server-print-plan.txt" 2>/dev/null

grep -q "Remote:       $server_print_remote" "$tmp/server-print-plan.txt"
grep -q "agent-coord-init --remote $server_print_remote" "$tmp/server-print-plan.txt"
test ! -e "$tmp/server-print-remotes"
test ! -e "$server_print_project_dir/.pi-env/coordination"

PI_COORD_REMOTE_URL="$tmp/env-remote.git" bootstrap-coordination \
  --project-root "$server_print_project_dir" \
  --remote "$server_print_remote" \
  --print-only >"$tmp/server-precedence-plan.txt" 2>/dev/null
grep -q "Remote:       $server_print_remote" "$tmp/server-precedence-plan.txt"
! grep -q "Remote:       $tmp/env-remote.git" "$tmp/server-precedence-plan.txt"

server_remote="$tmp/server-remote.git"
git init --bare --initial-branch=main "$server_remote" >/dev/null 2>&1 \
  || git init --bare "$server_remote" >/dev/null
agent-coord-init \
  --remote "$server_remote" \
  --project server-demo \
  --agent-id agent-server \
  --dir "$tmp/server-coordination" >/dev/null

test -f "$tmp/server-coordination/AGENTS.md"
server_head="$(git --git-dir="$server_remote" rev-parse main)"
agent-coord-init \
  --remote "$server_remote" \
  --project server-demo \
  --agent-id agent-server \
  --dir "$tmp/server-coordination-existing" >/dev/null

test "$(git -C "$tmp/server-coordination-existing" rev-parse HEAD)" = "$server_head"

env_remote="$tmp/env-clone-remote.git"
git clone --bare "$server_remote" "$env_remote" >/dev/null 2>&1
unset PI_COORD_ROOT
PI_COORD_REMOTE_URL="$env_remote" agent-coord-clone \
  --dir "$tmp/env-remote-clone" >/dev/null
test -f "$tmp/env-remote-clone/AGENTS.md"
agent-coord-clone \
  --remote "$server_remote" \
  --dir "$tmp/arg-remote-clone" >/dev/null
test -f "$tmp/arg-remote-clone/AGENTS.md"

clone_default_project="$tmp/clone-default-project"
mkdir -p "$clone_default_project"
git -C "$clone_default_project" init -q
cd "$clone_default_project"
agent-coord-clone \
  --remote "$server_remote" >/dev/null
test -f "$clone_default_project/.pi-env/coordination/AGENTS.md"
grep -Fxq '/.pi-env/' "$clone_default_project/.git/info/exclude"

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
test ! -e "$bare_only_project_dir/.pi-env/coordination"

cd "$workspace_dir"
agent-coord-init \
  --root "$tmp/remotes" \
  --project pi-env \
  --agent-id agent-a \
  --dir coordination >/dev/null

test -d "$tmp/remotes/pi-env-coordination.git"
test -f coordination/AGENTS.md
test -f coordination/docs/SYNC_PROTOCOL.md
test -f coordination/docs/ITEM_FORMAT.md
test -f coordination/.pi/skills/agent-coordination/SKILL.md
test -d coordination/issues/open
test -d coordination/issues/done
test ! -e coordination/WORKSPACE.md
test ! -e coordination/workspace
test ! -e coordination/functional-requirements
test ! -e coordination/quality-requirements
test ! -e coordination/constraint-requirements
test -d coordination/requirements
grep -q '^project: pi-env$' coordination/PROJECT.md
grep -q '^item_key: PIENV$' coordination/PROJECT.md
git -C coordination config --get pull.rebase | grep -qx true
git -C coordination config --get rebase.autoStash | grep -qx true
test "$(git -C coordination remote get-url origin)" = "../../remotes/pi-env-coordination.git"

cd "$tmp"
agent-coord-clone \
  --root "$tmp/remotes" \
  --project pi-env \
  --dir clone >/dev/null

test -f clone/AGENTS.md
test -f clone/docs/SYNC_PROTOCOL.md
test "$(git -C clone remote get-url origin)" = "../remotes/pi-env-coordination.git"

git -C clone remote remove origin
agent-coord-clone \
  --root "$tmp/remotes" \
  --project pi-env \
  --dir clone >/dev/null

test "$(git -C clone remote get-url origin)" = "../remotes/pi-env-coordination.git"

git -C clone rev-parse --verify HEAD >/dev/null

action_path="$(cd "$workspace_dir" && agent-coord-new \
  --coord-dir coordination \
  --agent-id agent-a \
  --role architect \
  "Document pi config behavior" | tail -n 1)"

test -f "$workspace_dir/coordination/$action_path"
grep -q '^id: PIENV-ISS-[0-9]\{8\}-[0-9]\{6\}-001$' \
  "$workspace_dir/coordination/$action_path"
grep -q '^status: open$' "$workspace_dir/coordination/$action_path"
grep -q '^done: null$' "$workspace_dir/coordination/$action_path"
grep -q '^reviewed: false$' "$workspace_dir/coordination/$action_path"
grep -q '^verified: false$' "$workspace_dir/coordination/$action_path"
grep -q '^testable: yes$' "$workspace_dir/coordination/$action_path"
grep -q '^testability_note: null$' "$workspace_dir/coordination/$action_path"
grep -q '^project: pi-env$' "$workspace_dir/coordination/$action_path"
grep -q "^title: 'Document pi config behavior'$" \
  "$workspace_dir/coordination/$action_path"
grep -q '^    type: opened$' "$workspace_dir/coordination/$action_path"
grep -q '^      id: agent-a$' "$workspace_dir/coordination/$action_path"
grep -q '^      role: architect$' "$workspace_dir/coordination/$action_path"
grep -q '^      # Document pi config behavior$' \
  "$workspace_dir/coordination/$action_path"

explicit_key_path="$(cd "$workspace_dir" && agent-coord-new \
  --coord-dir coordination \
  --project other-project \
  --project-key 'my_key | test/foo\bar' \
  "Explicit project key item" | tail -n 1)"
grep -q '^id: MYKEYTESTFOOBAR-ISS-[0-9]\{8\}-[0-9]\{6\}-001$' \
  "$workspace_dir/coordination/$explicit_key_path"
grep -q '^item_key: MYKEYTESTFOOBAR$' \
  "$workspace_dir/coordination/projects/other-project/PROJECT.md"

workspace_item_path="$(cd "$workspace_dir" && agent-coord-new \
  --coord-dir coordination \
  --workspace-item \
  "Workspace coordination item" | tail -n 1)"
grep -q '^id: PIENVTEST-ISS-[0-9]\{8\}-[0-9]\{6\}-001$' \
  "$workspace_dir/coordination/$workspace_item_path"

requirement_path="$(cd "$workspace_dir" && agent-coord-new \
  --coord-dir coordination \
  --type functional \
  --status accepted \
  --testable no \
  --testability-note "Covered by coordination helper smoke tests." \
  "Functional requirement item naming" | tail -n 1)"
grep -q '^id: PIENV-FRQ-[0-9]\{8\}-[0-9]\{6\}-001$' \
  "$workspace_dir/coordination/$requirement_path"
grep -q '^type: functional-requirement$' "$workspace_dir/coordination/$requirement_path"
grep -q '^status: accepted$' "$workspace_dir/coordination/$requirement_path"
grep -q '^testable: no$' "$workspace_dir/coordination/$requirement_path"
case "$requirement_path" in
  requirements/*.yaml) ;;
  *) printf 'unexpected requirement path: %s\n' "$requirement_path" >&2; exit 1 ;;
esac

quality_requirement_path="$(cd "$workspace_dir" && agent-coord-new \
  --coord-dir coordination \
  --type quality \
  --status accepted \
  --testable no \
  --testability-note "Covered by coordination helper smoke tests." \
  "Quality requirement item naming" | tail -n 1)"
grep -q '^id: PIENV-QRQ-[0-9]\{8\}-[0-9]\{6\}-001$' \
  "$workspace_dir/coordination/$quality_requirement_path"
grep -q '^type: quality-requirement$' "$workspace_dir/coordination/$quality_requirement_path"
case "$quality_requirement_path" in
  requirements/*.yaml) ;;
  *) printf 'unexpected quality requirement path: %s\n' "$quality_requirement_path" >&2; exit 1 ;;
esac

constraint_requirement_path="$(cd "$workspace_dir" && agent-coord-new \
  --coord-dir coordination \
  --type constraint \
  --status accepted \
  --testable no \
  --testability-note "Covered by coordination helper smoke tests." \
  "Constraint requirement item naming" | tail -n 1)"
grep -q '^id: PIENV-CRQ-[0-9]\{8\}-[0-9]\{6\}-001$' \
  "$workspace_dir/coordination/$constraint_requirement_path"
grep -q '^type: constraint-requirement$' "$workspace_dir/coordination/$constraint_requirement_path"
case "$constraint_requirement_path" in
  requirements/*.yaml) ;;
  *) printf 'unexpected constraint requirement path: %s\n' "$constraint_requirement_path" >&2; exit 1 ;;
esac

legacy_requirement_path="$(cd "$workspace_dir" && agent-coord-new \
  --coord-dir coordination \
  --type requirement \
  --status accepted \
  --testable no \
  --testability-note "Covered by coordination helper smoke tests." \
  "Legacy requirement item naming" | tail -n 1)"
grep -q '^id: PIENV-REQ-[0-9]\{8\}-[0-9]\{6\}-001$' \
  "$workspace_dir/coordination/$legacy_requirement_path"
grep -q '^type: requirement$' "$workspace_dir/coordination/$legacy_requirement_path"
case "$legacy_requirement_path" in
  requirements/*.yaml) ;;
  *) printf 'unexpected legacy requirement path: %s\n' "$legacy_requirement_path" >&2; exit 1 ;;
esac

requirement_id="$(grep '^id: ' "$workspace_dir/coordination/$requirement_path" | sed 's/^id: //')"
quality_requirement_id="$(grep '^id: ' "$workspace_dir/coordination/$quality_requirement_path" | sed 's/^id: //')"
constraint_requirement_id="$(grep '^id: ' "$workspace_dir/coordination/$constraint_requirement_path" | sed 's/^id: //')"
legacy_requirement_id="$(grep '^id: ' "$workspace_dir/coordination/$legacy_requirement_path" | sed 's/^id: //')"

decision_path="$(cd "$workspace_dir" && agent-coord-new \
  --coord-dir coordination \
  --type decision \
  --status accepted \
  --testable no \
  --testability-note "Decision item covered by list helper smoke tests." \
  "Use coordination list helper" | tail -n 1)"
grep -q '^id: PIENV-DEC-[0-9]\{8\}-[0-9]\{6\}-001$' \
  "$workspace_dir/coordination/$decision_path"
grep -q '^type: decision$' "$workspace_dir/coordination/$decision_path"
grep -q '^status: accepted$' "$workspace_dir/coordination/$decision_path"
case "$decision_path" in
  decisions/*.yaml) ;;
  *) printf 'unexpected decision path: %s\n' "$decision_path" >&2; exit 1 ;;
esac

decision_id="$(grep '^id: ' "$workspace_dir/coordination/$decision_path" | sed 's/^id: //')"
item_id="$(grep '^id: ' "$workspace_dir/coordination/$action_path" | sed 's/^id: //')"

test "$(agent-coord-cat --coord-dir "$workspace_dir/coordination" "$item_id")" = \
  "$(cat "$workspace_dir/coordination/$action_path")"
test "$(agent-coord-cat --coord-dir "$workspace_dir/coordination" --path "$item_id")" = "$action_path"
test "$(agent-coord-cat --coord-dir "$workspace_dir/coordination" --path "$action_path")" = "$action_path"
test "$(agent-coord-cat \
  --coord-dir "$workspace_dir/coordination" \
  --path "${item_id%-001}")" = "$action_path"
if agent-coord-cat --coord-dir "$workspace_dir/coordination" MISSING-ITEM \
  >"$tmp/cat-missing.out" 2>"$tmp/cat-missing.err"; then
  printf 'agent-coord-cat unexpectedly found missing item\n' >&2
  exit 1
fi
grep -q '^agent-coord: item not found: MISSING-ITEM$' "$tmp/cat-missing.err"
if agent-coord-cat --coord-dir "$workspace_dir/coordination" PIENV \
  >"$tmp/cat-ambiguous.out" 2>"$tmp/cat-ambiguous.err"; then
  printf 'agent-coord-cat unexpectedly resolved ambiguous prefix\n' >&2
  exit 1
fi
grep -q '^agent-coord: multiple items match PIENV:' "$tmp/cat-ambiguous.err"
grep -q "$action_path" "$tmp/cat-ambiguous.err"

issue_list="$(agent-coord-list --coord-dir "$workspace_dir/coordination" issues open)"
printf '%s\n' "$issue_list" \
  | grep -Eq "^$item_id[[:space:]]+open[[:space:]]+Document pi config behavior$"
requirement_list="$(agent-coord-list \
  --coord-dir "$workspace_dir/coordination" functional-requirements accepted)"
printf '%s\n' "$requirement_list" \
  | grep -Eq "^$requirement_id[[:space:]]+accepted[[:space:]]+Functional requirement item naming$"
all_requirement_list="$(agent-coord-list \
  --coord-dir "$workspace_dir/coordination" requirements accepted)"
printf '%s\n' "$all_requirement_list" \
  | grep -Eq "^$requirement_id[[:space:]]+accepted[[:space:]]+Functional requirement item naming$"
printf '%s\n' "$all_requirement_list" \
  | grep -Eq "^$quality_requirement_id[[:space:]]+accepted[[:space:]]+Quality requirement item naming$"
printf '%s\n' "$all_requirement_list" \
  | grep -Eq "^$constraint_requirement_id[[:space:]]+accepted[[:space:]]+Constraint requirement item naming$"
printf '%s\n' "$all_requirement_list" \
  | grep -Eq "^$legacy_requirement_id[[:space:]]+accepted[[:space:]]+Legacy requirement item naming$"
legacy_requirement_list="$(agent-coord-list \
  --coord-dir "$workspace_dir/coordination" legacy-requirements accepted)"
printf '%s\n' "$legacy_requirement_list" \
  | grep -Eq "^$legacy_requirement_id[[:space:]]+accepted[[:space:]]+Legacy requirement item naming$"
if printf '%s\n' "$legacy_requirement_list" | grep -q "$requirement_id"; then
  printf 'legacy requirement list included class requirement\n' >&2
  exit 1
fi
decision_list="$(agent-coord-list \
  --coord-dir "$workspace_dir/coordination" decisions accepted)"
printf '%s\n' "$decision_list" \
  | grep -Eq "^$decision_id[[:space:]]+accepted[[:space:]]+Use coordination list helper$"

agent-coord-status --coord-dir "$workspace_dir/coordination" >/dev/null
agent-coord-push \
  --coord-dir "$workspace_dir/coordination" \
  --agent-id agent-a \
  --role architect \
  -m "Add coordination test item" >/dev/null
test "$(git -C "$workspace_dir/coordination" log -1 --format='%an <%ae>|%cn <%ce>')" = \
  "agent-a/architect <agent-a+architect@coordination.local>|agent-a/architect <agent-a+architect@coordination.local>"

agent-coord-claim \
  --coord-dir "$workspace_dir/coordination" \
  --agent-id agent-a \
  --role developer \
  "$item_id" >/dev/null

grep -q '^status: claimed$' "$workspace_dir/coordination/$action_path"
grep -q '^owner: agent-a$' "$workspace_dir/coordination/$action_path"
grep -q '^    type: claimed$' "$workspace_dir/coordination/$action_path"
grep -q '^      role: developer$' "$workspace_dir/coordination/$action_path"
grep -q '^      Claimed\.$' "$workspace_dir/coordination/$action_path"
test "$(git -C "$workspace_dir/coordination" log -1 --format='%an <%ae>|%cn <%ce>')" = \
  "agent-a/developer <agent-a+developer@coordination.local>|agent-a/developer <agent-a+developer@coordination.local>"

done_path="$(agent-coord-done \
  --coord-dir "$workspace_dir/coordination" \
  --agent-id agent-a \
  --role developer \
  --result "Implemented in test." \
  --implementation-ref \
  "pi-env:main@0123456789abcdef0123456789abcdef01234567" \
  "$item_id" | tail -n 1)"

test -f "$workspace_dir/coordination/$done_path"
grep -q '^status: done$' "$workspace_dir/coordination/$done_path"
grep -q '^done: 20' "$workspace_dir/coordination/$done_path"
grep -q '^closed: null$' "$workspace_dir/coordination/$done_path"
grep -q '^reviewed: false$' "$workspace_dir/coordination/$done_path"
grep -q '^verified: false$' "$workspace_dir/coordination/$done_path"
grep -q '^    type: done$' "$workspace_dir/coordination/$done_path"
grep -q '^      role: developer$' "$workspace_dir/coordination/$done_path"
grep -q '^      - repo: pi-env$' "$workspace_dir/coordination/$done_path"
grep -q '^        branch: main$' "$workspace_dir/coordination/$done_path"
grep -q '^        commit: 0123456789abcdef0123456789abcdef01234567$' \
  "$workspace_dir/coordination/$done_path"
grep -q '^      Implemented in test\.$' "$workspace_dir/coordination/$done_path"
test "$(git -C "$workspace_dir/coordination" log -1 --format='%an <%ae>|%cn <%ce>')" = \
  "agent-a/developer <agent-a+developer@coordination.local>|agent-a/developer <agent-a+developer@coordination.local>"

done_issue_list="$(agent-coord-list --coord-dir "$workspace_dir/coordination" issues done)"
printf '%s\n' "$done_issue_list" \
  | grep -Eq "^$item_id[[:space:]]+done[[:space:]]+Document pi config behavior \\(reviewed:false, verified:false\\)$"

review_path="$(agent-coord-review \
  --coord-dir "$workspace_dir/coordination" \
  --agent-id reviewer-a \
  --role reviewer \
  --pass \
  --result "Review passed." \
  "$item_id" | tail -n 1)"

test "$review_path" = "$done_path"
grep -q '^reviewed: true$' "$workspace_dir/coordination/$done_path"
grep -q '^    type: reviewed$' "$workspace_dir/coordination/$done_path"
grep -q '^      role: reviewer$' "$workspace_dir/coordination/$done_path"
grep -q '^      Review passed\.$' "$workspace_dir/coordination/$done_path"
test "$(git -C "$workspace_dir/coordination" log -1 --format='%an <%ae>|%cn <%ce>')" = \
  "reviewer-a/reviewer <reviewer-a+reviewer@coordination.local>|reviewer-a/reviewer <reviewer-a+reviewer@coordination.local>"

verify_path="$(PI_COORD_ROLE=tester agent-coord-verify \
  --coord-dir "$workspace_dir/coordination" \
  --agent-id tester-a \
  --pass \
  --result "Verification passed." \
  "$item_id" | tail -n 1)"

test "$verify_path" = "$done_path"
grep -q '^verified: true$' "$workspace_dir/coordination/$done_path"
grep -q '^    type: verified$' "$workspace_dir/coordination/$done_path"
grep -q '^      role: tester$' "$workspace_dir/coordination/$done_path"
grep -q '^      Verification passed\.$' "$workspace_dir/coordination/$done_path"
test "$(git -C "$workspace_dir/coordination" log -1 --format='%an <%ae>|%cn <%ce>')" = \
  "tester-a/tester <tester-a+tester@coordination.local>|tester-a/tester <tester-a+tester@coordination.local>"

reviewed_verified_done_issue_list="$(agent-coord-list --coord-dir "$workspace_dir/coordination" issues done)"
printf '%s\n' "$reviewed_verified_done_issue_list" \
  | grep -Eq "^$item_id[[:space:]]+done[[:space:]]+Document pi config behavior \\(reviewed:true, verified:true\\)$"

closed_path="$(PI_COORD_ROLE=tester agent-coord-close \
  --coord-dir "$workspace_dir/coordination" \
  --agent-id tester-a \
  --result "Closed after review and verification." \
  "$item_id" | tail -n 1)"

test -f "$workspace_dir/coordination/$closed_path"
grep -q '^status: closed$' "$workspace_dir/coordination/$closed_path"
grep -q '^closed: 20' "$workspace_dir/coordination/$closed_path"
grep -q '^reviewed: true$' "$workspace_dir/coordination/$closed_path"
grep -q '^verified: true$' "$workspace_dir/coordination/$closed_path"
grep -q '^    type: closed$' "$workspace_dir/coordination/$closed_path"
grep -q '^      role: tester$' "$workspace_dir/coordination/$closed_path"
grep -q '^      Closed after review and verification\.$' "$workspace_dir/coordination/$closed_path"
test "$(git -C "$workspace_dir/coordination" log -1 --format='%an <%ae>|%cn <%ce>')" = \
  "tester-a/tester <tester-a+tester@coordination.local>|tester-a/tester <tester-a+tester@coordination.local>"

closed_issue_list="$(agent-coord-list --coord-dir "$workspace_dir/coordination" issues closed)"
printf '%s\n' "$closed_issue_list" \
  | grep -Eq "^$item_id[[:space:]]+closed[[:space:]]+Document pi config behavior$"

review_fail_path="$(agent-coord-new \
  --coord-dir "$workspace_dir/coordination" \
  --agent-id agent-a \
  --role developer \
  "Review failure clears owner" | tail -n 1)"
review_fail_id="$(basename "$review_fail_path")"
review_fail_id="${review_fail_id%.yaml}"
agent-coord-claim \
  --coord-dir "$workspace_dir/coordination" \
  --agent-id agent-a \
  --role developer \
  "$review_fail_id" >/dev/null
agent-coord-done \
  --coord-dir "$workspace_dir/coordination" \
  --agent-id agent-a \
  --role developer \
  --result "Ready for failed review." \
  "$review_fail_id" >/dev/null
review_failed_path="$(agent-coord-review \
  --coord-dir "$workspace_dir/coordination" \
  --agent-id reviewer-a \
  --role reviewer \
  --fail \
  --result "Needs more work." \
  "$review_fail_id" | tail -n 1)"

test "$review_failed_path" = "issues/open/$review_fail_id.yaml"
grep -q '^status: open$' "$workspace_dir/coordination/$review_failed_path"
grep -q '^owner: null$' "$workspace_dir/coordination/$review_failed_path"
grep -q '^done: null$' "$workspace_dir/coordination/$review_failed_path"
grep -q '^reviewed: false$' "$workspace_dir/coordination/$review_failed_path"
grep -q '^verified: false$' "$workspace_dir/coordination/$review_failed_path"
grep -q '^    type: review_failed$' \
  "$workspace_dir/coordination/$review_failed_path"

verify_fail_path="$(agent-coord-new \
  --coord-dir "$workspace_dir/coordination" \
  --agent-id agent-a \
  --role developer \
  "Verification failure clears owner" | tail -n 1)"
verify_fail_id="$(basename "$verify_fail_path")"
verify_fail_id="${verify_fail_id%.yaml}"
agent-coord-claim \
  --coord-dir "$workspace_dir/coordination" \
  --agent-id agent-a \
  --role developer \
  "$verify_fail_id" >/dev/null
agent-coord-done \
  --coord-dir "$workspace_dir/coordination" \
  --agent-id agent-a \
  --role developer \
  --result "Ready for failed verification." \
  "$verify_fail_id" >/dev/null
agent-coord-review \
  --coord-dir "$workspace_dir/coordination" \
  --agent-id reviewer-a \
  --role reviewer \
  --pass \
  --result "Review passed for verification failure test." \
  "$verify_fail_id" >/dev/null
verification_failed_path="$(PI_COORD_ROLE=tester agent-coord-verify \
  --coord-dir "$workspace_dir/coordination" \
  --agent-id tester-a \
  --fail \
  --result "Needs more verification work." \
  "$verify_fail_id" | tail -n 1)"

test "$verification_failed_path" = "issues/open/$verify_fail_id.yaml"
grep -q '^status: open$' "$workspace_dir/coordination/$verification_failed_path"
grep -q '^owner: null$' "$workspace_dir/coordination/$verification_failed_path"
grep -q '^done: null$' "$workspace_dir/coordination/$verification_failed_path"
grep -q '^reviewed: false$' "$workspace_dir/coordination/$verification_failed_path"
grep -q '^verified: false$' "$workspace_dir/coordination/$verification_failed_path"
grep -q '^    type: verification_failed$' \
  "$workspace_dir/coordination/$verification_failed_path"

head_before="$(git -C "$workspace_dir/coordination" rev-parse HEAD)"
agent-coord-upgrade-rules \
  --coord-dir "$workspace_dir/coordination" \
  --preview >/dev/null
head_after="$(git -C "$workspace_dir/coordination" rev-parse HEAD)"
test "$head_before" = "$head_after"
test -z "$(git -C "$workspace_dir/coordination" status --short)"

printf 'agent coordination blackbox tests passed\n'
