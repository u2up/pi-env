# Agent Coordination Repository Design

This document describes a proposed optional `pi-env` layer for creating and maintaining Git-backed agent coordination repositories.

The goal is to make multi-agent workspaces easy to establish while keeping synchronization plain, inspectable, and tool-independent: Git plus Markdown files.

## 1. Concept

An agent coordination repository is a dedicated Git repository that stores shared agent state for a workspace:

- issues;
- tasks and TODOs;
- bugs;
- decisions;
- notes;
- agent activity logs;
- cross-project coordination state.

For multi-agent work, the coordination repository is the only synchronization mechanism. Agents pull, edit, commit, and push coordination state just like source code.

For same-machine use, the shared remote can be a local bare Git repository.

## 2. Scope for `pi-env`

`pi-env` should not become a task tracker or database. It can provide optional infrastructure and conventions:

- helper commands for initializing and cloning coordination repositories;
- scaffolding for a standard directory layout;
- simple issue/task templates;
- documented Git synchronization protocol;
- environment variables for selecting a coordination domain;
- optional instructions that tell agents where the coordination repo is and how to sync it.

The coordination repositories themselves should remain normal Git repositories containing plain Markdown and small metadata blocks.

## 3. Coordination domains

Use this rule:

```text
one bare coordination repo == one coordination domain
```

A coordination domain is usually one workspace. If several projects are related and agents need to coordinate across them, use one workspace-level coordination repository with per-project directories.

If workspaces are unrelated, use separate bare coordination repositories.

Example:

```text
~/agent-remotes/
  piws-coordination.git
  client-a-coordination.git
  oss-tools-coordination.git

~/workspaces/
  agent-a/
    piws/
      coordination/
      project-1/
      project-2/
    client-a/
      coordination/
      project-x/

  agent-b/
    piws/
      coordination/
      project-1/
```

## 4. Repository layout

Recommended workspace-level layout:

```text
coordination/
  AGENTS.md
  README.md
  WORKSPACE.md
  docs/
    SYNC_PROTOCOL.md
    ITEM_FORMAT.md
  .pi/
    skills/
      agent-coordination/
        SKILL.md
  projects/
    project-a/
      PROJECT.md
      issues/
        open/
        blocked/
        closed/
      decisions/
      notes/
    project-b/
      PROJECT.md
      issues/
        open/
        blocked/
        closed/
      decisions/
      notes/
  workspace/
    issues/
      open/
      blocked/
      closed/
    decisions/
    architecture/
    cross-project-todos/
  agents/
    agent-a.md
    agent-b.md
```

`AGENTS.md` and `.pi/skills/agent-coordination/SKILL.md` are generated from `pi-env` templates by `agent-coord-init`. After initialization, the copies in the coordination repository are authoritative for that workspace and can be edited/versioned like any other coordination state.

Use project-local `AGENTS.md`, `.pi/skills`, `.pi/prompts`, and `.pi/extensions` for codebase-specific Pi behavior. Keep task state and cross-agent synchronization in the coordination repository.

## 5. Item IDs and state

Use stable IDs in filenames. For high-concurrency agent-created items, prefer timestamp IDs to avoid number allocation races:

```text
<PROJECTKEY>-<YYYYMMDD-HHMMSS>-<slug>.md
```

`PROJECTKEY` should be uppercase alphanumeric text. Project item keys are
stored in `projects/<project>/PROJECT.md` as `item_key`. Workspace-level
item keys are stored in top-level `WORKSPACE.md` as `item_key`.

Default key resolution for `agent-coord-new` should be:

1. explicit `--project-key`;
2. stored `item_key` in `projects/<project>/PROJECT.md` or `WORKSPACE.md`;
3. `PI_COORD_PROJECT_KEY` when no stored key exists;
4. derive from `--project` / `PI_COORD_PROJECT` for project items;
5. derive from the workspace directory for workspace-level items.

Derived keys are uppercased and all delimiters, whitespace, pipes, slashes,
backslashes, and other non-alphanumeric characters are removed.

Example:

```text
PIENV-20260605-143022-document-pi-config.md
```

For smaller human-managed repositories, sequential IDs are also acceptable:

