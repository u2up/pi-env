# COORDINATION_REPO_PATTERN.md

> **Status:** Draft 0.3
>
> **Author:** Samo Pogačnik <samo_pogacnik@t-2.net>
>
> This document describes the Coordination Repository Pattern independently of
> any specific implementation. It originated during the design of **pi-env**, but
> is intended as a reusable architectural pattern for Git-backed project state.

---

# Coordination Repository Pattern

## Abstract

The Coordination Repository Pattern separates **project coordination state**
from **project implementation state**.

Instead of spreading project goals, requirements, work status, decisions,
assignments, review notes, operational context, and planning history across
issue trackers, chat systems, local notes, automation logs, and source
repositories, these artifacts are maintained in a dedicated Git repository.

The coordination repository becomes a version-controlled source of project
state and its history. Because that state is represented as normal Git content,
humans, scripts, CI jobs, release tooling, and AI-assisted development tools can
all participate through the same reviewable source of truth.

Implementation repositories remain focused on source code and deliverables.

---

## 30-Second Example

A coordination repository owns the durable project-state records:

```text
coordination-repo/
  requirements/     desired behavior and constraints
  decisions/        rationale and trade-offs
  issues/           workflow, ownership, review, verification, acceptance
  release-plans/    release intent and readiness notes
```

The implementation repository remains authoritative for implementation
artifacts:

```text
implementation-repo/
  src/
  tests/
  build/
  docs/
```

Conceptually, the coordination repository owns durable coordination state while
implementation systems own implementation artifacts and execution evidence:

```text
                 Coordination Repository
          (durable project coordination state)

  Requirements --+
  Decisions -----+--> intent, scope, ownership,
  Issues --------+    acceptance, and traceability
  Notes ---------+

           |
           | links to and is supported by
           v

      Implementation Ecosystem

  Implementation repositories: source, tests, build config, docs
  Code review systems: pull requests, reviews, merge state
  CI systems: run results, logs, artifacts
  Release systems: packages, deployments, release evidence
```

A requirement can link to a decision, an issue can link to the requirement, and
the issue can link to source commits, tests, pull requests, or CI evidence
without moving ownership of those artifacts out of the implementation systems.

---

## Motivation

Software projects accumulate important state outside source code:

* goals and scope;
* requirements and constraints;
* architectural decisions;
* active work and ownership;
* review and verification status;
* release intent;
* migration plans;
* operational notes;
* links between work, commits, tests, and decisions.

This state is often fragmented across:

* issue trackers;
* project boards;
* chat systems;
* design documents;
* CI systems;
* code review tools;
* local notes;
* automation memory;
* implementation repositories.

Humans can sometimes mentally integrate these systems. Automation generally
cannot do so reliably, and even human teams lose context over time.

A coordination repository provides a single Git-native place for project state
that should be explicit, attributable, reviewable, and traceable.

Git is especially well-suited to coordination state because it provides durable
history, attribution, branching, merging, review workflows, offline operation,
and portable plain-text storage. Using Git for project state makes these
properties available to coordination data without requiring every participant or
automation tool to depend on one hosted service.

AI agents and other automation increase the need for such state, but they are
not a prerequisite for the pattern. The pattern is useful anywhere project
state deserves the same durability and reviewability as source code.

Agent-centric note: when AI agents participate, the coordination repository
should be treated as the durable communication medium between agents. Important
handoff information should be written to structured Git content rather than
left only in conversation transcripts, hidden memory, or another agent's prompt
context. This keeps context size manageable: each agent can load the small set
of relevant project-state files instead of inheriting an ever-growing session
history.

For example, a coordination repository might contain:

* a requirement file saying CSV export is needed;
* an issue file tracking implementation work;
* a decision file explaining why streaming export was chosen;
* links from the issue to pull request 42, implementation commits, and CI test
  evidence.

---

## Core Principle

> **Source repositories contain implementation state.**
>
> **Coordination repositories contain project state.**

Implementation repositories answer:

* What has been built?
* How is it built, tested, packaged, and released?
* Which source changes realize a behavior?

Coordination repositories answer:

