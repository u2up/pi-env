#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
cd "$repo_root"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

legacy_public_name="pi""-coordination"
legacy_config_name=".pi""-coordination.yaml"

if git grep -n -- "$legacy_public_name" >"$tmp/legacy-public.out"; then
  cat "$tmp/legacy-public.out" >&2
  printf 'old public coordination package name remains in tracked files\n' >&2
  exit 1
fi

if git grep -n -- "$legacy_config_name" >"$tmp/legacy-config.out"; then
  cat "$tmp/legacy-config.out" >&2
  printf 'old implementation config filename remains in tracked files\n' >&2
  exit 1
fi

grep -q 'pi-env-coordination = piCoordination;' flake.nix
grep -q 'pi-env-coordination-smoke = smokeCheck "pi-env-coordination-smoke"' flake.nix
grep -q 'nix profile install ~/src/pi-env#pi-env-coordination' README.md
grep -q '`pi-env-coordination` contains the Git-backed coordination helper commands' \
  designs/nix-runtime.md

if grep -q 'legacy_impl_config' scripts/agent-coord-lib.sh; then
  printf 'legacy implementation config helper remains in agent-coord-lib.sh\n' >&2
  exit 1
fi

if grep -q 'deprecated:' scripts/agent-coord-lib.sh; then
  printf 'config deprecation warning path remains in agent-coord-lib.sh\n' >&2
  exit 1
fi
