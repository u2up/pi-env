# COORDINATION_REPO_PATTERN.md

> **Status:** Draft 1.0 candidate
>
> **Author:** Samo Pogačnik <samo_pogacnik@t-2.net>
>
> **Document license:** Creative Commons Attribution 4.0 International
> (CC BY 4.0), <https://creativecommons.org/licenses/by/4.0/>.
>
> **Reference implementation:** `pi-env`, <https://github.com/u2up/pi-env>.
>
> This document describes the Coordination Repository Pattern independently of
> any specific implementation. It originated during the design of **pi-env**, but
> is intended as a reusable architectural pattern for Git-backed project state.

---

# Coordination Repository Pattern

## Abstract

The Coordination Repository Pattern separates **project coordination state**
from **project implementation state**.

Project coordination state includes goals, requirements, work status,
decisions, ownership, review notes, release intent, operational context, and
planning history. Instead of leaving that state fragmented across issue
trackers, chat systems, local notes, automation logs, and source repositories,
the pattern keeps durable coordination artifacts in a dedicated Git repository.

The coordination repository becomes a version-controlled source of project
state and history. Because that state is represented as normal Git content,
humans, scripts, CI jobs, release tooling, and AI-assisted development tools can
all participate through the same reviewable source of truth.

Implementation repositories remain focused on source code and deliverables.

---

## 30-Second Example

A coordination repository owns durable project-state records:

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

Conceptually:

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

## Document Structure

This document separates the pattern from operational guidance:

* **Core Pattern** describes the durable architectural idea.
* **Recommended Operational Practices** describes practices that commonly make
  the pattern work well, but are not required by every implementation.
* **Appendix A** briefly identifies the `pi-env` reference implementation and
  links to implementation-specific details.

The document uses words such as "should" in their ordinary advisory sense, not
as a formal conformance vocabulary. A future RFC-style specification could make
some recommendations normative, but this draft is primarily a pattern paper.

---

# Core Pattern

## Motivation

Software projects accumulate important state outside source code:

* goals, scope, requirements, and constraints;
* architectural decisions and trade-offs;
* active work, ownership, blockers, review, and verification status;
* release intent, migration plans, and operational notes;
* links between work, commits, tests, decisions, and releases.

This state is often spread across issue trackers, project boards, chat systems,
design documents, CI systems, code review tools, local notes, automation memory,
and implementation repositories. Humans can sometimes mentally integrate these
systems. Automation generally cannot do so reliably, and even human teams lose
context over time.

Git is well-suited to durable coordination state because it provides history,
attribution, branching, merging, review workflows, offline operation, and
portable plain-text storage. Using Git for project state makes those properties
available without requiring every participant or automation tool to depend on
one hosted service.

AI agents and other automation increase the need for explicit coordination
state, but they are not a prerequisite for the pattern. The pattern is useful
wherever project state deserves the same durability and reviewability as source
code.

When AI agents participate, the coordination repository should be treated as the
durable communication medium between agents. Important handoff information
belongs in structured Git content rather than only in conversation transcripts,
hidden memory, or another agent's prompt context.

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
unless a project explicitly chooses to include those concerns.

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
Implementations may use different item schemas and names.

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

## Why a Dedicated Git Repository?

The architectural unit is a dedicated Git repository because coordination state
often needs ownership, history, review, synchronization, and portability
independent of any one implementation repository or hosted workflow tool.

A directory inside an implementation repository can store planning files, but it
couples coordination history to source history, release branches, access rules,
and repository boundaries. That coupling becomes awkward when coordination spans
multiple repositories, when planning should change without touching source
branches, or when implementation history should not expose internal planning
context.

A database or issue tracker can be the right system of record for selected
workflow concerns. The coordination repository addresses a narrower case:
durable text artifacts that benefit from source-control mechanics such as
clone, branch, review, diff, merge, archive, and recover. It remains readable
from a checkout and usable by humans, scripts, CI jobs, and AI-assisted tools
without requiring one central application to mediate all access.

The repository boundary also makes authority explicit. The implementation
repository owns deliverables; the coordination repository owns project intent,
lifecycle state, decisions, acceptance, and traceability. Other tools may index,
mirror, notify, or visualize that state, but the Git repository provides the
portable architectural anchor.

This does not mean Git should replace every workflow tool. The pattern uses Git
where Git's strengths matter most: durable text artifacts, inspectable history,
distributed synchronization, reviewable changes, and long-term independence
from any one hosted service.

## Project-State Scope

Project state is not one monolithic category. A coordination repository often
organizes several related concerns:

| Concern | Examples |
| --- | --- |
| Intent | Requirements, decisions, goals, and constraints. |
| Execution | Issues, TODOs, ownership, blockers, and active work. |
| Knowledge | Notes, runbooks, operational context, and migration context. |
| Governance | Reviews, verification, acceptance, lifecycle rules, and release readiness. |
| Traceability | Links, evidence, coverage reports, commits, tests, and external records. |

