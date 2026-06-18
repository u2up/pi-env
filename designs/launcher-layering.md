# Launcher Layering Design

`pi-env` exposes a small launcher stack that separates environment setup,
interactive agent startup, and sandbox execution. The boundary keeps each
entrypoint understandable and limits privileged or host-sensitive behavior to
the layer that needs it.

## Covers

| Requirement | Coordination item |
|-------------|-------------------|
| UC-001 | PIENV-FRQ-20260612-210000-001 |
| UC-002 | PIENV-FRQ-20260612-210000-002 |
| UC-014 | PIENV-FRQ-20260612-210000-014 |
| UC-016 | PIENV-FRQ-20260612-210000-016 |
| CRQ-011 | PIENV-CRQ-20260613-183419-001 |
| CMD-001 | PIENV-FRQ-20260612-210000-032 |
| CMD-002 | PIENV-FRQ-20260612-210000-033 |
| CMD-003 | PIENV-FRQ-20260612-210000-034 |
| CMD-004 | PIENV-FRQ-20260612-210000-035 |
| CMD-005 | PIENV-FRQ-20260612-210000-036 |
| CMD-006 | PIENV-FRQ-20260612-210000-037 |
| CMD-007 | PIENV-FRQ-20260612-210000-038 |
| CMD-008 | PIENV-FRQ-20260612-210000-039 |
| CMD-018 | PIENV-FRQ-20260613-183404-001 |
| CMD-019 | PIENV-FRQ-20260613-183411-001 |

## 1. Layer responsibilities

`pi-env` is the outer entrypoint. It prepares paths, validates one selected
project root, and chooses whether the user wants a shell, a command, or an
agent launch. It owns argument compatibility for the command families covered
by `CMD-001` through `CMD-008`. The selected project root is the only primary
project for the run and is later mounted at `/workspace`; pi-env does not manage
a host-side collection of projects.

`pi-start` is the agent-facing startup layer. It translates the prepared
workspace into the final `pi` invocation, applies role or prompt options, and
keeps startup ergonomics separate from sandbox construction.

`pi-bwrap` is the sandbox construction layer. It builds the Bubblewrap command
line and is the only layer that should assemble mount, environment, network,
and home-state isolation flags.

## 2. Command flow

The launchers pass structured intent downward rather than sharing hidden global
state. `pi-env` resolves the single project root and runtime inputs, then calls
`pi-start` for the default `UC-001` agent startup or `pi-bwrap` for the
custom-argument `UC-002` path. `pi-start` may delegate to `pi-bwrap` when the
agent must run in the sandbox.

This shape lets `CMD-018` and the launcher-facing part of `CMD-019` add role
manager integration without changing the sandbox contract. Role selection is
interpreted before the final `pi` process starts; sandboxing still receives a
normal command and environment policy. Tool allowlist overrides for `UC-014`
and globally-installed Pi discovery for `UC-016` are launcher inputs that are
translated into normal Pi arguments and read-only runtime mounts.

## 3. Compatibility and diagnostics

Launchers should fail early for unsupported arguments, missing project roots, or
missing runtime tools. Error messages should identify the layer that rejected
the request so users know whether to adjust launch flags, Pi startup options,
or sandbox settings.

The layering also preserves backwards compatibility: user-visible command names
remain stable while implementation detail can move between scripts as long as
ownership boundaries above are maintained.
