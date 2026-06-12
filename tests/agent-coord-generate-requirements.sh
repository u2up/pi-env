#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

stdout_file="$tmpdir/requirements.stdout.md"
output_file="$tmpdir/requirements.output.md"

scripts/agent-coord-generate-requirements > "$stdout_file"
scripts/agent-coord-generate-requirements --output "$output_file"

if [ "$(sha256sum "$stdout_file" | awk '{print $1}')" != "$(sha256sum "$output_file" | awk '{print $1}')" ]; then
  echo "stdout and --output renderings differ" >&2
  exit 1
fi

grep -F '# pi-env Requirements' "$stdout_file" >/dev/null
grep -F '## 3. Functional requirements' "$stdout_file" >/dev/null
grep -F '## 4. Quality requirements' "$stdout_file" >/dev/null
grep -F '## 5. Constraint requirements' "$stdout_file" >/dev/null
grep -F '#### UC-001' "$stdout_file" >/dev/null
grep -F '#### CMD-004' "$stdout_file" >/dev/null
grep -F '#### TEST-031' "$stdout_file" >/dev/null
grep -F '#### CRQ-009' "$stdout_file" >/dev/null
grep -F 'projects/<project>/requirements/' "$stdout_file" >/dev/null

# The canonical manual document remains the source used to recreate items; the
# generator should preserve its stable public requirement keys even if static
# introductory prose differs.
for key in UC-001 UC-023 FLAKE-001 CMD-016 TEST-031 CRQ-009; do
  grep -F "#### $key" REQUIREMENTS.md >/dev/null
  grep -F "#### $key" "$stdout_file" >/dev/null
done

test -f REQUIREMENTS.legacy.md
test -f USE_CASES.legacy.md
