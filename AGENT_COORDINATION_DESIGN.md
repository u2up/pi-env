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
  README.md
  WORKSPACE.md
  projects/
    project-a/
      issues/
        open/
        blocked/
        closed/
      decisions/
      notes/
    project-b/
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

Use project-local `AGENTS.md`, `.pi/skills`, `.pi/prompts`, and `.pi/extensions` for codebase-specific Pi behavior. Keep task state and cross-agent synchronization in the coordination repository.

## 5. Item IDs and state

Use stable IDs in filenames. For high-concurrency agent-created items, prefer timestamp IDs to avoid number allocation races:

```text
<PROJECTKEY>-<YYYYMMDD-HHMMSS>-<slug>.md
```

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
```

With these set, `agent-coord-clone` can infer:

```text
$PI_COORD_ROOT/$PI_COORD_WORKSPACE-coordination.git -> $PI_COORD_DIR
```

## 9. Optional Pi integration

`pi-start` should not mutate coordination state automatically.

Possible safe integrations:

- print a reminder when `./coordination` exists;
- provide a generated or scaffolded `coordination/README.md` with agent instructions;
- provide an optional prompt/context snippet explaining the Git sync protocol;
- allow users to mount/select the coordination repository explicitly when it is outside the project root.

Any automatic claim, close, commit, or push behavior should be opt-in and implemented outside the default `pi-start` path.

## 10. Non-goals

Initial infrastructure should avoid:

- daemons;
- databases;
- non-Git locking services;
- complex dependency solvers;
- automatic background pushes;
- hidden state outside the coordination repository, except local Git clone metadata;
- making `pi-env` itself responsible for deciding what agents should work on.

The value of the design is that humans and agents can inspect, edit, and recover everything with standard Git and text tools.