Common artifact roles include:

* **Requirement**: desired behavior, quality, constraint, policy, or outcome.
* **Decision**: selected approach plus rationale, alternatives, and trade-offs.
* **Issue**: actionable workflow container with lifecycle, ownership, and
  evidence.
* **TODO**: lightweight reminder or follow-up that does not need a full issue
  lifecycle.
* **Note**: durable contextual information that should remain discoverable.

An issue is not limited to a defect report. More generally, it coordinates
ownership, lifecycle, evidence, and acceptance for a unit of work,
investigation, or inquiry.

Other domains may add risks, incidents, release plans, milestones, runbooks, or
review records. The important property is that each artifact type has a clear
coordination purpose and an explicit relationship to other project state.

## Repository Topology

The coordination repository is logically separate from implementation
repositories, but its working clone may be located wherever is operationally
convenient.

Common topologies include separate sibling repositories:

```text
project-source/
  src/
  tests/

project-coordination/
  requirements/
  issues/
  decisions/
```

or a nested working clone ignored by the implementation repository:

```text
project-source/
  src/
  tests/
  .pi-env/
    coordination/       # separate Git repository, ignored by project-source
```

The important boundary is Git ownership and responsibility:

* the implementation repository owns source and deliverables;
* the coordination repository owns project state and coordination history.

A coordination repository may use a hosted remote, a local bare Git remote, or
ordinary peer-to-peer Git exchange. The pattern does not prescribe hosting.

## Design Goals

A coordination repository should usually be:

* **Git-native**: important state is version-controlled and compatible with
  standard clone, branch, commit, review, merge, and archive workflows.
* **Human-readable**: important artifacts are understandable from a checkout
  without a specialized service. Markdown, YAML, TOML, JSON, and plain text are
  common choices.
* **Automation-readable**: status, ownership, dependencies, IDs,
  relationships, and lifecycle fields are structured where deterministic
  behavior matters.
* **Traceable**: readers can answer not only what the current state is, but how
  it became that way.
* **Reviewable**: planning, priority, scope, acceptance, and architectural
  decisions leave an inspectable history.
* **Distributed**: participants can work with coordination state using normal
  Git tooling.
* **Tool-independent**: the pattern does not depend on a specific AI model,
  coding agent, IDE, hosting platform, issue tracker, CI system, or project
  management service.

## Authority Boundaries

A coordination repository should explicitly define which project state it owns.
For each field of project state, the coordination domain should identify one
authoritative source. Other systems may mirror, summarize, link to, or notify
about that state, but they should not silently compete as independent sources
of truth.

A typical division of authority is:

| System | Common authoritative state |
| --- | --- |
| Implementation repository | Source code, tests, build configuration, and deliverable artifacts. |
| Coordination repository | Requirements, decisions, lifecycle state, ownership, acceptance, and traceability. |
| Issue tracker | Public intake, external discussion, labels, notifications, and user-facing status. |
| Code review system | Pull request discussion, reviewer approvals, and merge status. |
| CI system | Raw run results, logs, artifacts, and execution metadata. |
| Chat system | Synchronous discussion and notifications, not durable project state. |

The boundaries are domain-specific. For example, an issue tracker may own
public intake and external discussion while the coordination repository owns
implementation planning, lifecycle status, verification, acceptance, and
traceability. CI systems may own raw logs while coordination items link to the
specific evidence used for project-state decisions.

Mirrored or generated records should identify their authoritative input and
should normally be regenerated rather than hand-edited.

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
files. The pattern does not require one schema, but it benefits from stable
IDs, explicit status, clear relationships, and durable links to evidence.

## Traceability

Traceability is central to the pattern. A coordination repository should make
it possible to follow relationships such as:

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

Useful traceability practices include stable item IDs, links between related
items, explicit lifecycle fields, chronological state-change records,
references to commits or external evidence, and generated coverage or status
reports derived from authoritative item files.

## Integration with Other Systems

The Coordination Repository Pattern does not replace other project systems. It
integrates with them according to the authority boundaries defined by the
coordination domain.

Issue trackers, project boards, CI systems, code review systems, release tools,
and chat systems may remain useful. A coordination repository can link to them,
mirror selected state, or generate reports for them.

The pattern is most valuable for state that benefits from being
version-controlled, reviewable as text, available offline, shared between
humans and automation, traceable over time, and portable across tools and
hosting platforms.

## Applicability

Use this pattern when project coordination state must outlive transient
conversation, span multiple tools or repositories, be reviewed like source
changes, or be consumed safely by automation. It is especially useful for
multi-actor projects, regulated or audit-sensitive work, long-running
migrations, AI-assisted development, and projects where decisions and
acceptance evidence must remain traceable.

