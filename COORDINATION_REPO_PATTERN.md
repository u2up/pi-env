# COORDINATION_REPO_PATTERN.md

> **Status:** Draft 0.1
>
> This document describes the Coordination Repository Pattern independently of any specific implementation. It originated during the design of **pi-env**, but is intended as a reusable architectural pattern for AI-assisted software development.

---

# Coordination Repository Pattern

## Abstract

The Coordination Repository Pattern separates **project coordination** from **project implementation**.

Instead of embedding project planning, task state, decisions, agent assignments, and operational knowledge inside implementation repositories or external project-management tools, these artifacts are maintained in a dedicated Git repository.

The coordination repository becomes the authoritative, version-controlled source of project state for both humans and autonomous software agents.

Implementation repositories remain focused on source code and deliverables.

---

# Motivation

Modern software projects increasingly involve autonomous coding agents alongside human contributors.

While source code already benefits from Git's distributed, reviewable workflow, project coordination is often fragmented across:

* issue trackers
* project boards
* chat systems
* documentation
* CI systems
* agent memory
* implementation repositories

Humans can mentally integrate information from these systems.

Agents cannot reliably do so.

A coordination repository provides a single, Git-native source of operational truth.

---

# Core Principle

> **Source repositories contain implementation state.**
>
> **Coordination repositories contain project state.**

This distinction is the foundation of the pattern.

Implementation repositories answer:

* What has been built?

Coordination repositories answer:

* What should be built?
* Why?
* By whom?
* In what order?
* With which dependencies?
* What decisions led here?
* What remains?

---

# Design Goals

A Coordination Repository should be:

## Git-native

No database.

No proprietary backend.

Everything important is represented as version-controlled artifacts.

---

## Human-readable

Every important project artifact should be understandable without specialized software.

Markdown and plain text are preferred.

---

## Agent-readable

Project state should have enough structure that autonomous agents can interpret it deterministically.

Free-form prose should be minimized where structured data is appropriate.

---

## Reviewable

Changes to project state deserve the same review process as changes to source code.

Planning, priorities, and architectural decisions should leave an auditable history.

---

## Distributed

Coordination should work offline.

Contributors and agents should be able to clone, branch, merge, and review coordination artifacts using standard Git workflows.

---

## Tool-independent

The pattern should not depend on a specific AI model, coding agent, IDE, hosting platform, or project management service.

---

# Architecture

```
                    Project

          +------------------------+
          | Coordination Repository|
          +------------------------+
             |    |    |     |
             |    |    |     |
      Goals  Tasks Decisions Status

                    |
        ----------------------------
        |            |             |
        v            v             v

   Source Repo   Documentation   Infrastructure
```

The coordination repository contains project intent.

Implementation repositories contain project realization.

---

# Typical Contents

A coordination repository may include:

* project goals
* roadmap
* backlog
* active work
* completed work
* architectural decisions
* implementation plans
* agent registry
* contributor information
* project conventions
* repository catalog
* release planning
* coordination workflows

The exact structure is intentionally left implementation-specific.

---

# Human–Agent Collaboration

The pattern assumes humans and agents operate as peers with different responsibilities.

Humans typically:

* define goals
* make architectural decisions
* review work
* resolve conflicts

Agents typically:

* execute tasks
* propose changes
* update task state
* document implementation progress

Both interact through the same coordination artifacts.

---

# Example Lifecycle

1. A task is created.
2. An agent claims responsibility.
3. The implementation occurs in a source repository.
4. Progress is reflected in the coordination repository.
5. A pull request is reviewed.
6. The task is completed and archived.
7. Git history preserves the complete operational record.

---

# Why Not GitHub Issues?

Issue trackers remain valuable.

The Coordination Repository Pattern addresses a different problem.

Issue trackers optimize human interaction through web interfaces.

Coordination repositories optimize shared, version-controlled project state for both humans and autonomous agents.

The two approaches may complement each other.

---

# Relationship to pi-env

pi-env provides reproducible, secure execution environments for autonomous coding agents.

The Coordination Repository Pattern addresses a different concern:

**how project state is represented and shared.**

Projects may:

* adopt pi-env without using a coordination repository,
* adopt the Coordination Repository Pattern without using pi-env,
* or use both together.

pi-env therefore **supports** the pattern but does not require it.

---

# Non-Goals

This pattern does not attempt to replace:

* Git itself
* source repositories
* CI systems
* issue trackers
* code review
* release management

Instead, it provides a Git-native coordination layer that integrates naturally with them.

---

# Future Directions

Areas for future exploration include:

* standard task schemas
* agent claiming protocols
* dependency tracking
* coordination analytics
* cross-project coordination
* interoperability between AI coding tools

These may evolve into shared conventions or formal specifications while preserving the core principles of the pattern.

---

# Status

This document is a living design document.

The pattern is expected to evolve through practical experience and community feedback.

Implementations are encouraged to innovate while preserving the core principle:

> Separate project coordination from project implementation using Git-native, reviewable, human- and agent-readable artifacts.

