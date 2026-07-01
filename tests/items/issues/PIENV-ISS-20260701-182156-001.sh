#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

assert_file() {
  [ -e "$1" ] || { echo "missing expected file: $1" >&2; exit 1; }
}

assert_executable() {
  [ -x "$1" ] || { echo "missing expected executable: $1" >&2; exit 1; }
}

verify_install() {
  local prefix="$1"
  assert_executable "$prefix/bin/pi-env"
  assert_executable "$prefix/bin/pi-start"
  assert_executable "$prefix/bin/pi-bwrap"
  assert_executable "$prefix/bin/bootstrap-coordination"
  assert_executable "$prefix/bin/agent-coord-status"
  assert_executable "$prefix/bin/agent-coord-done"
  assert_executable "$prefix/bin/pi-serial-roles"
  assert_executable "$prefix/bin/pi-env-uninstall"
  [ ! -e "$prefix/bin/agent-coord-lib.sh" ] || { echo "private library installed as command" >&2; exit 1; }
  assert_file "$prefix/share/pi-env/scripts/agent-coord-lib.sh"
  assert_file "$prefix/share/pi-env/pi-skill-templates/agent-coordination/AGENTS.md"
  assert_file "$prefix/share/pi-env/role-manager/package.json"
  assert_file "$prefix/share/pi-env/install-manifest"

  "$prefix/bin/agent-coord-status" --help >/dev/null
  "$prefix/bin/bootstrap-coordination" --help >/dev/null

  grep -q "PI_ENV_COORD_LIB=.*$prefix/share/pi-env/scripts/agent-coord-lib.sh" "$prefix/bin/agent-coord-status"
  grep -q "PI_ENV_COORD_TEMPLATE_DIR=.*$prefix/share/pi-env/pi-skill-templates/agent-coordination" "$prefix/bin/agent-coord-status"
  grep -q "PI_ENV_ROLE_MANAGER_PACKAGE=.*$prefix/share/pi-env/role-manager" "$prefix/bin/pi-start"
}

source_prefix="$tmp/source-prefix"
"$repo_root/scripts/install-non-nix" --prefix "$source_prefix"
verify_install "$source_prefix"
"$source_prefix/bin/pi-env-uninstall"
[ ! -e "$source_prefix/bin/pi-env" ] || { echo "uninstall left pi-env wrapper behind" >&2; exit 1; }
[ ! -e "$source_prefix/share/pi-env" ] || { echo "uninstall left support directory behind" >&2; exit 1; }

archive_root="$tmp/pi-env-release"
mkdir -p "$archive_root"
cp -R "$repo_root/scripts" "$archive_root/scripts"
cp -R "$repo_root/role-manager" "$archive_root/role-manager"
cp -R "$repo_root/pi-skill-templates" "$archive_root/pi-skill-templates"
archive_prefix="$tmp/archive-prefix"
"$archive_root/scripts/install-non-nix" --prefix "$archive_prefix"
verify_install "$archive_prefix"