The pattern may be unnecessary for small, short-lived projects where source
commits and a lightweight issue tracker already provide enough context. It may
also be the wrong primary store for high-volume telemetry, large binary
artifacts, real-time locking, private personnel data, or workflow state whose
value depends mainly on a hosted product's notification and dashboard features.

The central trade-off is discipline for durability: adopters gain portable,
reviewable coordination history, but they must define authority boundaries and
keep project state current.

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

It also does not prescribe one schema, lifecycle, directory layout, actor
model, automation framework, or AI coding tool. Instead, it provides a
Git-native coordination layer that integrates naturally with existing systems.

---

# Recommended Operational Practices

The practices in this section are guidance, not the minimum definition of the
pattern. Small projects may use only a subset; larger or automated projects may
need explicit rules.

## Synchronization Protocol

Treat the coordination repository like other shared Git state: pull or rebase
before changing it, make focused changes, record important state transitions in
the artifacts themselves, commit clearly, and push promptly. Resolve conflicts
conservatively and avoid rewriting shared history unless the coordination
domain has a recovery procedure.

## Concurrent Actors and Semantic Conflicts

Git detects textual conflicts, but not all coordination conflicts are textual.
Two actors can claim the same work, a generated report can race with a manual
edit, or one actor can close work while another is updating related state.
Useful mitigations include short-lived claims or leases, actor and timestamp
metadata, stale-owner rules, re-reading relevant items before final state
transitions, and clear separation between source records and generated files.

## Work Lifecycles

The pattern does not mandate one lifecycle. A domain may use a simple
`open -> in-progress -> closed` flow or a more explicit sequence that separates
proposal, implementation, review, verification, acceptance, and release
inclusion. The important practice is to define what each state means, because
"work completed" is not always the same as "project state accepted".

## Human, Automation, and Role Collaboration

Humans, scripts, CI jobs, bots, and AI-assisted tools can all be actors. Role
labels such as planner, architect, implementer, reviewer, tester, operator, or
release manager can clarify responsibility, but the pattern does not require a
specific taxonomy or role manager.

A useful transition records who or what performed it, which evidence was
considered, and what next state or role is expected.

## Adoption Checklist

Before adopting the pattern, decide the coordination domain boundary, remote
location, authoritative source records, generated outputs, item IDs, required
metadata, lifecycle states, review expectations, conflict rules, automation
permissions, evidence-linking conventions, and sensitivity exclusions.

A small project can start with Markdown files and a status convention. More
automated projects may add schemas, linting, generated reports, lifecycle
helpers, and role-based runners.

---

# Appendix A: pi-env Reference Implementation

[`pi-env`](https://github.com/u2up/pi-env) includes optional Git-backed
coordination helpers that implement one version of the Coordination Repository
Pattern for sandboxed AI-assisted software development.

This appendix is descriptive, not prescriptive. Other implementations may use
different layouts, schemas, lifecycle states, automation runners, or tools
while still following the pattern.

## Overview

`pi-env` uses a project-local coordination repository and helper tooling to
manage requirement items, issues, task-category work, decisions when used,
notes, lifecycle status, ownership, review state, verification state, and
traceability links within the selected coordination domain.

The coordination repository is a separate Git repository even when its working
clone is placed inside a project-local operational directory. Exact paths,
scaffolded files, item schemas, helper commands, local remotes, logs, locks,
and automation runners are implementation details of `pi-env`, not part of the
pattern.

Implementation repositories remain authoritative for source code, tests, build
configuration, deliverable artifacts, and implementation design documents when
those documents are the chosen place for implementation architecture rationale.
External systems such as issue trackers, CI systems, pull requests, and chat
may be referenced as evidence or used for intake and notification.

## Further implementation details

Current `pi-env` documentation describes repository layout, item formats,
helper commands, synchronization behavior, installed coordination rules, role
context, and automation architecture. Treat those documents as the `pi-env`
implementation contract rather than as requirements of the Coordination
Repository Pattern.

See the [`pi-env` repository README](README.md), [`designs/`](designs/), and
[`role-manager/`](role-manager/) for current implementation documentation.

---

# Acknowledgments

This pattern was developed during work on `pi-env` and refined through
independent review, discussion, and AI-assisted drafting and critique.

AI-assisted review and drafting support was provided by Pi/ChatGPT.

---

# Future Directions

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

The pattern intentionally remains lightweight; future work should improve
interoperability without increasing mandatory complexity.

These may evolve into shared conventions or formal specifications while
preserving the core principle:

> Separate project coordination state from implementation state using
> Git-native, reviewable, human- and automation-readable artifacts with
> traceable history.
