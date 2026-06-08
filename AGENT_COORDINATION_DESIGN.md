# Agent Coordination Repository Design

This document describes a proposed optional `pi-env` layer for creating and maintaining Git-backed agent coordination repositories.

The goal is to make multi-agent workspaces easy to establish while keeping synchronization plain, inspectable, and tool-independent: Git plus YAML item files with Markdown message bodies.

## 1. Concept

An agent coordination repository is a dedicated Git repository that stores shared agent state for a workspace:

- issues;
- tasks and TODOs;
- bugs;
- decisions;
- notes;
- chronological agent event histories;
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

The coordination repositories themselves should remain normal Git repositories containing plain text: YAML coordination items, Markdown message bodies, and small metadata files.

## 3. Coordination domains

Use this rule:

```text
one bare coordination repo == one coordination domain
```

A coordination domain is usually one workspace. If several projects are related and agents need to coordinate across them, use one workspace-level coordination repository with per-project directories.

If workspaces are unrelated, use separate bare coordination repositories.

Example:

```text
/workspace/agent-remotes/
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
        done/
        closed/
      decisions/
      notes/
    project-b/
      PROJECT.md
      issues/
        open/
        blocked/
        done/
        closed/
      decisions/
      notes/
  workspace/
    issues/
      open/
      blocked/
      done/
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

Use stable ID-only filenames. New items use type-coded timestamp IDs to avoid
number allocation races while preserving creation-time information:

```text
<PROJECTKEY>-<TYPECODE>-<YYYYMMDD-HHMMSS>-<NNN>.yaml
```

`PROJECTKEY` should be uppercase alphanumeric text. Built-in type codes are
`ISS` for issue, `REQ` for requirement, `DEC` for decision, and `NOTE` for
note. `NNN` is a three-digit collision/order suffix for the exact UTC
timestamp and starts at `001`. Project item keys are stored in
`projects/<project>/PROJECT.md` as `item_key`. Workspace-level item keys are
stored in top-level `WORKSPACE.md` as `item_key`.

Default key resolution for `agent-coord-new` should be:

1. explicit `--project-key`;
2. stored `item_key` in `projects/<project>/PROJECT.md` or `WORKSPACE.md`;
3. `PI_COORD_PROJECT_KEY` when no stored key exists;
4. derive from `--project` / `PI_COORD_PROJECT` for project items;
5. derive from the workspace directory for workspace-level items.

Derived keys are uppercased and all delimiters, whitespace, pipes, slashes,
backslashes, and other non-alphanumeric characters are removed.

Examples:

```text
PIENV-ISS-20260605-143022-001.yaml
PIENV-REQ-20260605-143022-002.yaml
```

Historical items may keep legacy IDs and slug filenames. Do not rename or
renumber existing items only to satisfy a newer naming convention.

Each item should be a YAML file with top-level current state, chronological
events, and Markdown message bodies linked to those events:

```yaml
schema: coordination-item/v1
id: PIENV-ISS-20260605-143022-001
type: issue
status: open
project: pi-env
title: Document pi config behavior
owner: null
priority: medium
created: 2026-06-05T14:30:22Z
updated: 2026-06-05T14:30:22Z
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

      ## Acceptance criteria

      - [ ] README explains host `pi config`
      - [ ] README explains sandbox `pi-bwrap -- config`
```

Keep issue work in developer-centric state directories and keep current
`status` in the YAML file:

```text
issues/open/
issues/blocked/
issues/done/
issues/closed/
```

Other item types live under semantic type directories such as
`requirements/`, `decisions/`, and `notes/`.

The state names are developer-centric: `open` means developer work is needed,
`blocked` means developer work cannot proceed, `done` means the developer
believes implementation is complete, and `closed` means final acceptance after
review and verification. New items start with `reviewed: false` and
`verified: false`, and declare `testable: yes` or `testable: no` with a
`testability_note` when direct item-matched testing is not required.
Item-matched tests live in the project repository under `tests/items/`, mirror
project/workspace and item type, and match the item ID by filename stem. They
intentionally do not mirror issue status directories.

When marking an issue done, move it with `git mv`, set `status: done`, set
`done:`, reset `reviewed: false` and `verified: false`, update `current:`,
and append a `done` event/message. Done or link events should include
structured implementation refs when possible: `repo: pi-env`, `branch: main`,
and the full `commit` hash. When final-closing an issue after review and
verification, move it to `closed/`, set `status: closed`, set `closed:`, and
append a final `closed` event/message.

## 6. Git synchronization protocol

Agents should use a simple protocol:

```text
1. pull/rebase before reading or selecting work;
2. claim one item by editing current YAML fields;
3. append a claimed event and linked Markdown message;
4. commit and push the claim immediately;
5. do project work in the relevant project clone;
6. pull/rebase the coordination repo again;
7. append progress, link, result, or status events/messages;
8. commit and push immediately.
```

Example claim flow:

```bash
cd coordination
git pull --rebase
# edit item: status: claimed, owner: agent-a, current: evt-0002/msg-0002
# append a claimed event and message
path=projects/pi-env/issues/open/PIENV-ISS-20260605-143022-001.yaml
git add "$path"
git commit -m "Claim PIENV-ISS-20260605-143022-001"
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
bootstrap-coordination
                      infer defaults and initialize via agent-coord-init
