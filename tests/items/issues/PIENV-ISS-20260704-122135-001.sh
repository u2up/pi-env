#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
lib="$repo_root/scripts/agent-coord-lib.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

coord_dir="$tmp/coordination"
mkdir -p "$coord_dir"
cat >"$coord_dir/repositories.yaml" <<'YAML'
repositories:
  - repo_id: backend-api
    active: true
    aliases:
      - api-old
  - repo_id: remote-api
    active: true
  - repo_id: inactive-api
    active: false
YAML

project="$tmp/project"
mkdir -p "$project"
git -C "$project" init -q
git -C "$project" remote add origin git@example.com:org/remote-api.git
cat >"$project/.pi-coordination.yaml" <<'YAML'
version: 1
coordination_domain: my-product
coordination_remote: git@example.com:org/my-product-coordination.git
repo_id: api-old
YAML

(
  cd "$project"
  # shellcheck source=/dev/null
  . "$lib"

  [ "$(coord_impl_config_path)" = "$project/.pi-coordination.yaml" ]
  [ "$(coord_impl_config_value repo_id)" = "api-old" ]
  [ "$(coord_resolve_coordination_remote '')" = "git@example.com:org/my-product-coordination.git" ]
  [ "$(coord_resolve_coordination_remote 'ssh://explicit')" = "ssh://explicit" ]

  [ "$(coord_resolve_repo_id backend-api "$coord_dir")" = "backend-api" ]
  PI_COORD_REPO_ID=backend-api
  export PI_COORD_REPO_ID
  [ "$(coord_resolve_repo_id '' "$coord_dir")" = "backend-api" ]
  unset PI_COORD_REPO_ID

  alias_output="$(coord_resolve_repo_id '' "$coord_dir" 2>"$tmp/alias.err")"
  [ "$alias_output" = "backend-api" ]
  grep -q "api-old' is an alias" "$tmp/alias.err"

  nested_coord="$project/.pi-env/coordination"
  mkdir -p "$nested_coord/docs"
  git -C "$nested_coord" init -q
  touch "$nested_coord/AGENTS.md" \
    "$nested_coord/docs/SYNC_PROTOCOL.md" \
    "$nested_coord/docs/ITEM_FORMAT.md"
  (
    cd "$nested_coord"
    # shellcheck source=/dev/null
    . "$lib"
    [ "$(coord_project_root)" = "$project" ]
    [ "$(coord_impl_config_path)" = "$project/.pi-coordination.yaml" ]
    [ "$(coord_impl_config_value repo_id)" = "api-old" ]
    [ "$(coord_resolve_repo_id '' "$coord_dir" 2>"$tmp/nested-alias.err")" = "backend-api" ]
    grep -q "api-old' is an alias" "$tmp/nested-alias.err"
  )

  rm .pi-coordination.yaml
  [ "$(coord_resolve_repo_id '' "$coord_dir")" = "remote-api" ]

  git remote remove origin
  if bash -c '. "$1"; coord_resolve_repo_id "" "$2"' bash "$lib" "$coord_dir" >"$tmp/missing.out" 2>"$tmp/missing.err"; then
    echo "missing repo id unexpectedly succeeded" >&2
    exit 1
  fi
  grep -q "pass --repo-id" "$tmp/missing.err"

  if bash -c '. "$1"; coord_resolve_repo_id inactive-api "$2"' bash "$lib" "$coord_dir" >"$tmp/invalid.out" 2>"$tmp/invalid.err"; then
    echo "inactive repo id unexpectedly succeeded" >&2
    exit 1
  fi
  grep -q "is not active" "$tmp/invalid.err"
)
