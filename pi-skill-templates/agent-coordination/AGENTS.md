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
7. Record all meaningful state transitions in the item's `## Activity`
   section.
8. Link completed work to concrete project commits, branches, PRs, or file
   paths where possible.
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

## State transitions

- Create: add a new Markdown item under `issues/open/` or the appropriate
  typed directory.
- Claim: set `status: claimed`, set `owner: <agent-id>`, append activity,
  commit, and push.
- Block: move to `blocked/` when needed, set `status: blocked`, document
  blocker details, commit, and push.
- Resume or unblock: move back to `open/`, or keep claimed if the same
  agent continues the work.
- Close: use `git mv` into `closed/`, set `status: closed`, set
  `closed: <timestamp>`, append result links, commit, and push.
- Split: create new linked items and mark the relationship in `related:` or
  `split_from:` fields.
- Supersede: leave the old item in place, mark it closed or superseded, and
  link to the replacement.

Do not encode important state only in a commit message. The file content
must remain understandable from a checkout.
