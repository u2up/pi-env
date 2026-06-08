# Coordination Item Format

Coordination items are YAML files with chronological event history and
Markdown message bodies. The file content, not Git commit messages, is the
authoritative item record.

## Filename IDs

New items use ID-only filenames. The filename stem must match the YAML `id`:

```text
<PROJECTKEY>-<TYPECODE>-<YYYYMMDD-HHMMSS>-<NNN>.yaml
```

Examples:

```text
PIENV-ISS-20260607-204155-001.yaml
PIENV-REQ-20260607-204155-002.yaml
```

`PROJECTKEY` is uppercase alphanumeric text. Project item keys are stored in
`projects/<project>/PROJECT.md` as `item_key`. Workspace-level item keys are
stored in top-level `WORKSPACE.md` as `item_key`.

`TYPECODE` is an uppercase item-type abbreviation. Built-in mappings are:

- `ISS`: `issue`;
- `REQ`: `requirement`;
- `DEC`: `decision`;
- `NOTE`: `note`.

For custom types, use a short uppercase alphanumeric code derived from the
custom type. The timestamp is UTC. `NNN` is a three-digit collision/order
suffix for that exact timestamp and starts at `001`. It is not a global
sequence number.

When `agent-coord-new` needs to derive a project key, it uppercases the source
name and removes delimiters, whitespace, slashes, backslashes, pipes, and other
non-alphanumeric characters. Project items derive from the project name;
workspace-level items derive from the workspace directory name. `--id` may
override the whole item ID when a caller needs to preserve or import an ID.

Historical items may keep legacy IDs and slug filenames. Do not rename or
renumber existing items only to satisfy a newer naming convention.

## YAML structure

Each item stores current state near the top for quick scanning, followed by
append-only `events` and `messages` lists. Messages are Markdown block strings
linked to events.

```yaml
schema: coordination-item/v1
id: PIENV-ISS-20260607-204155-001
type: issue
status: open
project: pi-env
title: Document pi config behavior
owner: null
priority: medium
created: 2026-06-07T20:41:55Z
updated: 2026-06-07T20:41:55Z
done: null
closed: null
reviewed: false
verified: false
testable: yes
testability_note: null
related: []
current:
  event: evt-0001
  message: msg-0001
events:
  - id: evt-0001
    type: opened
    at: 2026-06-07T20:41:55Z
    actor:
      id: agent-a
      role: architect
    message: msg-0001
messages:
  - id: msg-0001
    event: evt-0001
    body: |-
      # Document pi config behavior

      ## Context

      Explain host and sandbox Pi configuration behavior.

      ## Acceptance criteria

      - [ ] README explains host `pi config`.
      - [ ] README explains sandbox `pi-bwrap -- config`.
```

## Item types and directories

Issue items use developer-centric status directories:

```text
projects/<project>/issues/open/
projects/<project>/issues/blocked/
projects/<project>/issues/done/
projects/<project>/issues/closed/
workspace/issues/open/
workspace/issues/blocked/
workspace/issues/done/
workspace/issues/closed/
```

Other item types live under their semantic type directory and do not mirror
issue status directories by default:

```text
projects/<project>/requirements/
projects/<project>/decisions/
projects/<project>/notes/
workspace/requirements/
workspace/decisions/
workspace/notes/
```

Projects may define additional type-specific status values, but should avoid
moving test scripts when an item's lifecycle status changes.

## Issue state meanings

- `open`: developer work is available or required.
- `claimed`: developer work is actively owned; keep the file under `open/`.
- `blocked`: developer work is required but cannot proceed yet.
- `done`: developer believes implementation is complete; review and
  verification remain pending until flags say otherwise.
- `closed`: final accepted state after `reviewed: true` and `verified: true`.

New issue items start with `done: null`, `closed: null`, `reviewed: false`,
and `verified: false`. When marking an issue done, use `git mv` into `done/`,
set `status: done`, set `done: <timestamp>`, reset review/verification flags
to false, update `current`, and append a `done` event with a linked message and
implementation refs where possible. When final-closing an issue, use `git mv`
into `closed/`, set `status: closed`, set `closed: <timestamp>`, update
`current`, and append a `closed` event.

## Testability and test linkage

Every item should declare whether it requires a directly item-matched test:

```yaml
testable: yes
testability_note: null
```

or:

```yaml
testable: no
testability_note: 'Documentation-only; verified by review.'
```

Use `testable: yes` when the item should have a project-repository test script
whose filename stem exactly matches the item ID. Use `testable: no` only with a
short rationale, for example documentation-only work, a policy decision, a
legacy closed item predating this convention, or coverage by another explicitly
named requirement item.

Executable item tests live in the project repository, not the coordination
repository. Project item tests mirror the project and item-type path, but not
issue status directories:

```text
tests/items/projects/<project>/issues/<item-id>.sh
tests/items/projects/<project>/requirements/<item-id>.sh
tests/items/workspace/issues/<item-id>.sh
```

Examples:

```text
coordination/projects/pi-env/issues/closed/PIENV-ISS-20260607-204155-001.yaml
tests/items/projects/pi-env/issues/PIENV-ISS-20260607-204155-001.sh

coordination/projects/pi-env/requirements/PIENV-REQ-20260607-204155-001.yaml
tests/items/projects/pi-env/requirements/PIENV-REQ-20260607-204155-001.sh
```

A verification event should record the exact test command(s) and result. The
test script itself should remain in the project repo so it evolves with the
code commit it verifies.

## Events

Events are chronological and define item history. Every meaningful item change
should add one event and one linked message. Use these event types where
possible:

- `opened`: initial item definition;
- `claimed`: ownership claim;
- `blocked`: blocker recorded;
- `reopened`: item returned to active work with the reason or revised
  definition;
- `done`: developer work completed and ready for review/verification;
- `reviewed`: independent review passed;
- `review_failed`: independent review failed and developer work reopened;
- `verified`: tester or automation verification passed;
- `verification_failed`: verification failed and developer work reopened;
- `closed`: final acceptance after done, reviewed, and verified;
- `updated`: factual update that is not a state transition;
- `linked`: later addition of implementation, PR, release, test, or commit
  refs;
- `superseded`: item replaced by another item.

Actors are explicit in each event:

```yaml
actor:
  id: pi
  role: developer
```

Use `role: null` when no role is active. Do not rely on `git blame` alone for
role attribution; Git history is audit data, while event metadata is the
workflow record.

## Implementation references

Done or linked events should include structured implementation references:

```yaml
implementation_refs:
  - repo: pi-env
    branch: main
    commit: 32225e01ffebef26b1aeca098e7081ff913066cc
```

Use the long-lived branch that contains the result, normally `main`, and the
full commit hash. If multiple done/review/verify/reopen cycles occur, record
each transition as its own event. Multiple references are allowed on one event.

## Messages

Messages are chronological and read like a dialog between actors. The first
message normally contains the original item definition. Reopen or update
messages may carry revised definitions. Done messages should summarize the
implementation and point to the implementation refs stored on the same event.
Review and verification messages should record pass/fail evidence, including
commands run for item-matched tests where applicable.

Keep Markdown inside `body: |-` readable as normal Markdown. Do not add a
separate `## Activity` section; that would duplicate the YAML event history.