```text
PIENV-0001-document-pi-config.md
```

Each item should repeat the ID and status in frontmatter:

```markdown
---
id: PIENV-20260605-143022
type: issue
status: open
project: pi-env
owner:
priority: medium
created: 2026-06-05T14:30:22Z
updated: 2026-06-05T14:30:22Z
closed:
related: []
---

# Document pi config behavior

## Context

## Acceptance criteria

- [ ] README explains host `pi config`
- [ ] README explains sandbox `pi-bwrap -- config`

## Activity

- 2026-06-05T14:30:22Z agent-a: Created.
```

Separate open and closed work by directory and keep status in frontmatter:

```text
issues/open/
issues/blocked/
issues/closed/
```

When closing an issue, move it with `git mv`, set `status: closed`, and set `closed:`.

## 6. Git synchronization protocol

Agents should use a simple protocol:

```text
1. pull/rebase before reading or selecting work;
2. claim one item by editing its frontmatter;
3. commit and push the claim immediately;
4. do project work in the relevant project clone;
5. pull/rebase the coordination repo again;
6. update progress, links, result, or status;
7. commit and push immediately.
```

Example claim flow:

```bash
cd coordination
git pull --rebase
# edit item: status: claimed, owner: agent-a
git add projects/pi-env/issues/open/PIENV-20260605-143022-document-pi-config.md
git commit -m "Claim PIENV-20260605-143022"
git push
```

If two agents claim the same file, Git push/rebase conflicts become the locking mechanism.

Recommended per-clone Git settings:

```bash
git config pull.rebase true
git config rebase.autoStash true
```

## 7. Proposed `pi-env` helper commands

`pi-env` could expose a small helper CLI or a set of shell commands:

```text
agent-coord-init      create a local bare coordination remote
agent-coord-clone     clone a coordination remote into the current workspace
agent-coord-status    show sync status and current open/claimed items
agent-coord-pull      run git pull --rebase in the coordination clone
agent-coord-push      commit/push coordination changes
agent-coord-new       create a new templated item
agent-coord-claim     claim an item
agent-coord-close     close an item and move it to closed/
```

A minimal first implementation could include only:

```text
agent-coord-init
agent-coord-clone
agent-coord-new
```

Everything else can remain normal Git commands until real usage proves that more automation is needed.

## 8. Proposed environment variables

```bash
PI_COORD_ROOT=~/agent-remotes       # where bare coordination remotes live
PI_COORD_WORKSPACE=piws             # coordination domain/workspace id
PI_COORD_DIR=coordination           # clone directory in each workspace
PI_COORD_AGENT_ID=agent-a           # agent identity for ownership/activity logs
PI_COORD_PROJECT_KEY=PIENV          # optional generated item ID prefix
```

With these set, `agent-coord-clone` can infer:

```text
$PI_COORD_ROOT/$PI_COORD_WORKSPACE-coordination.git -> $PI_COORD_DIR
```

## 9. Coordination rules installed by `agent-coord-init`

Because `pi-env` is a Pi-related project, the default agent rules should be provided as Pi skill templates and scaffolded instructions. The `pi-env` source tree should keep these defaults under a clear template directory such as:

```text
pi-skill-templates/
  agent-coordination/
    SKILL.md
    AGENTS.md
    SYNC_PROTOCOL.md
    ITEM_FORMAT.md
```

`agent-coord-init` should install those templates into a newly initialized coordination repository as at least:

```text
coordination/AGENTS.md
coordination/docs/SYNC_PROTOCOL.md
coordination/docs/ITEM_FORMAT.md
coordination/.pi/skills/agent-coordination/SKILL.md
```

The installed files are the workspace's authoritative rules. `pi-env` templates are only defaults; after initialization, updates to rules should be committed to the coordination repository so all agents receive them via Git.

### 9.1 Required `AGENTS.md` rules

The generated `coordination/AGENTS.md` should instruct agents:

1. Treat the coordination repository as the only shared synchronization source for agent work state.
2. Pull/rebase before inspecting, selecting, creating, claiming, blocking, closing, or otherwise modifying items.
3. Commit and push coordination changes immediately after changing shared state.
4. Never force-push, rewrite public history, delete closed items, or renumber item IDs.
5. Prefer one claimed item per agent unless explicitly instructed otherwise.
6. Do not edit another agent's claimed item except to resolve a Git conflict, add clearly relevant factual information, or when workspace rules define it as stale/abandoned.
7. Record all meaningful state transitions in the item's `## Activity` section.
8. Link completed work to concrete project commits, branches, PRs, or file paths where possible.
9. Keep coordination changes small and reviewable.
10. Keep all Git commit, tag, and other Git message text readable in standard terminals: subject/summary lines should be at most 72 characters, and body paragraphs should be hard-wrapped at 72 characters where practical.
11. If a push/rebase conflict occurs, resolve it conservatively and preserve both agents' factual updates when possible.

### 9.2 Item manipulation rules

Agents should use these state transitions:

- create: add a new Markdown item under `issues/open/` or the appropriate typed directory;
- claim: set `status: claimed`, set `owner: <agent-id>`, append activity, commit, push;
- block: move to `blocked/` when needed, set `status: blocked`, document blocker and owner expectations;
- resume/unblock: move back to `open/` or keep claimed if the same agent continues;
- close: use `git mv` into `closed/`, set `status: closed`, set `closed: <timestamp>`, append result and links;
- split: create new linked items and mark the relationship in `related:` / `split_from:` fields;
- supersede: leave the old item in place, mark `status: closed` or `superseded`, and link to the replacement.

Do not encode important state only in a commit message. The file content must remain understandable from a checkout.

### 9.3 Required Pi skill template

`pi-env` should ship the canonical skill source as `pi-skill-templates/agent-coordination/SKILL.md`. `agent-coord-init` should copy it to `coordination/.pi/skills/agent-coordination/SKILL.md`. A generated skill should look like this in spirit:

```markdown
# Agent Coordination

Use this skill when working in a workspace that contains a Git-backed agent coordination repository, when asked to find/claim/update work, or before making changes that affect shared agent state.

## Coordination repository

The coordination repository is the only synchronization source for agent task state. Find it at `./coordination` unless the user or environment says otherwise.

## Required protocol

1. `cd coordination && git pull --rebase` before reading or modifying coordination state.
2. Inspect open/claimed/blocked items relevant to the current workspace/project.
3. Claim at most one item unless instructed otherwise.
4. Commit and push immediately after claiming or changing status.
5. Do project work in the project repository.
6. Return to the coordination repo, pull/rebase, update the item with results and links, then commit and push.

## Safety rules

- Never force-push.
- Never rewrite coordination history.
- Never renumber IDs.
- Never delete closed items.
- Keep Git commit/tag message subject lines at or below 72 characters and hard-wrap body text at 72 characters where practical.
- Preserve other agents' factual updates during conflict resolution.
- Ask the user when ownership, stale claims, or conflicts are ambiguous.
```

The skill should complement, not replace, `coordination/AGENTS.md`. If they differ, the checked-in coordination repository rules win.

### 9.4 Template ownership and updates

`pi-env` may update its built-in templates over time. Existing coordination repositories should not be silently overwritten. If template upgrade support is added, it should be explicit, diffable, and commit-based, for example:

```bash
agent-coord-upgrade-rules --preview
agent-coord-upgrade-rules
```

## 10. Optional Pi integration

`pi-start` should not mutate coordination state automatically.

Possible safe integrations:

- print a reminder when `./coordination` exists;
- provide generated/scaffolded `coordination/AGENTS.md`, docs, and Pi skill templates through `agent-coord-init`;
- provide an optional prompt/context snippet explaining the Git sync protocol;
- allow users to mount/select the coordination repository explicitly when it is outside the project root.

Any automatic claim, close, commit, or push behavior should be opt-in and implemented outside the default `pi-start` path.

## 11. Non-goals

Initial infrastructure should avoid:

- daemons;
- databases;
- non-Git locking services;
- complex dependency solvers;
- automatic background pushes;
- hidden state outside the coordination repository, except local Git clone metadata;
- making `pi-env` itself responsible for deciding what agents should work on.

The value of the design is that humans and agents can inspect, edit, and recover everything with standard Git and text tools.
