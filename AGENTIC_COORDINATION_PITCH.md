# Agentic Coding Needs Durable Coordination State

> **Status:** Draft position paper
>
> **Author:** Samo Pogačnik <samo_pogacnik@t-2.net>
>
> **Document license:** Creative Commons Attribution 4.0 International
> (CC BY 4.0), <https://creativecommons.org/licenses/by/4.0/>.
>
> **Reference implementation:** `pi-env`, <https://github.com/u2up/pi-env>.
>
> **Purpose:** A short, ecosystem-facing companion to
> [`COORDINATION_REPO_PATTERN.md`](COORDINATION_REPO_PATTERN.md). The pattern
> paper explains the Coordination Repository Pattern. This document explains why
> people building and using agentic coding systems should care about it now.

---

## Thesis

Agentic coding has made rapid progress on tool access. Agents can inspect
repositories, edit files, run commands, call APIs, use MCP servers, operate in
sandboxes, and participate in increasingly sophisticated workflows.

But tool access is not the same as project coordination.

Agentic coding stacks have a coordination gap. A recurring question remains:

> **Where does durable project coordination state live?**

Many agentic coding workflows still rely on prompts, chat transcripts, hidden
memory, issue comments, pull request discussion, temporary notes, or the current
context window to carry project intent from one step to the next. Those channels
can be useful, but they are weak foundations for durable coordination.

The Coordination Repository Pattern addresses this missing layer by treating
project coordination as first-class, version-controlled state.

---

## The problem: agents can act, but coordination state is fragile

Today's coding agents are increasingly capable execution participants. They can
read code, propose changes, run tests, review output, and hand work back to a
human or another agent. The surrounding ecosystem has focused heavily on:

- model quality;
- tool APIs;
- MCP servers;
- execution sandboxes;
- code generation;
- retrieval and memory systems;
- multi-agent orchestration.

These are important layers. They help an agent know what it can do and how it
can safely do it.

They do not, by themselves, answer how a project remembers what is being
coordinated.

In practice, important coordination state is often scattered across:

- initial prompts and follow-up instructions;
- long chat histories;
- hidden or provider-specific memory;
- issue trackers and project boards;
- pull request comments;
- local notes and scratch files;
- CI logs and automation output;
- task lists maintained outside the repository.

This fragmentation is manageable for small, single-session tasks. It becomes a
problem when work spans multiple sessions, multiple agents, multiple humans, or
multiple implementation repositories.

Common failure modes include:

- agents forget earlier constraints;
- long chats become too large to use effectively;
- context windows drop important decisions;
- task ownership becomes ambiguous;
- multiple agents duplicate or overwrite each other's work;
- review status is unclear;
- validation evidence disappears into logs or transcripts;
- architectural decisions become detached from the work they justified;
- handoff quality depends on whoever wrote the last prompt.

The result is not merely an agent memory problem. Much of this information is
project state.

Project state deserves a durable home.

---

## The missing layer: durable coordination state

Agentic development needs a shared layer for coordination information that is:

- **explicit**: represented as inspectable artifacts, not only implied by chat;
- **durable**: preserved across sessions, agents, and tool providers;
- **reviewable**: visible to humans before and after automation acts;
- **versioned**: able to show what changed, when, and why;
- **mergeable**: usable by distributed participants working concurrently;
- **portable**: not locked inside one hosted service or agent runtime;
- **linkable**: able to connect requirements, decisions, tasks, commits, tests,
  pull requests, and release evidence.

That layer should not replace implementation repositories, issue trackers,
code review systems, CI systems, or agent harnesses. It should complement them.

The key architectural idea is:

> **Treat project coordination as first-class version-controlled state.**

A coordination repository is one practical implementation of that idea.

---

## The Coordination Repository Pattern

The Coordination Repository Pattern separates project coordination state from
implementation state.

Implementation repositories remain authoritative for code, tests, build
configuration, packages, deployment assets, and product documentation.

A coordination repository stores durable project-state artifacts such as:

- goals and scope;
- requirements and constraints;
- work items and ownership;
- status, blockers, review state, and acceptance criteria;
- architectural decisions and trade-offs;
- risks and migration notes;
- release intent and readiness notes;
- links to implementation commits, tests, pull requests, CI results, and other
  evidence.

For agentic coding, the coordination repository becomes durable shared project
memory: project coordination state that humans and automation can both read and
update through normal file and Git operations.

It is not an agent-specific extension. It is an architectural coordination
layer that an agentic coding harness, human developer, CI job, release script,
or project bot can all participate in.

---

## How it complements agentic coding harnesses

An agentic coding harness usually answers questions such as:

