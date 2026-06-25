# Agent Coordination

Use this skill when working in a project that contains a Git-backed agent
coordination repository, when asked to find, claim, or update work, or before
making changes that affect shared agent state. Historical workspace-level
coordination state may exist for compatibility, but new pi-env work is
project-scoped.

## Coordination repository

The coordination repository is the only synchronization source for agent issue,
TODO, and coordination state. For fresh pi-env projects, find it at
`.pi-env/coordination` unless `PI_COORD_DIR`, the user, or project coordination
rules say otherwise. Existing
legacy projects may still use root-level `coordination/`.

## Required protocol

1. `cd "${PI_COORD_DIR:-.pi-env/coordination}" && git pull --rebase` before
   reading or modifying coordination state, or use the `agent-coord-*` helpers
   with their default coordination directory resolution.
2. Inspect open, claimed, blocked, and done YAML issue items relevant to the
   current project. Also inspect related requirement or decision items when
   they affect acceptance criteria.
3. Claim at most one issue item unless instructed otherwise.
4. When an active role is in effect, preserve it for coordination helpers with
   `--role ROLE` or `PI_COORD_ROLE=ROLE`; item events should store the actor ID
   and role explicitly.
5. Commit and push immediately after claiming or changing status.
6. Do project work in the project repository.
7. Return to the coordination repo, pull/rebase, mark developer-completed work
   as `done` with a new event/message and implementation refs, then commit and
   push.
8. Review and verification act on `done` items. Review failures or test
   failures move the item back to `open` with factual failure evidence.
9. Move an item to `closed` only after it is `done`, `reviewed: true`, and
   `verified: true`.

## Item keys and IDs

Use stored `item_key` metadata when creating items. Project-root item keys
live in top-level `PROJECT.md`; legacy project clones may store keys in
`projects/<project>/PROJECT.md`. Top-level `WORKSPACE.md` keys are legacy
compatibility metadata for existing workspace-level items only. Do not invent
or silently change keys.

New item IDs and filenames use:

```text
<PROJECTKEY>-<TYPECODE>-<YYYYMMDD-HHMMSS>-<NNN>.yaml
```

Use `ISS` for issue, `FRQ` for functional requirement, `QRQ` for quality
requirement, `CRQ` for constraint requirement, `TODO` for todo, `DEC` for
decision, and `NOTE` for note. Generic `REQ` requirement IDs are legacy-only
unless an explicit supersession or migration decision says otherwise. The `NNN`
suffix starts at
`001` for each UTC timestamp. Historical items may keep legacy IDs; do not
rename, renumber, rewrite, or move them unless explicitly directed.

`agent-coord-list notes` and `agent-coord-list todos` report note and TODO
items by their YAML `status` values. `agent-coord-list requirements` reports
functional, quality, constraint, and legacy requirement items. Use `functional`,
`quality`, `constraint`, or `legacy-requirements` for class-specific listings.

## Item history

Coordination items are YAML files. Issue item top-level fields show current
state; chronological `events:` entries define authoritative issue history;
linked `messages:` entries contain Markdown text. Requirement and TODO items
are current-state records with one top-level `body: |-` block and no embedded
`current:`, `events:`, or `messages:` sections. State group names are
developer-centric: `open` means developer work is needed, `blocked` means it
cannot proceed yet, `done` means the developer believes implementation is
complete, and `closed` means final acceptance after review and verification. Do
not add a separate `## Activity` section.

For developer-completed work, prefer structured implementation refs on the
`done` event:

```yaml
implementation_refs:
  - repo: pi-env
    branch: main
    commit: 32225e01ffebef26b1aeca098e7081ff913066cc
```

## Testability

Every item should declare `testable: yes` or `testable: no`. If `testable: no`,
include a non-empty `testability_note` explaining why an item-matched test is
not required.

Item-matched tests are executable bash scripts in the project repo, not the
coordination repo. Match the filename stem to the item ID and mirror the
project item path plus item type, not issue status. Legacy workspace-level
items may keep mirrored workspace test paths:

```text
tests/items/<item-id>.sh
tests/items/requirements/<item-id>.sh
tests/items/projects/<project>/issues/<item-id>.sh        # legacy
tests/items/projects/<project>/requirements/<item-id>.sh  # legacy
tests/items/workspace/issues/<item-id>.sh                 # legacy
tests/items/workspace/requirements/<item-id>.sh           # legacy
```

Verification messages should record exact commands and results. When available,
run this from the project root to check item metadata and test linkage:

```bash
agent-coord-lint --coord-dir "${PI_COORD_DIR:-.pi-env/coordination}" --project-root .
```

Use `--require-done-or-closed` for release gates that require all issue items
to be done or closed.

## Safety rules

- Never force-push.
- Never rewrite coordination history.
- Never renumber IDs.
- Never delete done or closed items.
- Keep Git commit or tag subject lines at or below 72 characters and hard-wrap
  body text at 72 characters where practical.
- Preserve other agents' factual updates during conflict resolution.
- Do not weaken unrelated previously passing tests to make a new done item pass
  verification.
- Ask the user when ownership, stale claims, or conflicts are ambiguous.

This skill complements, but does not replace, `coordination/AGENTS.md`. If
these files differ, the checked-in coordination repository rules win.
