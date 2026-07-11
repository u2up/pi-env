#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/support" "$tmp_dir/bin"
cp "$repo_root/scripts/pienv" "$tmp_dir/support/pienv"
chmod +x "$tmp_dir/support/pienv"

make_stub() {
  local name="$1"
  cat > "$tmp_dir/bin/$name" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
{
  printf 'cmd=%s\n' "$(basename "$0")"
  for arg in "$@"; do
    printf 'arg=%s\n' "$arg"
  done
} > "$PIENV_TEST_LOG"
STUB
  chmod +x "$tmp_dir/bin/$name"
}

for name in \
  pi-env pi-env-shell pi-bwrap bootstrap-coordination \
  agent-coord-init agent-coord-clone agent-coord-status agent-coord-list \
  agent-coord-cat agent-coord-new agent-coord-claim agent-coord-done \
  agent-coord-review agent-coord-verify agent-coord-close agent-coord-pull \
  agent-coord-push agent-coord-lint agent-coord-repo \
  agent-coord-upgrade-rules agent-coord-generate-requirements \
  agent-coord-generate-requirements-coverage pi-serial-roles \
  install-non-nix pi-env-uninstall; do
  make_stub "$name"
done

run_case() {
  local expected="$1"
  shift
  : > "$tmp_dir/log"
  PIENV_TEST_LOG="$tmp_dir/log" PATH="$tmp_dir/bin:$PATH" "$tmp_dir/support/pienv" "$@"
  actual="$(cat "$tmp_dir/log")"
  if [ "$actual" != "$expected" ]; then
    echo "pienv dispatcher mismatch for args: $*" >&2
    echo "expected:" >&2
    printf '%s\n' "$expected" >&2
    echo "actual:" >&2
    printf '%s\n' "$actual" >&2
    exit 1
  fi
}

run_case $'cmd=pi-env'
run_case $'cmd=pi-env\narg=--first' -- --first
run_case $'cmd=pi-env\narg=--foo' run --foo
run_case $'cmd=pi-env\narg=--raw\narg=--\narg=run' raw -- run
run_case $'cmd=pi-env-shell\narg=--runtime\narg=nix' shell --runtime nix
run_case $'cmd=pi-bwrap\narg=--continue' sandbox --continue
run_case $'cmd=pi-bwrap\narg=--shell\narg=--\narg=-l' sandbox shell -- -l
run_case $'cmd=bootstrap-coordination\narg=--help' coord bootstrap --help
run_case $'cmd=agent-coord-status\narg=--repo-id\narg=pi-env' coord status --repo-id pi-env
run_case $'cmd=agent-coord-cat\narg=ITEM-1' coord show ITEM-1
run_case $'cmd=agent-coord-upgrade-rules\narg=--check' coord rules upgrade --check
run_case $'cmd=agent-coord-generate-requirements\narg=--repo-id\narg=pi-env' coord requirements generate --repo-id pi-env
run_case $'cmd=agent-coord-generate-requirements-coverage' coord requirements coverage
run_case $'cmd=pi-serial-roles\narg=--role\narg=developer' roles serial --role developer
run_case $'cmd=install-non-nix\narg=--prefix\narg=/tmp/pienv' install --prefix /tmp/pienv
run_case $'cmd=pi-env-uninstall\narg=--prefix\narg=/tmp/pienv' uninstall --prefix /tmp/pienv
rm "$tmp_dir/bin/pi-env-uninstall"
run_case $'cmd=install-non-nix\narg=--uninstall\narg=--prefix\narg=/tmp/pienv' uninstall --prefix /tmp/pienv

completion_output="$(PATH="$tmp_dir/bin:$PATH" "$tmp_dir/support/pienv" completion bash)"
case "$completion_output" in
  *'complete -F _pienv pienv'*) ;;
  *) echo "pienv completion bash did not print sourceable completion" >&2; exit 1 ;;
esac

help_output="$(PATH="$tmp_dir/bin:$PATH" "$tmp_dir/support/pienv" help)"
case "$help_output" in
  *'pienv coord <command>'* ) ;;
  *) echo "pienv help did not include command namespace" >&2; exit 1 ;;
esac

printf 'pienv dispatcher tests passed\n'
