#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
cd "$repo_root"

# shellcheck source=../../lib/test-helpers.sh
source tests/lib/test-helpers.sh

pienv=scripts/pienv
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

bash "$pienv" --help >"$tmpdir/help.out"
test_grep 'pienv recipe flake-agent-shell' "$tmpdir/help.out"
test_grep 'recipe              Print non-mutating integration recipes' "$tmpdir/help.out"

bash "$pienv" help recipe >"$tmpdir/recipe-help.out"
test_grep 'flake-agent-shell  Print the canonical non-mutating flake .#agent shell recipe' "$tmpdir/recipe-help.out"
test_grep 'Recipes only print guidance. They do not modify project files.' "$tmpdir/recipe-help.out"

bash "$pienv" recipe flake-agent-shell >"$tmpdir/recipe.out"
test_grep 'pienv recipe flake-agent-shell' "$tmpdir/recipe.out"
test_grep 'does not read, edit, or write project files' "$tmpdir/recipe.out"
test_grep 'pi-env.url = "git+file:///home/me/src/pi-env";' "$tmpdir/recipe.out"
test_grep '# pi-env.url = "github:u2up/pi-env";' "$tmpdir/recipe.out"
test_grep 'outputs = { self, nixpkgs, flake-utils, pi-env, ... }:' "$tmpdir/recipe.out"
test_grep 'devShells.${system} = existingDevShells // {' "$tmpdir/recipe.out"
test_grep 'agent = pi-env.lib.mkPiShell {' "$tmpdir/recipe.out"
test_grep 'includeCoordinationHelpers = false;' "$tmpdir/recipe.out"
test_grep 'extraPackages = with pkgs; \[' "$tmpdir/recipe.out"
test_grep 'includeCoordinationHelpers = true;' "$tmpdir/recipe.out"
test_grep 'canonical, copyable helper' README.md
test_grep 'pienv recipe flake-agent-shell' README.md

completion_output="$(bash "$pienv" completion bash)"
grep -q 'recipe' <<< "$completion_output" || test_fail 'expected completion to include recipe namespace'
grep -q 'flake-agent-shell' <<< "$completion_output" || test_fail 'expected completion to include flake-agent-shell recipe'
bash -n <(printf '%s\n' "$completion_output")

test_note 'flake agent-shell recipe command, docs, and completion are covered'