* What is intended?
* Why is it intended?
* What is in progress?
* Who or what is responsible?
* What decisions led here?
* What has been reviewed or accepted?
* Which implementation commits, tests, reviews, or releases support the state?
* What remains unresolved?

This distinction is the foundation of the pattern.

---

## Definitions

### Project state

Within this pattern, project state means durable project coordination state:
information required to understand, coordinate, review, and evolve a project
beyond the implementation artifacts themselves.

Project state includes intent, scope, constraints, decisions, ownership,
lifecycle status, verification, acceptance, planning context, and links to
supporting implementation evidence. It is distinct from source code, tests,
build configuration, packages, and other deliverables, though it often refers to
them.

The pattern does not attempt to model all organizational project-management
state, such as budgeting, staffing, legal approval, contracts, or procurement,
unless a coordination domain explicitly chooses to include those concerns.

### Coordination repository

A Git repository dedicated to project coordination state. It stores artifacts
such as work items, requirements, decisions, plans, status, notes, and project
history.

### Implementation repository

A repository containing source code, configuration, documentation,
infrastructure, tests, packages, or other deliverables.

### Coordination domain

The project, product, migration, release, or operational scope governed by one
coordination repository.

A coordination domain may map to one implementation repository, multiple
implementation repositories, or a non-code project. The pattern does not
require a fixed topology.

### Actor

Any participant that reads or changes coordination state. Actors may be humans,
scripts, CI jobs, release tooling, bots, AI coding agents, or other automation.

### Item

A structured coordination artifact representing a requirement, work item,
decision, note, risk, release task, bug, or other unit of project state.

Implementations may use different item schemas and names. For example, one
implementation may model task-like work as issues with a task category, while
another may use a dedicated task item type.

---

## Project State Concerns

Project state is not one monolithic category. A coordination repository often
organizes several related concerns:

| Concern | Examples |
| --- | --- |
| Intent | Requirements, decisions, goals, and constraints. |
| Execution | Issues, TODOs, ownership, blockers, and active work. |
| Knowledge | Notes, runbooks, operational context, and migration context. |
| Governance | Reviews, verification, acceptance, lifecycle rules, and release readiness. |
| Traceability | Links, evidence, coverage reports, commits, tests, and external records. |

The exact grouping is domain-specific, but making these concerns explicit helps
participants decide what belongs in the coordination repository and how it
relates to implementation artifacts and external systems.

---

## Common Artifact Types

A coordination repository usually combines several kinds of project-state
artifacts. The exact names and schemas are implementation-specific, but the
following conceptual roles are common:

* **Requirement**: desired behavior, quality, constraint, policy, or outcome.
* **Decision**: selected approach plus rationale, alternatives, and trade-offs.
* **Issue**: actionable workflow container with lifecycle, ownership, and
  evidence.
* **TODO**: lightweight reminder or follow-up that does not need the full issue
  lifecycle.
* **Note**: durable contextual information that should remain discoverable.

An issue is not limited to a defect report. More generally, it is an actionable
workflow container: something that coordinates ownership, lifecycle, evidence,
and acceptance for a unit of work, investigation, or inquiry.

Other domains may add risks, incidents, release plans, milestones, runbooks, or
review records. The important property is that each artifact type has a clear
coordination purpose and an explicit relationship to other project state.

---

## Design Goals

A Coordination Repository should be:

### Git-native

No database is required.

Important state is represented as version-controlled artifacts that can be
cloned, branched, committed, pushed, pulled, merged, reviewed, and archived with
standard Git workflows.

### Human-readable

Important project artifacts should be understandable from a checkout without a
specialized service.

Markdown, YAML, TOML, JSON, and plain text are common choices. Rich prose is
useful for context, rationale, acceptance criteria, and review notes.

### Automation-readable

Project state should have enough structure that scripts, CI jobs, release
systems, and AI tools can interpret it consistently.

Free-form prose is valuable, but status, ownership, dependencies, IDs,
relationships, and lifecycle fields should be structured where deterministic
behavior matters.

### Traceable

A reader should be able to answer not only what the current state is, but how
it became that way.

