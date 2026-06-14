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
grep -F '#### CMD-017' "$stdout_file" >/dev/null
grep -F '#### TEST-031' "$stdout_file" >/dev/null
grep -F '#### CRQ-009' "$stdout_file" >/dev/null
grep -F '#### CRQ-010' "$stdout_file" >/dev/null
grep -F '#### CRQ-010 — Requirement source of truth precedence' "$stdout_file" >/dev/null
grep -F 'projects/<project>/requirements/' "$stdout_file" >/dev/null
grep -F 'one renderable top-level `body: |-` block' "$stdout_file" >/dev/null

sample_requirement="coordination/projects/pi-env/requirements/PIENV-FRQ-20260612-210000-001.yaml"
grep -F 'body: |-' "$sample_requirement" >/dev/null
if grep -E '^(current|events|messages):' "$sample_requirement" >/dev/null; then
  echo "active requirement item still contains embedded history" >&2
  exit 1
fi

for heading in \
  '### 3.2 Flake and package requirements' \
  '## 4. Quality requirements' \
  '## 5. Constraint requirements'
do
  if [ "$(grep -F -c "$heading" "$stdout_file")" != 1 ]; then
    echo "generated requirements should render heading exactly once: $heading" >&2
    exit 1
  fi
done

if grep -F 'functional/quality/constraint requirement tests' "$stdout_file" >/dev/null; then
  echo "generated requirements contain stale class-specific test text" >&2
  exit 1
fi
if grep -F 'functional/quality/constraint requirement items' "$stdout_file" >/dev/null; then
  echo "generated requirements contain stale class-specific item text" >&2
  exit 1
fi

if grep -F 'message: msg-0002' "$stdout_file" >/dev/null || grep -F 'events:' "$stdout_file" >/dev/null; then
  echo "generated requirements leaked coordination YAML structure" >&2
  exit 1
fi

for key in UC-001 UC-023 FLAKE-001 CMD-016 CMD-017 TEST-031 CRQ-009 CRQ-010; do
  grep -F "#### $key" REQUIREMENTS.md >/dev/null
  grep -F "#### $key" "$stdout_file" >/dev/null
done

