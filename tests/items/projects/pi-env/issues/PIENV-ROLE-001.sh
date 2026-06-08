#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd -P)"
"$repo_root/tests/role-manager-schema.sh"
printf 'PIENV-ROLE-001 passed\n'
