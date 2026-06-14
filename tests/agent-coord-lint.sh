#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
export PI_ENV_COORD_LIB="$repo_root/scripts/agent-coord-lib.sh"
export PI_ENV_COORD_TEMPLATE_DIR="$repo_root/pi-skill-templates/agent-coordination"
export PATH="$repo_root/scripts:$PATH"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export HOME="$tmp/home"
unset PI_COORD_ROOT PI_COORD_WORKSPACE PI_COORD_DIR PI_COORD_AGENT_ID PI_COORD_PROJECT PI_COORD_PROJECT_KEY PI_COORD_ROLE
mkdir -p "$HOME" "$tmp/project"
git config --global user.name "Coordination Test"
git config --global user.email "coordination-test@example.invalid"

cd "$tmp/project"
agent-coord-init \
  --root "$tmp/remotes" \
  --workspace demo \
  --agent-id agent-a \
  --project pi-env >/dev/null

item_path="$(agent-coord-new \
  --coord-dir coordination \
  --project pi-env \
  --type issue \
  "Lint item-matched tests" | tail -n 1)"
item_id="$(grep '^id: ' "coordination/$item_path" | sed 's/^id: //')"

grep -q '^testable: yes$' "coordination/$item_path"
case "$item_path" in
  projects/pi-env/issues/open/"$item_id".yaml) ;;
  *) printf 'unexpected item path: %s\n' "$item_path" >&2; exit 1 ;;
esac

if agent-coord-lint \
  --coord-dir coordination \
  --project-root . >/dev/null 2>&1; then
  printf 'expected lint to fail for missing item-matched test\n' >&2
  exit 1
fi

mkdir -p tests/items/projects/pi-env/issues
cat >"tests/items/projects/pi-env/issues/$item_id.sh" <<'EOF_TEST'
#!/usr/bin/env bash
set -euo pipefail
printf 'item-matched test placeholder passed\n'
EOF_TEST
chmod +x "tests/items/projects/pi-env/issues/$item_id.sh"

agent-coord-lint \
  --coord-dir coordination \
  --project-root . >/dev/null

if agent-coord-lint \
  --coord-dir coordination \
  --project-root . \
  --require-done-or-closed >/dev/null 2>&1; then
  printf 'expected done-or-closed lint to fail for open issue\n' >&2
  exit 1
fi

requirement_path="$(agent-coord-new \
  --coord-dir coordination \
  --project pi-env \
  --type functional-requirement \
  --testable no \
  --testability-note "Reviewed as a policy requirement." \
  "Lint functional requirement item" | tail -n 1)"
requirement_id="$(grep '^id: ' "coordination/$requirement_path" | sed 's/^id: //')"

case "$requirement_path" in
  projects/pi-env/requirements/"$requirement_id".yaml) ;;
  *) printf 'unexpected requirement path: %s\n' "$requirement_path" >&2; exit 1 ;;
esac
grep -q '^id: PIENV-FRQ-[0-9]\{8\}-[0-9]\{6\}-001$' \
  "coordination/$requirement_path"
grep -q '^status: active$' "coordination/$requirement_path"
grep -q '^body: |-$' "coordination/$requirement_path"
if grep -E '^(current|events|messages):' "coordination/$requirement_path" >/dev/null; then
  printf 'new requirement item should not contain embedded history\n' >&2
  exit 1
fi
cp "coordination/$requirement_path" "$tmp/requirement.clean.yaml"
printf 'current:\n  event: evt-0001\n  message: msg-0001\n' \
  >>"coordination/$requirement_path"
if agent-coord-lint \
  --coord-dir coordination \
  --project-root . >/dev/null 2>&1; then
  printf 'expected lint to fail for requirement with embedded history\n' >&2
  exit 1
fi
cp "$tmp/requirement.clean.yaml" "coordination/$requirement_path"

quality_requirement_path="$(agent-coord-new \
  --coord-dir coordination \
  --project pi-env \
  --type quality \
  --testable no \
  --testability-note "Reviewed as a quality requirement." \
  "Lint quality requirement item" | tail -n 1)"
imported_requirement_path="$(agent-coord-new \
  --coord-dir coordination \
  --project pi-env \
  --type quality \
  --testable no \
  --testability-note "Imported from REQUIREMENTS.md; reviewed as policy." \
  "Lint imported quality requirement" | tail -n 1)"