agent-coord-init      create a local bare coordination remote
agent-coord-clone     clone a coordination remote into the current workspace
agent-coord-status    show sync status and current open/claimed items
agent-coord-list      list issues, decisions, or requirements by status
agent-coord-pull      run git pull --rebase in the coordination clone
agent-coord-push      commit/push coordination changes
agent-coord-new       create a new templated item
agent-coord-lint      lint item IDs, status, and item-matched tests
agent-coord-claim     claim an item
agent-coord-done      mark developer work done and move it to done/
agent-coord-review    mark review pass/fail and reopen on failure
agent-coord-verify    mark verification pass/fail and reopen on failure
agent-coord-close     final-close a reviewed and verified done item
agent-coord-upgrade-rules
                      preview/apply rule template updates
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
PI_COORD_ROOT=/workspace/agent-remotes # where bare coordination remotes live
PI_COORD_WORKSPACE=piws                # coordination domain/workspace id
PI_COORD_DIR=coordination              # clone directory in each workspace
PI_COORD_AGENT_ID=agent-a              # agent identity for item ownership/events
PI_COORD_ROLE=architect                # optional active role for role-aware commits
PI_COORD_PROJECT_KEY=PIENV             # optional generated item ID prefix
```

`bootstrap-coordination` can print and apply inferred values for these
variables when they are not already set, including when pointed at another
project/workspace with `--project-root`. If the coordination clone already
exists but the planned local bare remote is missing or empty, it can restore
that remote from committed clone history without changing item state. With
these set, `agent-coord-clone` can infer:

```text
$PI_COORD_ROOT/$PI_COORD_WORKSPACE-coordination.git -> $PI_COORD_DIR
```

When `PI_COORD_ROOT` is unset, helpers should prefer a project-visible
`agent-remotes` directory. Inside the pi-env sandbox, or when `/workspace`
resolves to the current project root, that default should be
`/workspace/agent-remotes` so the same bare remote is usable from inside
and outside Bubblewrap. `pi-bwrap` should auto-bind host
`/workspace/agent-remotes` at that same sandbox path when it exists and is
not already part of the selected project mount.

### 8.1 Optional role-aware identity

If a role-template extension is active, coordination helpers may use
`PI_COORD_ROLE` or an explicit `--role ROLE` option to make coordination
actions attributable to the role that performed them. Item events store the
agent ID and role explicitly; helper Git commits can still use an effective
actor such as `pi/architect` through per-command identity overrides such
as:

```bash
git -c user.name=pi/architect \
    -c user.email=pi+architect@coordination.local \
    commit -m "Claim PIENV-ISS-20260605-143022-001"
```

Role-aware identity should apply to the coordination repository only. It should
not change project repository Git identity unless the user explicitly opts in.
`pi-start` must still avoid automatic claims, closes, commits, or pushes.

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
2. Pull/rebase before inspecting, selecting, creating, claiming, blocking, marking done, reviewing, verifying, closing, or otherwise modifying items.
3. Commit and push coordination changes immediately after changing shared state.
4. Never force-push, rewrite public history, delete done or closed items, or renumber item IDs.
5. Prefer one claimed item per agent unless explicitly instructed otherwise.
6. Do not edit another agent's claimed item except to resolve a Git conflict, add clearly relevant factual information, or when workspace rules define it as stale/abandoned.
7. Record all meaningful state transitions as chronological item events with linked Markdown messages.
8. Link developer-completed work to concrete structured implementation refs with `repo`, `branch`, and full `commit` fields.
9. Keep coordination changes small and reviewable.
10. Keep all Git commit, tag, and other Git message text readable in standard terminals: subject/summary lines should be at most 72 characters, and body paragraphs should be hard-wrapped at 72 characters where practical.
11. If a push/rebase conflict occurs, resolve it conservatively and preserve both agents' factual updates when possible.

### 9.2 Item manipulation rules

Agents should use these state transitions:

- create: add a new YAML item under `issues/open/` or the appropriate typed directory, with `reviewed: false`, `verified: false`, and an `opened` event/message;
- claim: set `status: claimed`, set `owner: <agent-id>`, update `current:`, append a `claimed` event/message, commit, push;
- block: move to `blocked/` when needed, set `status: blocked`, document blocker and owner expectations in a `blocked` event/message;
- resume/unblock: move back to `open/` or keep claimed if the same agent continues, and append `reopened` or `updated` history;
- done: use `git mv` into `done/`, set `status: done`, set `done: <timestamp>`, reset `reviewed: false` and `verified: false`, append a `done` event/message with structured implementation refs;
- review pass/fail: set `reviewed: true` on pass, or move back to `open/` and append a `review_failed` event on failure;
- verify pass/fail: set `verified: true` on pass, or move back to `open/` and append a `verification_failed` event on failure;
- close: after `status: done`, `reviewed: true`, and `verified: true`, use `git mv` into `closed/`, set `status: closed`, set `closed: <timestamp>`, and append a final `closed` event/message;
- split: create new linked items and mark the relationship in `related:` / `split_from:` fields and an `updated` event;
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
2. Inspect open/claimed/blocked/done YAML items relevant to the current workspace/project.
3. Claim at most one item unless instructed otherwise.
4. Commit and push immediately after claiming or changing status.
5. Do project work in the project repository.
6. Return to the coordination repo, pull/rebase, mark developer-completed work as done with results and implementation refs, then commit and push.
7. Reviewers and testers update `reviewed` and `verified` flags on done items; failures reopen developer work.
8. Move items to closed only after they are done, reviewed, and verified.

## Safety rules

- Never force-push.
- Never rewrite coordination history.
- Never renumber IDs.
- Never delete done or closed items.
- Keep Git commit/tag message subject lines at or below 72 characters and hard-wrap body text at 72 characters where practical.
- Preserve other agents' factual updates during conflict resolution.
- Do not weaken unrelated previously passing tests to make a new done item pass verification.
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

Any automatic claim, mark-done, review, verify, close, commit, or push behavior should be opt-in and implemented outside the default `pi-start` path.

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
