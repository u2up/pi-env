#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
export PI_ENV_COORD_LIB="$repo_root/scripts/agent-coord-lib.sh"
export PATH="$repo_root/scripts:$PATH"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

unset PI_COORD_ROOT PI_COORD_WORKSPACE PI_COORD_DIR PI_COORD_AGENT_ID PI_COORD_PROJECT PI_COORD_PROJECT_KEY PI_COORD_ROLE

git config --global user.name "Coordination Test"
git config --global user.email "coordination-test@example.invalid"

project_root="$tmp/project"
coord_dir="$project_root/coordination"
mkdir -p "$coord_dir" "$project_root/tests/items" "$project_root/designs"
git -C "$coord_dir" init -q
cat >"$coord_dir/PROJECT.md" <<'EOF_PROJECT'
---
project: root-demo
item_key: ROOTDEMO
created: 2026-01-01T00:00:00Z
---

# Root Demo
EOF_PROJECT
mkdir -p \
  "$coord_dir/issues/open" \
  "$coord_dir/issues/blocked" \
  "$coord_dir/issues/done" \
  "$coord_dir/issues/closed" \
  "$coord_dir/requirements" \
  "$coord_dir/decisions" \
  "$coord_dir/notes"
git -C "$coord_dir" add -A
git -C "$coord_dir" commit -q -m "Initialize root layout"

issue_path="$(agent-coord-new \
  --coord-dir "$coord_dir" \
  --agent-id agent-a \
  --role architect \
  "Root layout issue" | tail -n 1)"
case "$issue_path" in
  issues/open/ROOTDEMO-ISS-*.yaml) ;;
  *) printf 'unexpected root issue path: %s\n' "$issue_path" >&2; exit 1 ;;
esac
issue_id="$(basename "$issue_path" .yaml)"
grep -q '^project: root-demo$' "$coord_dir/$issue_path"
grep -q "^$issue_id[[:space:]]\+open[[:space:]]\+Root layout issue$" \
  <(agent-coord-list --coord-dir "$coord_dir" issues open)
agent-coord-cat --coord-dir "$coord_dir" "$issue_id" | grep -q "^title: 'Root layout issue'$"
agent-coord-status --coord-dir "$coord_dir" | grep -q "$issue_id"

cat >"$project_root/tests/items/$issue_id.sh" <<'EOF_TEST'
#!/usr/bin/env bash
set -euo pipefail
true
EOF_TEST
chmod +x "$project_root/tests/items/$issue_id.sh"

agent-coord-claim --coord-dir "$coord_dir" --agent-id agent-a --role developer --no-pull --no-push "$issue_id" >/dev/null
agent-coord-done --coord-dir "$coord_dir" --agent-id agent-a --role developer --no-pull --no-push "$issue_id" >/dev/null
agent-coord-review --coord-dir "$coord_dir" --agent-id reviewer --role reviewer --no-pull --no-push --pass "$issue_id" >/dev/null
agent-coord-verify --coord-dir "$coord_dir" --agent-id verifier --role verifier --no-pull --no-push --pass "$issue_id" >/dev/null
agent-coord-close --coord-dir "$coord_dir" --agent-id closer --role maintainer --no-pull --no-push "$issue_id" >/dev/null

test -f "$coord_dir/issues/closed/$issue_id.yaml"
grep -q '^status: closed$' "$coord_dir/issues/closed/$issue_id.yaml"
agent-coord-list --coord-dir "$coord_dir" issues closed | grep -q "^$issue_id"

requirement_path="$(agent-coord-new \
  --coord-dir "$coord_dir" \
  --type functional \
  --testable no \
  --testability-note "Rendered by root layout test." \
  "Root layout requirement" | tail -n 1)"
case "$requirement_path" in
  requirements/ROOTDEMO-FRQ-*.yaml) ;;
  *) printf 'unexpected root requirement path: %s\n' "$requirement_path" >&2; exit 1 ;;
esac
requirement_id="$(basename "$requirement_path" .yaml)"

agent-coord-generate-requirements \
  --coordination-dir "$coord_dir" \
  --project root-demo | grep -q 'Root layout requirement'

cat >"$project_root/designs/root.md" <<EOF_DESIGN
# Root design

## Covers

| Requirement | Coordination item |
|-------------|-------------------|
| $requirement_id | $requirement_id |
EOF_DESIGN
agent-coord-generate-requirements-coverage \
  --coordination-dir "$coord_dir" \
  --project root-demo \
  --designs-dir "$project_root/designs" \
  --check

agent-coord-lint --coord-dir "$coord_dir" --project-root "$project_root"