Important state changes should leave an auditable trail linking project intent
to decisions, work items, reviews, tests, implementation commits, releases, or
other evidence.

### Reviewable

Changes to project state deserve the same review discipline as changes to
source code.

Planning, priority, scope, acceptance, and architectural decisions should leave
an inspectable history.

### Distributed

Coordination should work offline and across organizational boundaries.

Participants should be able to clone, branch, merge, and review coordination
state using normal Git tooling.

### Tool-independent

The pattern should not depend on a specific AI model, coding agent, IDE,
hosting platform, issue tracker, CI system, or project management service.

---

## Repository Topology

The coordination repository is logically separate from implementation
repositories, but its working clone may be located wherever is operationally
convenient.

Common topologies include:

```text
project-source/
  src/
  tests/

project-coordination/
  requirements/
  issues/
  decisions/
```

or a nested working clone that is ignored by the implementation repository:

```text
project-source/
  src/
  tests/
  .coordination/        # separate Git repository, ignored by project-source
```

The important boundary is Git ownership and responsibility:

* the implementation repository owns source and deliverables;
* the coordination repository owns project state and coordination history.

A coordination repository may use a hosted remote, a local bare Git remote, or
ordinary peer-to-peer Git exchange. The pattern does not prescribe hosting.

---

## Typical Contents

A coordination repository may include:

* project goals;
* requirements;
* roadmap and milestones;
* backlog and active work;
* ownership and assignment state;
* review and verification records;
* completed and accepted work;
* architectural decisions;
* implementation plans;
* risks and blockers;
* release planning;
* operational notes;
* actor or contributor registry;
* repository catalog;
* synchronization protocol;
* workflow rules;
* generated traceability reports.

The exact layout is implementation-specific.

---

## Item Representation

A practical coordination repository usually combines structured metadata with
human-readable prose.

For example:

```yaml
id: PROJ-ISS-20260625-120000-001
type: issue
status: open
owner: null
priority: medium
created: 2026-06-25T12:00:00Z
updated: 2026-06-25T12:00:00Z
related:
  - PROJ-REQ-20260624-180000-001
body: |-
  # Improve release notes

  ## Context

  Release notes currently omit migration caveats.

  ## Acceptance criteria

  - Release notes mention compatibility behavior.
  - The release checklist links to the updated notes.
```

Other implementations may store event history separately, keep Markdown files
with front matter, use JSON records, or generate summary documents from item
files.

The pattern does not require one schema, but it benefits from stable IDs,
explicit status, clear relationships, and durable links to evidence.

---

## Traceable Project State

Traceability is central to the pattern.

A coordination repository should make it possible to follow relationships such
as:

```text
requirement -> decision -> work item -> implementation commit -> test evidence -> accepted state
```

or:

```text
incident -> mitigation task -> review -> release note -> follow-up decision
```

Not every project needs a formal traceability model, but important state should
not exist only in transient chat messages, local memories, or opaque automation
logs.

Useful traceability practices include:

* stable item IDs;
* links between related items;
* explicit lifecycle fields;
* chronological state-change records;
* references to source repositories, branches, commits, pull requests, test
  runs, release artifacts, or external records;
* generated coverage or status reports derived from source item files.

---

## Synchronization Protocol

Because the coordination repository is a Git repository, Git provides both
synchronization and conflict detection.

A typical protocol is:

1. Pull or rebase before reading, selecting, or changing shared state.
2. Make a small, focused coordination change.
3. Record meaningful state transitions in the coordination artifacts
   themselves, not only in commit messages.
4. Commit with a clear message.
5. Push promptly.
6. Resolve conflicts conservatively, preserving factual updates from all sides
   when possible.
7. Avoid force-pushing or rewriting shared coordination history unless the
   coordination domain has an explicit recovery procedure.

The exact protocol may vary, but coordination state should remain inspectable
from a checkout and recoverable from Git history.

### Concurrent Actors and Semantic Conflicts

Git detects textual conflicts, but coordination state can also have semantic
conflicts. Two actors may claim the same work, a stale owner may block progress,
a generated report may race with a manual edit, or one actor may close work
while another is still updating its requirements.

