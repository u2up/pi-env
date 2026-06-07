# Agent Coordination Rules

This repository is the authoritative coordination state for this workspace.

## Required rules

1. Treat this coordination repository as the only shared synchronization
   source for agent work state.
2. Pull/rebase before inspecting, selecting, creating, claiming, blocking,
   closing, or otherwise modifying items.
3. Commit and push coordination changes immediately after changing shared
   state.
4. Never force-push, rewrite public history, delete closed items, or
   renumber item IDs.
5. Prefer one claimed item per agent unless explicitly instructed
   otherwise.
6. Do not edit another agent's claimed item except to resolve a Git
   conflict, add clearly relevant factual information, or when workspace
   rules define it as stale or abandoned.
7. Record every meaningful state transition as a chronological YAML event
   with a linked Markdown message in the item file.
8. Link completed work from close/link events to concrete structured
   implementation references with `repo`, `branch`, and `commit` fields.
9. Keep coordination changes small and reviewable.
10. Keep Git commit, tag, and other Git message text readable in standard
    terminals. Subject or summary lines should be at most 72 characters,
    and body paragraphs should be hard-wrapped at 72 characters where
    practical.
11. If a push or rebase conflict occurs, resolve it conservatively and
    preserve both agents' factual updates when possible.

## Item keys

Use the stored `item_key` for generated coordination item IDs:

- project items use `projects/<project>/PROJECT.md`;
- workspace-level items use top-level `WORKSPACE.md`.

Do not invent, rename, or silently change item keys. If a key is missing,
derive it from the project or workspace directory name by uppercasing it
and removing delimiters and other non-alphanumeric characters, then commit
that key in the appropriate metadata file. Changing an existing `item_key`
requires an explicit workspace decision.

## Item format

Coordination items are YAML files under the status directories. Current
state is stored near the top (`status`, `owner`, `updated`, `closed`, and
`current`), while authoritative history is stored in chronological `events`
and linked Markdown `messages` entries.

Do not add or maintain a separate Markdown `## Activity` section in item
files. It duplicates the event list and will drift.

## State transitions

- Create: add a new YAML item under `issues/open/` or the appropriate typed
  directory, with an `opened` event and initial message.
- Claim: set `status: claimed`, set `owner: <agent-id>`, update
  `updated:` and `current:`, append a `claimed` event and linked message,
  commit, and push.
- Block: move to `blocked/` when needed, set `status: blocked`, document
  blocker details in a `blocked` event/message, commit, and push.
- Resume or unblock: move back to `open/`, or keep claimed if the same
  agent continues the work, and append a `reopened` or `updated` event.
- Close: use `git mv` into `closed/`, set `status: closed`, set
  `closed: <timestamp>`, append a `closed` event/message, and include
  structured implementation refs where possible:
  `repo: pi-env`, `branch: main`, and the full `commit` hash.
- Split: create new linked items and mark the relationship in `related:` or
  `split_from:` fields and an `updated` event.
- Supersede: leave the old item in place, mark it closed or superseded, and
  link to the replacement.

Do not encode important state only in a commit message. The file content
must remain understandable from a checkout.
