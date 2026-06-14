# Verification Strategy Design

Verification combines item-matched tests, blackbox command checks, and review
for documentation-only behavior. The strategy favors executable evidence for
runtime behavior and explicit rationale when a requirement is not directly
executable.

## Covers

| Requirement | Coordination item |
|-------------|-------------------|
| UC-021 | PIENV-FRQ-20260612-210000-021 |
| TEST-001 | PIENV-QRQ-20260612-210000-003 |
| TEST-002 | PIENV-QRQ-20260612-210000-004 |
| TEST-003 | PIENV-QRQ-20260612-210000-005 |
| TEST-004 | PIENV-QRQ-20260612-210000-006 |
| TEST-005 | PIENV-QRQ-20260612-210000-007 |
| TEST-006 | PIENV-QRQ-20260612-210000-008 |
| TEST-007 | PIENV-QRQ-20260612-210000-009 |
| TEST-008 | PIENV-QRQ-20260612-210000-010 |
| TEST-009 | PIENV-QRQ-20260612-210000-011 |
| TEST-010 | PIENV-QRQ-20260612-210000-012 |
| TEST-011 | PIENV-QRQ-20260612-210000-013 |
| TEST-012 | PIENV-QRQ-20260612-210000-014 |
| TEST-013 | PIENV-QRQ-20260612-210000-015 |
| TEST-014 | PIENV-QRQ-20260612-210000-016 |
| TEST-015 | PIENV-QRQ-20260612-210000-017 |
| TEST-016 | PIENV-QRQ-20260612-210000-018 |
| TEST-017 | PIENV-QRQ-20260612-210000-019 |
| TEST-018 | PIENV-QRQ-20260612-210000-020 |
| TEST-019 | PIENV-QRQ-20260612-210000-021 |
| TEST-020 | PIENV-QRQ-20260612-210000-022 |
| TEST-021 | PIENV-QRQ-20260612-210000-023 |
| TEST-022 | PIENV-QRQ-20260612-210000-024 |
| TEST-023 | PIENV-QRQ-20260612-210000-025 |
| TEST-024 | PIENV-QRQ-20260612-210000-026 |
| TEST-025 | PIENV-QRQ-20260612-210000-027 |
| TEST-026 | PIENV-QRQ-20260612-210000-028 |
| TEST-027 | PIENV-QRQ-20260612-210000-029 |
| TEST-028 | PIENV-QRQ-20260612-210000-030 |
| TEST-029 | PIENV-QRQ-20260612-210000-031 |
| TEST-030 | PIENV-QRQ-20260612-210000-032 |
| TEST-031 | PIENV-QRQ-20260612-210000-033 |

## 1. Item-matched tests

Executable issue and requirement checks live under `tests/items/` with paths
that mirror coordination scope and type. A testable item should have a script
whose filename stem matches the item ID. The script is the direct evidence used
by verification.

Non-testable items must explain why executable evidence is not appropriate.
Documentation-only requirements and planning records may be verified by review
when the requested change is fully inspectable in text.

## 2. Blackbox launcher testing

Runtime behavior is verified through blackbox shell tests. Tests invoke public
scripts and inspect observable output, generated files, or fake command logs.
For Bubblewrap-related behavior, fake `bwrap` or fake `pi` binaries let tests
assert the constructed command without needing privileged sandbox execution.

## 3. Coordination lint and coverage checks

Coordination-specific behavior is verified with lint-style checks over YAML
items and repository layout. Design coverage is verified by the coverage
generator, which validates `## Covers` tables against active requirement items.

## 4. Role-manager and smoke tests

Role-manager behavior has focused smoke tests because it crosses CLI parsing,
resource selection, and Pi startup. Those tests should stay narrow enough to be
fast, but broad enough to catch broken role resource imports and launcher
integration.

## 5. Review-only evidence

When a requirement is intentionally documentation-only, verification records the
reviewed files and rationale instead of inventing a weak executable test. This
keeps `TEST-001` through `TEST-031` meaningful: tests should prove behavior,
while review should prove textual policy or design completeness.
