#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd -P)"
"$repo_root/tests/role-manager-package.sh"
printf 'PIENV-ROLE-008 passed\n'