- Which tools can the agent call?
- What files can it access?
- What commands may it run?
- What sandbox boundaries apply?
- How are model prompts assembled?
- How are tool calls authorized and observed?

A coordination repository answers different questions:

- What work is currently active?
- Who or what owns it?
- What requirement or decision motivates it?
- What constraints must be preserved?
- What has already been tried?
- What validation evidence exists?
- What remains blocked, unresolved, or ready for review?
- What should the next human or agent know before continuing?

These questions are not transient prompt details. They are coordination facts
about the project.

Because the coordination repository is just Git-backed content, different
agentic coding systems can share it without agreeing on one runtime, model
provider, memory service, or orchestration framework.

That interoperability is the point. The project, not any individual model
provider, orchestration framework, chat system, or agent runtime, should own its
durable coordination state. Coordination is no longer tied to a single agent
session, provider-specific memory store, orchestration framework, or chat UI.
One agent can update project state, another agent can continue from it, a human
can review it, and CI or release automation can link evidence back to it.

---

## Why this is different from AI memory

A coordination repository is not another name for agent memory.

AI memory usually answers:

> What has this agent seen?

A coordination repository answers:

> What does this project currently know?

AI memory is often provider-specific, conversational, and difficult to review.
A coordination repository is project-owned, reviewable, versioned, shared, and
durable.

AI memory can be useful context for an agent. Coordination state is durable
project context for humans, agents, scripts, CI jobs, and release processes.

---

## Why Git is an attractive substrate

Git is not the right substrate for every kind of memory. It is not a vector
database, a low-latency message bus, a secrets manager, or a replacement for all
project-management tools.

But Git is unusually well suited to the class of information that behaves like
project state:

- it has history;
- it benefits from review;
- it changes through explicit edits;
- it needs attribution;
- it may be branched and merged;
- it should survive local and hosted tool changes;
- it should be readable by humans and automation;
- it often needs to link to source changes and release evidence.

Git already provides distributed synchronization, review workflows, offline
operation, textual diffs, branches, commits, merges, and broad tool support.
Those are exactly the properties coordination state often needs.

The claim is not "put everything in Git." The claim is narrower and stronger:

> Use Git for project coordination information that naturally benefits from
> Git's semantics.

---

## Example workflow

A simple agentic workflow might look like this:

1. A human or planning agent records a requirement in the coordination
   repository.
2. An architectural decision documents the chosen approach and trade-offs.
3. A work item links to the requirement and decision, defines acceptance
   criteria, and records current ownership.
4. A coding agent claims the item, inspects the linked context, and makes an
   implementation change in the relevant implementation repository.
5. The agent updates the work item with what changed, what tests were run, what
   evidence supports the result, and what remains uncertain.
6. A reviewer inspects both the implementation change and the coordination
   update.
7. Another human, agent, CI job, or release process can later reconstruct why
   the change happened and what evidence supported it.

The important point is not the exact schema. The important point is that intent,
ownership, decisions, validation, and handoff state are durable, reviewable, and
shared.

---

## Boundaries

A coordination repository should not become an undifferentiated dumping ground.
It should avoid storing:

- secrets or credentials;
- large generated artifacts;
- raw logs better kept in CI or observability systems;
- high-volume chat transcripts;
- private human-resource, financial, legal, or procurement information unless a
  project explicitly chooses to manage that domain;
- source code or build artifacts that belong in implementation repositories.

The pattern works best when the repository stores compact, durable coordination
facts and links to supporting evidence elsewhere.

---

## Why the timing matters

Many teams are independently rediscovering the same problems:

- agents forget;
- context windows are finite;
- long chats do not scale;
- hidden memory is hard to review;
- multiple agents need synchronization;
- task ownership becomes ambiguous;
- decisions disappear into transcripts;
- handoffs are inconsistent.

Different systems are exploring memory services, vector databases, knowledge
graphs, notebooks, issue trackers, MCP servers, and custom orchestration layers.
Those approaches can be valuable.

The Coordination Repository Pattern starts from a simple observation: some of
this information is not merely retrieval context or conversation history. It is
project coordination state. Project coordination state often deserves the same
kind of durability, reviewability, and version history that source code already
has.

---

## Acknowledgments

This position paper was developed from the Coordination Repository Pattern work
in `pi-env` and refined through independent review, discussion, and AI-assisted
drafting and critique.

AI-assisted review and drafting support was provided by Pi/ChatGPT.

---

## Further reading

For the formal pattern description, terminology, trade-offs, and operational
practices, see:

- [`COORDINATION_REPO_PATTERN.md`](COORDINATION_REPO_PATTERN.md)
