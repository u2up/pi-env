#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
cd "$repo_root"

# shellcheck source=../../lib/test-helpers.sh
source tests/lib/test-helpers.sh

script=scripts/pi-env-bwrap
prompt_command="$(awk -F"'" '/bwrap_dev_prompt_command=/{print $2; exit}' "$script")"

[ -n "$prompt_command" ] || test_fail 'missing bwrap-dev prompt command setup'

test_grep 'copy_env PS1' "$script"
test_grep 'set_env PROMPT_COMMAND "$bwrap_dev_prompt_command' "$script"

evaluate_interactive_prompt() {
  local initial_ps1="$1"
  PS1="$initial_ps1" PROMPT_COMMAND="$prompt_command" \
    bash --noprofile --norc -i -c 'eval "$PROMPT_COMMAND"; printf "%s" "$PS1"' \
    2>/dev/null
}

actual="$(evaluate_interactive_prompt '(nix-dev) base$ ')"
test_eq '(bwrap-dev) (nix-dev) base$ ' "$actual" \
  'bwrap prompt should compose with inherited nix prompt'

actual="$(evaluate_interactive_prompt '(bwrap-dev) (nix-dev) base$ ')"
test_eq '(bwrap-dev) (nix-dev) base$ ' "$actual" \
  'bwrap prompt should not be duplicated'

PS1='plain$ '
eval "$prompt_command"
test_eq 'plain$ ' "$PS1" 'non-interactive prompt command should be inert'

test_note 'bwrap-dev prompt prefix setup is covered'