if agent-coord-lint \
  --coord-dir coordination \
  --project-root . >/dev/null 2>&1; then
  printf 'expected lint to fail for imported requirement without source_refs\n' >&2
  exit 1
fi
printf 'source_refs:\n  - "REQUIREMENTS.md#lint-imported-quality-requirement"\n' \
  >>"coordination/$imported_requirement_path"
imported_note_requirement_path="$(agent-coord-new \
  --coord-dir coordination \
  --project pi-env \
  --type functional-requirement \
  --testable no \
  --testability-note "Imported requirement is review-only for now." \
  "Lint imported note wording" | tail -n 1)"
if agent-coord-lint \
  --coord-dir coordination \
  --project-root . >/dev/null 2>&1; then
  printf 'expected lint to fail for imported requirement note without source_refs\n' >&2
  exit 1
fi
printf 'source_refs:\n  - "USE_CASES.md#lint-imported-note-wording"\n' \
  >>"coordination/$imported_note_requirement_path"
constraint_requirement_path="$(agent-coord-new \
  --coord-dir coordination \
  --project pi-env \
  --type constraint \
  --testable no \
  --testability-note "Reviewed as a constraint requirement." \
  "Lint constraint requirement item" | tail -n 1)"
legacy_requirement_path="$(agent-coord-new \
  --coord-dir coordination \
  --project pi-env \
  --type requirement \
  --testable no \
  --testability-note "Legacy requirement compatibility check." \
  "Lint legacy requirement item" | tail -n 1)"

grep -q '^id: PIENV-QRQ-[0-9]\{8\}-[0-9]\{6\}-001$' \
  "coordination/$quality_requirement_path"
grep -q '^id: PIENV-QRQ-[0-9]\{8\}-[0-9]\{6\}-[0-9]\{3\}$' \
  "coordination/$imported_requirement_path"
grep -q '^id: PIENV-CRQ-[0-9]\{8\}-[0-9]\{6\}-001$' \
  "coordination/$constraint_requirement_path"
grep -q '^id: PIENV-REQ-[0-9]\{8\}-[0-9]\{6\}-001$' \
  "coordination/$legacy_requirement_path"

agent-coord-lint \
  --coord-dir coordination \
  --project-root . >/dev/null

mkdir -p designs scripts
ln -sf "$repo_root/scripts/agent-coord-generate-requirements-coverage" \
  scripts/agent-coord-generate-requirements-coverage
requirement_key="$(grep '^requirement_key: ' "coordination/$requirement_path" | sed 's/^requirement_key: //')"
cat >designs/lint-coverage.md <<EOF_DESIGN
# Lint coverage

## Covers

| Requirement | Coordination item |
|-------------|-------------------|
| $requirement_key | $requirement_id |
EOF_DESIGN
agent-coord-lint \
  --coord-dir coordination \
  --project-root . >/dev/null
sed -i "s/$requirement_id/PIENV-FRQ-20260614-000000-999/" designs/lint-coverage.md
if agent-coord-lint \
  --coord-dir coordination \
  --project-root . >/dev/null 2>&1; then
  printf 'expected lint to fail for stale design Covers item ID\n' >&2
  exit 1
fi
sed -i "s/PIENV-FRQ-20260614-000000-999/$requirement_id/" designs/lint-coverage.md

cat >tests/items/projects/pi-env/issues/ORPHAN-ISS-20260607-204155-001.sh <<'EOF_TEST'
#!/usr/bin/env bash
set -euo pipefail
EOF_TEST
chmod +x tests/items/projects/pi-env/issues/ORPHAN-ISS-20260607-204155-001.sh

if agent-coord-lint \
  --coord-dir coordination \
  --project-root . >/dev/null 2>&1; then
  printf 'expected lint to fail for orphan item-matched test\n' >&2
  exit 1
fi

rm tests/items/projects/pi-env/issues/ORPHAN-ISS-20260607-204155-001.sh
chmod -x "tests/items/projects/pi-env/issues/$item_id.sh"

if agent-coord-lint \
  --coord-dir coordination \
  --project-root . >/dev/null 2>&1; then
  printf 'expected lint to fail for non-executable item-matched test\n' >&2
  exit 1
fi

printf 'agent coordination lint tests passed\n'
