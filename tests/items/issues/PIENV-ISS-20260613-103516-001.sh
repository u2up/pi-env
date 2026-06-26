#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
cd "$repo_root"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

coord_dir="$repo_root/.pi-env/coordination"
if [ ! -d "$coord_dir" ]; then
  coord_dir="$repo_root/coordination"
fi

item_id="PIENV-ISS-20260613-103516-001"
item_path="$(scripts/agent-coord-cat --coord-dir "$coord_dir" --path "$item_id")"
test -f "$coord_dir/$item_path"

test "$(scripts/agent-coord-cat --coord-dir "$coord_dir" "$item_id")" = \
  "$(cat "$coord_dir/$item_path")"
test "$(scripts/agent-coord-cat --coord-dir "$coord_dir" --path "$item_path")" = "$item_path"
test "$(scripts/agent-coord-cat --coord-dir "$coord_dir" --path "${item_id%-001}")" = "$item_path"

if scripts/agent-coord-cat --coord-dir "$coord_dir" MISSING-ITEM \
  >"$tmp/cat-missing.out" 2>"$tmp/cat-missing.err"; then
  printf 'agent-coord-cat unexpectedly found missing item\n' >&2
  exit 1
fi
grep -q '^agent-coord: item not found: MISSING-ITEM$' "$tmp/cat-missing.err"

printf 'PIENV-ISS-20260613-103516-001 passed\n'
