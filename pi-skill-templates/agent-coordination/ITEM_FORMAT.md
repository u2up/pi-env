# Coordination Item Format

Coordination items are YAML files with chronological event history and
Markdown message bodies. The file content, not Git commit messages, is the
authoritative item record.

## Filename IDs

Use stable IDs in filenames. For high-concurrency agent-created items,
prefer timestamp IDs to avoid number allocation races:

```text
<PROJECTKEY>-<YYYYMMDD-HHMMSS>-<slug>.yaml
```

`PROJECTKEY` should be uppercase alphanumeric text. Project item keys are
stored in `projects/<project>/PROJECT.md` as `item_key`. Workspace-level
item keys are stored in top-level `WORKSPACE.md` as `item_key`.

When `agent-coord-new` needs to derive a key, it uppercases the source name
and removes delimiters, whitespace, slashes, backslashes, pipes, and other
non-alphanumeric characters. Project items derive from the project name;
workspace-level items derive from the workspace directory name.

Example:

```text
PIENV-20260605-143022-document-pi-config.yaml
```

Sequential IDs are acceptable for smaller human-managed repositories:

```text
PIENV-0001-document-pi-config.yaml
```

## YAML structure

Each item stores current state near the top for quick scanning, followed by
append-only `events` and `messages` lists. Messages are Markdown block
strings linked to events.

```yaml
schema: coordination-item/v1
id: PIENV-20260605-143022
type: issue
status: open
project: pi-env
title: Document pi config behavior
owner: null
priority: medium
created: 2026-06-05T14:30:22Z
updated: 2026-06-05T14:30:22Z
closed: null
related: []
current:
  event: evt-0001
  message: msg-0001
events:
  - id: evt-0001
    type: opened
    at: 2026-06-05T14:30:22Z
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

## Events

Events are chronological and define item history. Every meaningful item
change should add one event and one linked message. Use these event types
where possible:

- `opened`: initial item definition;
- `claimed`: ownership claim;
- `blocked`: blocker recorded;
- `reopened`: item returned to active work with the reason or revised
  definition;
- `closed`: closure with implementation references when available;
- `updated`: factual update that is not a state transition;
- `linked`: later addition of implementation, PR, release, or commit refs;
- `superseded`: item replaced by another item.

Actors are explicit in each event:

```yaml
actor:
  id: pi
  role: developer
```

Use `role: null` when no role is active. Do not rely on `git blame` alone
for role attribution; Git history is audit data, while event metadata is the
workflow record.

## Implementation references

Closed or linked events should include structured implementation references:

```yaml
implementation_refs:
  - repo: pi-env
    branch: main
    commit: 32225e01ffebef26b1aeca098e7081ff913066cc
```

Use the long-lived branch that contains the result, normally `main`, and the
full commit hash. If multiple closures or reopenings occur, record each
close/reopen as its own event. Multiple references are allowed on one event.

## Messages

Messages are chronological and read like a dialog between actors. The first
message normally contains the original item definition. Reopen or update
messages may carry revised definitions. Close messages should summarize the
result and point to the implementation refs stored on the same event.

Keep Markdown inside `body: |-` readable as normal Markdown. Do not add a
separate `## Activity` section; that would duplicate the YAML event history.

## Directories and status

Keep open, blocked, and closed work in separate directories and also keep
current status in the YAML field:

```text
issues/open/
issues/blocked/
issues/closed/
```

When closing an issue, use `git mv` into `closed/`, set `status: closed`,
set `closed: <timestamp>`, update `current`, and append a `closed` event
with a linked message and implementation refs where possible.
