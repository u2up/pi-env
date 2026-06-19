#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$repo_root"

./tests/role-manager-commands.sh
./tests/items/PIENV-ISS-20260616-193125-001.sh
