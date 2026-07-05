#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
lib="$repo_root/scripts/agent-coord-lib.sh"

export PATH="$repo_root/scripts:$PATH"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

root_config="$repo_root/.pi-env-coordination.yaml"
test -f "$root_config"
grep -q '^version: 1$' "$root_config"
grep -q '^coordination_domain: pi-env$' "$root_config"
grep -q '^repo_id: pi-env$' "$root_config"
if grep -q '\.pi-env/' "$root_config"; then
  printf 'root implementation config must not point at local .pi-env paths\n' >&2
  exit 1
fi

for command in agent-coord-init agent-coord-clone agent-coord-done agent-coord-lint; do
  help="$($command --help)"
  grep -q '\.pi-env-coordination\.yaml' <<<"$help"
  if grep -q '\.pi-coordination\.yaml' <<<"$help"; then
    printf '%s help should not advertise the legacy config filename\n' "$command" >&2
    exit 1
  fi
done

coord_dir="$tmp/coordination"
mkdir -p "$coord_dir"
cat >"$coord_dir/repositories.yaml" <<'YAML'
repositories:
  - repo_id: alpha
    active: true
    aliases:
      - legacy-alpha
  - repo_id: remote-project
    active: true
YAML

project="$tmp/project"
mkdir -p "$project"
git -C "$project" init -q
git -C "$project" config user.name "Project Test"
git -C "$project" config user.email "project-test@example.invalid"
git -C "$project" commit --allow-empty -m "Project commit" >/dev/null
git -C "$project" remote add origin git@example.invalid:org/remote-project.git

cat >"$project/.pi-env-coordination.yaml" <<'YAML'
version: 1
coordination_domain: domain
coordination_remote: ssh://new-coordination.example.invalid/domain.git
repo_id: alpha
YAML
cat >"$project/.pi-coordination.yaml" <<'YAML'
version: 1
coordination_domain: domain
coordination_remote: ssh://legacy-coordination.example.invalid/domain.git
repo_id: legacy-alpha
YAML

(
  cd "$project"
  # shellcheck source=/dev/null
  . "$lib"

  [ "$(coord_impl_config_path)" = "$project/.pi-env-coordination.yaml" ]
  [ "$(coord_impl_config_value repo_id 2>"$tmp/new-value.err")" = "alpha" ]
  test ! -s "$tmp/new-value.err"
  [ "$(coord_resolve_coordination_remote '' 2>"$tmp/new-remote.err")" = "ssh://new-coordination.example.invalid/domain.git" ]
  test ! -s "$tmp/new-remote.err"
  [ "$(coord_resolve_repo_id '' "$coord_dir" 2>"$tmp/new-repo.err")" = "alpha" ]
  test ! -s "$tmp/new-repo.err"

  rm .pi-env-coordination.yaml
  [ "$(coord_impl_config_value repo_id 2>"$tmp/legacy-value.err")" = "legacy-alpha" ]
  grep -q 'deprecated: .pi-coordination.yaml is deprecated; rename it to .pi-env-coordination.yaml' \
    "$tmp/legacy-value.err"
  [ "$(coord_resolve_coordination_remote '' 2>"$tmp/legacy-remote.err")" = "ssh://legacy-coordination.example.invalid/domain.git" ]
  grep -q 'deprecated: .pi-coordination.yaml is deprecated; rename it to .pi-env-coordination.yaml' \
    "$tmp/legacy-remote.err"
  [ "$(coord_resolve_repo_id '' "$coord_dir" 2>"$tmp/legacy-repo.err")" = "alpha" ]
  grep -q 'deprecated: .pi-coordination.yaml is deprecated; rename it to .pi-env-coordination.yaml' \
    "$tmp/legacy-repo.err"
  grep -q "update .pi-env-coordination.yaml to 'alpha'" "$tmp/legacy-repo.err"

  rm .pi-coordination.yaml
  git remote remove origin
  if bash -c '. "$1"; coord_resolve_repo_id "" "$2"' bash "$lib" "$coord_dir" \
    >"$tmp/missing.out" 2>"$tmp/missing.err"; then
    printf 'missing repo id unexpectedly succeeded\n' >&2
    exit 1
  fi
  grep -q 'add repo_id to .pi-env-coordination.yaml' "$tmp/missing.err"
)
