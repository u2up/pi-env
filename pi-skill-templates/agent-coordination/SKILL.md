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
2. Inspect open, claimed, and blocked items relevant to the current
   workspace or project.
3. Claim at most one item unless instructed otherwise.
4. Commit and push immediately after claiming or changing status.
5. Do project work in the project repository.
6. Return to the coordination repo, pull/rebase, update the item with
   results and links, then commit and push.

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