Coordination domains should define concurrency rules appropriate to their risk
level. Useful practices include:

* claim or lease exclusive work before starting it;
* record actor, role, and timestamp metadata on meaningful state transitions;
* define when ownership is considered stale and how it can be reassigned;
* pull or rebase and re-read relevant items before marking work done, reviewed,
  verified, accepted, or released;
* keep generated files clearly derived from authoritative source records;
* prefer small, prompt commits over long-lived coordination branches.

---

## Work Lifecycles

The pattern does not mandate a single workflow. A coordination domain may define
lifecycle states appropriate to its process.

Common states include:

```text
proposed -> accepted -> active -> done -> reviewed -> verified -> closed
```

or, for simpler projects:

```text
open -> in-progress -> closed
```

More rigorous workflows may separate:

* developer completion;
* peer review;
* verification or testing;
* final acceptance;
* release inclusion.

This separation is useful because "work completed" is not always the same as
"project state accepted". The coordination repository should make the domain's
meaning of each state explicit.

---

## Human and Automation Collaboration

The pattern does not assume that project work is performed by humans,
automation, or AI systems alone.

All actors interact through the same Git-backed project state. A human may add a
requirement, a script may regenerate a coverage report, an AI coding agent may
claim and complete a work item, a CI job may attach verification evidence, and
a reviewer may record acceptance.

The important property is not who made a change, but that the change is
explicit, attributable, reviewable, and traceable.

---

## Role-Based Workflows

A coordination repository may support role-based workflows. Roles make
responsibility explicit and help actors operate within bounded expectations.

Example roles include:

* planner;
* architect;
* implementer;
* reviewer;
* tester;
* release manager;
* operator;
* incident responder.

Roles can be used by humans, scripts, or AI-assisted tools. The pattern does
not require a specific role taxonomy, role manager, scheduler, or automation
runner.

A useful role-based workflow records:

* which role performed a state transition;
* which evidence was considered;
* which next role or state is expected;
* whether the transition is final or pending review.

---

## Authority Rules

A coordination repository should explicitly define which project state it owns.
For each field of project state, the coordination domain should define exactly
one authoritative source. Other systems may mirror, summarize, link to, or
notify about that state, but they should not silently compete as independent
sources of truth.

A typical division of authority is:

| System | Common authoritative state |
| --- | --- |
| Implementation repository | Source code, tests, build configuration, and deliverable artifacts. |
| Coordination repository | Requirements, decisions, lifecycle state, ownership, acceptance, and traceability. |
| Issue tracker | Public intake, external discussion, labels, notifications, and user-facing status. |
| Code review system | Pull request discussion, reviewer approvals, and merge status. |
| CI system | Raw run results, logs, artifacts, and execution metadata. |
| Chat system | Synchronous discussion and notifications, not durable project state. |

The exact boundaries are domain-specific. Typical refinements include:

* issue trackers may own public intake, discussion, and external notification;
* coordination repositories may own implementation status, lifecycle state,
  ownership, verification, acceptance, and traceability;
* CI systems may own raw run results and logs, while coordination items link to
  the evidence needed for project-state decisions.

Mirrored or generated records should identify their authoritative input and
should normally be regenerated rather than hand-edited.

---

## Integration with Other Systems

The Coordination Repository Pattern does not replace other project systems. It
integrates with them according to the authority boundaries defined by the
coordination domain.

Issue trackers, project boards, CI systems, code review systems, release tools,
and chat systems may remain useful. A coordination repository can link to them,
mirror selected state, or generate reports for them.

The pattern is most valuable for state that benefits from being:

* version-controlled;
* reviewable as text;
* available offline;
* shared between humans and automation;
* traceable over time;
* portable across tools and hosting platforms.

---

## Why Not Only Use an Issue Tracker?

Issue trackers remain valuable. They optimize web-based human interaction,
notifications, search, labels, dashboards, and integrations.

The Coordination Repository Pattern addresses a different concern: durable,
Git-native project state that can be cloned, reviewed, merged, generated from,
and consumed by humans and automation using the same workflow.

