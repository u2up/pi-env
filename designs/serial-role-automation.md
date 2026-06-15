# Serial Role Automation Design

This document describes the first, deliberately small automation step for
running the developer, reviewer, and tester roles over one project checkout and
one coordination checkout.

## Covers

| Requirement | Coordination item |
|-------------|-------------------|
| UC-024 | PIENV-FRQ-20260615-175835-001 |
| CMD-020 | PIENV-FRQ-20260615-175837-001 |
| AGENT-016 | PIENV-FRQ-20260615-175838-001 |
| CRQ-013 | PIENV-CRQ-20260615-175840-001 |
| TEST-032 | PIENV-QRQ-20260615-175842-001 |

## Goal

Provide a serial automation mode that repeatedly checks the Git-backed
coordination repository, selects one eligible issue, runs one fresh Pi job in
the appropriate role, and then returns to polling. The first implementation
uses one mutable project clone and one coordination clone. It does not spawn
parallel terminals, tmux panes, or separate worktrees.

The serial mode is intended to prove the workflow and prompts before adding
parallel role workers with per-role clones or worktrees.

## Non-goals

- No parallel developer/reviewer/tester execution in the first version.
- No tmux dependency.
- No cross-process Git locking beyond a local single-run lockfile.
- No reviewer/tester lease protocol yet; the serial orchestrator is the only
  worker using the clone.
- No hidden database or queue outside the coordination repository.
- No automatic selection of requirement, decision, or note work; the loop
  handles issue lifecycle work only.

## Execution model

Run a single long-lived shell orchestrator from the project root:

```text
serial orchestrator
  -> pull/rebase coordination
  -> select one tester, reviewer, or developer item
  -> launch one fresh pi-env job for that role and item
  -> wait for completion
  -> repeat
```

The orchestrator, not Pi, owns the idle polling loop. Pi is invoked only when
there is a concrete item to process. Each issue-related job is a new Pi session
by invoking `pi-env --raw -- ...` without `--continue`.

## Role priority

Prefer draining downstream work before starting more development:

1. tester: done issues with `reviewed: true` and `verified: false`;
2. reviewer: done issues with `reviewed: false`;
3. developer: open issues.

This keeps completed developer work from piling up unreviewed or unverified.
If no item exists for any role, the orchestrator sleeps and polls again.

## Work selection

Initial selection can use existing helpers:

```bash
next_developer_item() {
  scripts/agent-coord-list issues open | head -n1 | cut -f1
}

next_reviewer_item() {
  scripts/agent-coord-list issues done |
    awk -F'\t' '$3 ~ /reviewed:false/ { print $1; exit }'
}

next_tester_item() {
  scripts/agent-coord-list issues done |
    awk -F'\t' '$3 ~ /reviewed:true/ && $3 ~ /verified:false/ { print $1; exit }'
}
```

A later implementation may replace this duplicated shell parsing with an
`agent-coord-next` helper, but that is not required for the serial MVP.

## Repository safety checks

Before every Pi job the orchestrator should:

- hold a local lock, for example `flock .pi-serial-roles.lock`, so two serial
  workers cannot accidentally run in the same clone;
- pull/rebase coordination before inspecting or mutating items;
- ensure the project working tree is clean unless the previous role job left a
  documented failure state that the user must resolve;
- ensure the coordination working tree is clean except during an intentional
  helper mutation;
- stop rather than auto-reset, auto-stash, or discard project changes.

Developer jobs must commit implementation changes before marking an item done
and must pass a structured implementation ref to `agent-coord-done` when
possible. Reviewer and tester jobs should review or verify committed project
state, not uncommitted leftovers.

## Pi invocation

The orchestrator should render a role-specific prompt that names exactly one
item and says not to select other work. The prompt should tell the role to use
sandbox-visible coordination helpers for lifecycle transitions. Packaged runs
can expose the helper directory with
`PI_BWRAP_EXTRA_PATH`; source-checkout runs should name paths under the mounted
`/workspace` when the helpers live in the project checkout:

- developer: `agent-coord-claim` before work, then `agent-coord-done` with
  implementation refs after project commits;
- reviewer: `agent-coord-review --pass` or `agent-coord-review --fail`;
- tester: `agent-coord-verify --pass` or `agent-coord-verify --fail`;
- optional final close may be configurable and should only run after both
  review and verification have passed.

Because `pi-bwrap` clears the environment, role activation through environment
variables requires explicit pass-through when used. A safe invocation shape is:

```bash
PI_BWRAP_PASS_ENV=PI_ACTIVE_ROLE \
PI_ACTIVE_ROLE="$role" \
PI_COORD_ROLE="$role" \
PI_COORD_AGENT_ID="$agent_id" \
PI_BWRAP_COORDINATION_DIR="$coordination_dir" \
pi-env --raw -- \
  -e "$PI_ENV_ROLE_MANAGER_PACKAGE" \
  --tools read,bash,edit,write,grep,find,ls \
  -p "$prompt"
```

The important properties are: no `--continue`, one item in the prompt, active
role context, and a mounted/writable coordination checkout.

## Failure behavior

The orchestrator should fail closed:

- if `git pull --rebase` fails, sleep and retry or stop with a clear message;
- if a Pi job exits non-zero, record enough log context for the human and do
  not start another item until the project and coordination trees are clean;
- if developer work leaves the project dirty without a commit, stop;
- if reviewer/tester finds a failure, use the coordination helper failure path
  to reopen developer work instead of editing item status by hand;
- never force-push or rewrite coordination history.

## Migration to parallel workers

Once the serial orchestrator is stable, the same selection and role prompts can
be reused by parallel workers. Parallel mode should first move to per-role or
per-item clones/worktrees and add reviewer/tester lease claims before allowing
multiple workers to act concurrently.
