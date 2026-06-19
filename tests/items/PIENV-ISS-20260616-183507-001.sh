#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
"$repo_root/tests/items/PIENV-ISS-20260615-175845-001.sh"