The two approaches can complement each other. For example, an issue tracker may
serve as a public intake channel while the coordination repository stores the
structured project state used for implementation planning, traceability,
automation, and long-term history.

---

## Consequences and Trade-Offs

Adopting a coordination repository creates useful discipline, but it also adds
operational responsibility.

Benefits include:

* clearer separation between intent and implementation;
* durable review history for requirements, decisions, and workflow state;
* better traceability from project intent to implementation evidence;
* a shared medium for humans and automation;
* reduced dependence on one hosted project-management service.

Costs and risks include:

* another repository and workflow for participants to understand;
* stale coordination state if actors do not update it promptly;
* duplicated or conflicting state when authority rules are unclear;
* semantic conflicts that Git cannot detect automatically;
* possible exposure of sensitive planning, operational, or security context;
* generated reports becoming misleading if their authoritative inputs are not
  clear.

These risks are manageable when the coordination domain defines authority,
lifecycle, synchronization, review, and sensitivity rules explicitly.

---

## Non-Goals

This pattern does not attempt to replace:

* Git itself;
* source repositories;
* CI systems;
* issue trackers;
* code review systems;
* release management;
* project communication tools;
* human judgment.

It also does not prescribe:

* one schema;
* one lifecycle;
* one directory layout;
* one actor model;
* one automation framework;
* one AI coding tool.

Instead, it provides a Git-native coordination layer that integrates naturally
with existing systems.

---

## Implementation Considerations

Projects adopting the pattern should decide:

* the coordination domain boundary;
* where the coordination repository remote lives;
* whether working clones are external or nested inside implementation checkouts;
* which files are authoritative source records and which files are generated;
* item ID format;
* required metadata fields;
* lifecycle states and transition rules;
* review and verification expectations;
* conflict handling protocol;
* automation permissions;
* how source commits, tests, releases, and external systems are referenced;
* how sensitive information is excluded.

A small project can start with Markdown files and a simple status convention.
More automated projects may add schemas, linting, generated reports, lifecycle
helpers, and role-based runners.

---

## Appendix A: pi-env Reference Implementation

`pi-env` includes optional Git-backed coordination helpers that implement one
version of the Coordination Repository Pattern for sandboxed AI-assisted
software development.

This appendix is descriptive, not prescriptive. Other implementations may use
different file layouts, schemas, lifecycle states, automation runners, or tools
while still following the pattern.

### Coordination domain and location

`pi-env` defaults to one coordination repository per selected project. Each
`pi-env` run operates on one project root mounted at `/workspace` inside the
sandbox.

Fresh local coordination state is placed under the project-local operational
root:

```text
.pi-env/
  coordination/          # working coordination clone
  agent-remotes/         # optional local bare coordination remotes
  logs/
  locks/
```

The `.pi-env/coordination` directory is a separate Git repository even though
its working clone is physically nested under the implementation checkout. The
`.pi-env/` operational root should normally remain untracked by the
implementation repository.

Hosted Git remotes are also supported through explicit remote URLs.

### Authority model

In the `pi-env` reference implementation, the coordination repository is the
authoritative source for project coordination state within the selected
coordination domain. This includes requirements, issues, task-category work,
decisions, notes, lifecycle status, ownership, review state, verification state,
and traceability links.

Implementation repositories remain authoritative for source code, tests, build
configuration, and deliverable artifacts. External systems such as issue
trackers, CI systems, pull requests, and chat may be referenced as evidence or
used for intake and notification, but `pi-env` coordination helpers treat the
coordination repository as the durable source of project-state truth.

### Scaffolded layout

A fresh `pi-env` coordination repository includes files and directories such as:

```text
AGENTS.md
README.md
PROJECT.md
docs/
  SYNC_PROTOCOL.md
  ITEM_FORMAT.md
.pi/
  skills/
    agent-coordination/
      SKILL.md
issues/
  open/
  blocked/
  done/
  closed/
requirements/
todos/
decisions/
notes/
agents/
```

### Helper commands

`pi-env` packages optional coordination helpers, including:

```text
bootstrap-coordination   infer defaults and initialize coordination state
agent-coord-init         create and scaffold a coordination repository
agent-coord-clone        clone an existing coordination repository
agent-coord-status       show repository status and active items
agent-coord-list         list items
agent-coord-cat          print an item
agent-coord-new          create a templated item
agent-coord-claim        claim an issue item
agent-coord-done         mark developer work done
agent-coord-review       record review pass/fail
agent-coord-verify       record verification pass/fail
agent-coord-close        final-close reviewed and verified done items
agent-coord-lint         validate coordination items and test linkage
agent-coord-pull         pull/rebase coordination state
agent-coord-push         commit and push coordination changes
```

The helpers are plain Git/text-file tooling and are separate from the core
sandbox launcher.

### Item model

`pi-env` stores coordination items as YAML files. New IDs use type-coded UTC
timestamps:

```text
<PROJECTKEY>-<TYPECODE>-<YYYYMMDD-HHMMSS>-<NNN>.yaml
```

Examples:

```text
PIENV-ISS-20260607-204155-001.yaml
PIENV-FRQ-20260607-204155-001.yaml
```

Built-in type codes include:

* `ISS` for issue;
* `FRQ` for functional requirement;
* `QRQ` for quality requirement;
* `CRQ` for constraint requirement;
* `TODO` for todo;
* `DEC` for decision;
* `NOTE` for note.

Task-like work is represented as an issue with `category: task`, not as a
separate structural `task` item type.

Built-in issue categories are `bug`, `feature-request`, `task`, `question`,
and `improvement`; project-specific slugs may be used for local categorization.

The mental model is that an issue is an actionable workflow container: a bug
tracks defect remediation, a feature request tracks desired capability, an
improvement tracks refinement of existing behavior, a question tracks a needed
clarification, and a task tracks concrete execution work. Requirements,
decisions, notes, and TODO records hold specification, rationale, context, or
lightweight reminders outside the issue lifecycle.

Issue items include current state near the top plus chronological events and
linked Markdown message bodies. Requirement and TODO items are current-state
records with renderable body blocks.

### Lifecycle semantics

`pi-env` issue state directories are developer-centric:

```text
issues/open/      developer work is available or required
issues/blocked/   developer work cannot proceed
issues/done/      developer believes implementation is complete
issues/closed/    final accepted state
```

A `done` issue is not final. Final acceptance requires review and verification:

```yaml
status: closed
reviewed: true
verified: true
```

Lifecycle helpers record meaningful transitions as item events and commit/push
coordination changes promptly.

### Synchronization and roles

`pi-env` coordination helpers use ordinary Git pull/rebase, commit, and push as
the synchronization mechanism. Commands that create item events can record actor
and role metadata. When the `pi-env` role-manager package is active, it exposes
role context to helper commands through `PI_COORD_ROLE` without changing normal
project repository Git identity.

### Serial role automation

`pi-env` also provides `pi-serial-roles`, a deliberately serial automation mode
for processing developer, reviewer, and tester jobs against one project clone
and one coordination clone. It polls coordination state, selects eligible work,
invokes role-scoped Pi sessions, and relies on coordination Git content as the
shared memory between jobs.

Parallel automation, multiple worktrees, leases, and cross-clone concurrency
rules are future implementation concerns rather than requirements of the
generic pattern.

---

## Acknowledgments

This pattern was developed during work on `pi-env` and refined through
independent review, discussion, and AI-assisted drafting and critique.

AI-assisted review and drafting support was provided by Pi/ChatGPT.

---

## Future Directions

Areas for future exploration include:

* shared item schema conventions;
* interoperable lifecycle vocabularies;
* dependency and blocking models;
* generated traceability and coverage reports;
* cross-project coordination patterns;
* role-based automation conventions;
* safe automation permission models;
* interoperability between issue trackers and coordination repositories;
* interoperability between AI-assisted development tools.

These may evolve into shared conventions or formal specifications while
preserving the core principle:

> Separate project coordination state from implementation state using
> Git-native, reviewable, human- and automation-readable artifacts with
> traceable history.
