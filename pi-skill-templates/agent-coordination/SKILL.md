# Agent Coordination

Use this skill when working in a workspace that contains a Git-backed agent
coordination repository, when asked to find, claim, or update work, or
before making changes that affect shared agent state.

## Coordination repository

The coordination repository is the only synchronization source for agent
task state. Find it at `./coordination` unless the user, environment, or
workspace rules say otherwise.

## Required protocol

1. `cd coordination && git pull --rebase` before reading or modifying
   coordination state.
2. Inspect open, claimed, and blocked YAML items relevant to the current
   workspace or project.
3. Claim at most one item unless instructed otherwise.
4. When an active role is in effect, preserve it for coordination helpers
   with `--role ROLE` or `PI_COORD_ROLE=ROLE`; item events should store the
   actor ID and role explicitly.
5. Commit and push immediately after claiming or changing status.
6. Do project work in the project repository.
7. Return to the coordination repo, pull/rebase, update the item with a new
   event/message and implementation refs, then commit and push.

## Item keys

Use stored `item_key` metadata when creating items. Project item keys live
in `projects/<project>/PROJECT.md`; workspace-level item keys live in
`WORKSPACE.md`. Do not invent or silently change keys.

## Item history

Coordination items are YAML files. Top-level fields show current state;
chronological `events:` entries define the authoritative history; linked
`messages:` entries contain Markdown text. Do not add a separate
`## Activity` section.

For completed work, prefer structured implementation refs:

```yaml
implementation_refs:
  - repo: pi-env
    branch: main
    commit: 32225e01ffebef26b1aeca098e7081ff913066cc
```

## Safety rules

- Never force-push.
- Never rewrite coordination history.
- Never renumber IDs.
- Never delete closed items.
- Keep Git commit or tag subject lines at or below 72 characters and
  hard-wrap body text at 72 characters where practical.
- Preserve other agents' factual updates during conflict resolution.
- Ask the user when ownership, stale claims, or conflicts are ambiguous.

This skill complements, but does not replace, `coordination/AGENTS.md`. If
these files differ, the checked-in coordination repository rules win.
