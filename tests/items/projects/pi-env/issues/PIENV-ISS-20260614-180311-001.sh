#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd -P)"
cd "$repo_root"
. tests/lib/test-helpers.sh

flake=flake.nix

# mkPiShell derives extra package bin directories with Nix path construction and
# preserves a caller-provided PI_BWRAP_EXTRA_PATH after project-declared tools.
test_grep 'extraPackagePath = pkgs.lib.makeBinPath extraPackages;' "$flake"
test_grep 'export PI_BWRAP_EXTRA_PATH="${extraPackagePath}:$PI_BWRAP_EXTRA_PATH"' "$flake"

# pi-bwrap validates the explicit extra path input before bwrap starts.
test_grep 'PI_BWRAP_EXTRA_PATH' "$flake"
test_grep 'unsafe PI_BWRAP_EXTRA_PATH entry is not absolute' "$flake"
test_grep 'unsafe PI_BWRAP_EXTRA_PATH entry is not an existing directory' "$flake"
test_grep 'unsafe PI_BWRAP_EXTRA_PATH entry outside /nix/store' "$flake"
test_grep 'canonical_extra_path="$(realpath "$extra_path_entry")"' "$flake"
test_grep '/nix/store/\*' "$flake"

# Empty entries are ignored and the final sandbox PATH preserves pi-env runtime
# precedence before validated extras and compatibility command dirs.
test_grep '\[ -n "$extra_path_entry" \] ||' "$flake"
test_grep 'sandbox_path="${runtimePath}"' "$flake"
test_grep 'sandbox_path="$sandbox_path:$validated_extra_path"' "$flake"
test_grep 'sandbox_path="$sandbox_path:/usr/local/bin:/usr/bin:/bin"' "$flake"
test_grep '--setenv PATH "$sandbox_path"' "$flake"

# Documentation surfaces the safe workflow and advanced escape hatch.
test_grep 'Project-specific build and test tools' README.md
test_grep 'gnumake' README.md
test_grep 'canonical `/nix/store` directories' README.md
test_grep 'PI_BWRAP_EXTRA_PATH=/nix/store/.../bin' README.md
test_grep 'does not infer tools from a repository automatically' README.md

# The sandbox still relies on a read-only Nix store rather than binding host
# system command directories to provide project tools.
if grep -q -- '--ro-bind /usr/bin /usr/bin\|--ro-bind /bin /bin' "$flake"; then
  test_fail 'flake binds host /bin or /usr/bin for command exposure'
fi

echo "safe extra Nix tool PATH propagation tests passed"
