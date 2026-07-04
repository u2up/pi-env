#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
export PI_ENV_COORD_LIB="$repo_root/scripts/agent-coord-lib.sh"
export PATH="$repo_root/scripts:$PATH"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home"
mkdir -p "$HOME"

git config --global user.name "Coordination Test"
git config --global user.email "coordination-test@example.invalid"

coord_dir="$tmp/coordination"
mkdir -p "$coord_dir"
git -C "$coord_dir" init -q
cat >"$coord_dir/PROJECT.md" <<'EOF_PROJECT'
---
project: registry-demo
item_key: REG
created: 2026-01-01T00:00:00Z
---

# Registry Demo
EOF_PROJECT
mkdir -p "$coord_dir/issues/open" "$coord_dir/issues/blocked" "$coord_dir/issues/done" "$coord_dir/issues/closed"
git -C "$coord_dir" add -A
git -C "$coord_dir" commit -q -m "Initialize registry test"

agent-coord-repo --coord-dir "$coord_dir" add alpha --remote https://example.invalid/alpha.git >/dev/null
test -f "$coord_dir/repos/alpha/REPO.md"
for state in open blocked done closed; do
  test -d "$coord_dir/repos/alpha/issues/$state"
done
agent-coord-repo --coord-dir "$coord_dir" list --active | grep -q $'^alpha\tactive$'
agent-coord-repo --coord-dir "$coord_dir" show alpha | grep -q '^repo_id: alpha$'

issue_path="$(agent-coord-new --coord-dir "$coord_dir" --repo-id alpha "Alpha issue" | tail -n 1)"
case "$issue_path" in
  repos/alpha/issues/open/ALPHA-ISS-*.yaml) ;;
  *) printf 'unexpected repo issue path: %s\n' "$issue_path" >&2; exit 1 ;;
esac
issue_id="$(basename "$issue_path" .yaml)"
agent-coord-cat --coord-dir "$coord_dir" "$issue_id" | grep -q '^project: alpha$'

if agent-coord-repo --coord-dir "$coord_dir" retire alpha >"$tmp/retire.out" 2>"$tmp/retire.err"; then
  printf 'retire unexpectedly succeeded with open issue\n' >&2
  exit 1
fi
grep -q 'open issues' "$tmp/retire.err"

agent-coord-repo --coord-dir "$coord_dir" retire alpha --force | grep -q '^retired alpha$'
agent-coord-repo --coord-dir "$coord_dir" list --retired | grep -q $'^alpha\tretired$'
if agent-coord-new --coord-dir "$coord_dir" --repo-id alpha "Blocked by retirement" >"$tmp/new-retired.out" 2>"$tmp/new-retired.err"; then
  printf 'new issue unexpectedly succeeded for retired repo\n' >&2
  exit 1
fi
grep -q 'retired' "$tmp/new-retired.err"

agent-coord-repo --coord-dir "$coord_dir" add delta --remote https://example.invalid/not-delta.git >/dev/null
impl_dir="$tmp/impl"
mkdir -p "$impl_dir"
git -C "$impl_dir" init -q
git -C "$impl_dir" remote add origin https://example.invalid/not-delta.git
resolved_remote_repo="$(cd "$impl_dir" && bash -c '. "$0"; coord_resolve_repo_id "" "$1"' "$repo_root/scripts/agent-coord-lib.sh" "$coord_dir")"
test "$resolved_remote_repo" = delta
agent-coord-repo --coord-dir "$coord_dir" add epsilon --remote https://example.invalid/not-delta.git >/dev/null
if cd "$impl_dir" && bash -c '. "$0"; coord_resolve_repo_id "" "$1"' "$repo_root/scripts/agent-coord-lib.sh" "$coord_dir" >"$tmp/amb-remote.out" 2>"$tmp/amb-remote.err"; then
  printf 'ambiguous registry remote unexpectedly resolved\n' >&2
  exit 1
fi
grep -q 'ambiguous' "$tmp/amb-remote.err"

agent-coord-repo --coord-dir "$coord_dir" add beta >/dev/null
agent-coord-repo --coord-dir "$coord_dir" rename beta gamma >/dev/null
test -d "$coord_dir/repos/gamma"
test ! -e "$coord_dir/repos/beta"
grep -q '^repo_id: gamma$' "$coord_dir/repos/gamma/REPO.md"
grep -q '^  - beta$' "$coord_dir/repos/gamma/REPO.md"
agent-coord-repo --coord-dir "$coord_dir" show beta 2>"$tmp/show-alias.err" | grep -q '^repo_id: gamma$'
grep -q "alias for 'gamma'" "$tmp/show-alias.err"

alias_issue_path="$(agent-coord-new --coord-dir "$coord_dir" --repo-id beta "Alias issue" 2>"$tmp/new-alias.err" | tail -n 1)"
case "$alias_issue_path" in
  repos/gamma/issues/open/GAMMA-ISS-*.yaml) ;;
  *) printf 'unexpected alias issue path: %s\n' "$alias_issue_path" >&2; exit 1 ;;
esac
grep -q "alias; update" "$tmp/new-alias.err"

for bad in Alpha .alpha alpha/one alpha-; do
  if agent-coord-repo --coord-dir "$coord_dir" add "$bad" >"$tmp/bad.out" 2>"$tmp/bad.err"; then
    printf 'invalid repo id accepted: %s\n' "$bad" >&2
    exit 1
  fi
done

mkdir -p "$coord_dir/repos/amb1" "$coord_dir/repos/amb2"
cat >"$coord_dir/repos/amb1/REPO.md" <<'EOF_AMB1'
---
repo_id: amb1
status: active
aliases:
  - old
---
EOF_AMB1
cat >"$coord_dir/repos/amb2/REPO.md" <<'EOF_AMB2'
---
repo_id: amb2
status: active
aliases:
  - old
---
EOF_AMB2
if agent-coord-repo --coord-dir "$coord_dir" show old >"$tmp/amb.out" 2>"$tmp/amb.err"; then
  printf 'ambiguous alias unexpectedly resolved\n' >&2
  exit 1
fi
grep -q 'ambiguous' "$tmp/amb.err"
