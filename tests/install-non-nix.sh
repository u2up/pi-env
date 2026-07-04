#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
workdir="$(mktemp -d)"
cleanup() {
  rm -rf "$workdir"
}
trap cleanup EXIT

assert_file() {
  local path="$1"
  [ -f "$path" ] || { echo "missing expected file: $path" >&2; exit 1; }
}

# Local payload installs must work without remote bootstrap options or network.
local_prefix="$workdir/local-prefix"
"$repo_root/scripts/install-non-nix" --prefix "$local_prefix"
assert_file "$local_prefix/bin/pi-env"
assert_file "$local_prefix/bin/agent-coord-repo"
assert_file "$local_prefix/share/pi-env/install-manifest"
[ ! -f "$local_prefix/share/pi-env/install-origin" ] || {
  echo "local install unexpectedly wrote remote origin metadata" >&2
  exit 1
}

# Build an archive-style payload and run a detached installer copy so no local
# payload can be discovered beside the script.
archive_root="$workdir/archive-root/pi-env-main"
mkdir -p "$archive_root"
cp -R "$repo_root/scripts" "$archive_root/scripts"
cp -R "$repo_root/role-manager" "$archive_root/role-manager"
cp -R "$repo_root/pi-skill-templates" "$archive_root/pi-skill-templates"
archive="$workdir/pi-env-main.tar.gz"
tar -czf "$archive" -C "$workdir/archive-root" pi-env-main

remote_script_dir="$workdir/remote-script"
mkdir -p "$remote_script_dir"
cp "$repo_root/scripts/install-non-nix" "$remote_script_dir/install-non-nix"
remote_prefix="$workdir/remote-prefix"
(
  cd "$workdir"
  "$remote_script_dir/install-non-nix" \
    --prefix "$remote_prefix" \
    --ref main \
    --repo test-owner/test-repo \
    --artifact-url "file://$archive"
)

assert_file "$remote_prefix/bin/pi-env"
assert_file "$remote_prefix/bin/agent-coord-repo"
assert_file "$remote_prefix/share/pi-env/install-origin"
grep -qx 'repository=test-owner/test-repo' "$remote_prefix/share/pi-env/install-origin"
grep -qx 'ref=main' "$remote_prefix/share/pi-env/install-origin"
grep -qx "artifact_url=file://$archive" "$remote_prefix/share/pi-env/install-origin"
grep -q '^sha256=' "$remote_prefix/share/pi-env/install-origin"
grep -qx "$remote_prefix/share/pi-env/install-origin" "$remote_prefix/share/pi-env/install-manifest"

# Uninstall must be driven by installed state only. Remove source/archive inputs
# before invoking the installed wrapper.
rm -rf "$remote_script_dir" "$archive" "$archive_root"
"$remote_prefix/bin/pi-env-uninstall"
[ ! -e "$remote_prefix/bin/pi-env" ] || {
  echo "pi-env wrapper survived uninstall" >&2
  exit 1
}
[ ! -e "$remote_prefix/share/pi-env/install-origin" ] || {
  echo "origin metadata survived uninstall" >&2
  exit 1
}

printf 'install-non-nix tests passed\n'
