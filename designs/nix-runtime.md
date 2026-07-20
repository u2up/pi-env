# Nix Runtime Design

The Nix runtime provides reproducible development and launcher tooling while
keeping the project usable from direct shell scripts. The flake is the shared
contract for packages, apps, shells, and reusable shell construction.

## Covers

| Requirement | Coordination item |
|-------------|-------------------|
| UC-003 | PIENV-FRQ-20260612-210000-003 |
| UC-017 | PIENV-FRQ-20260612-210000-017 |
| UC-018 | PIENV-FRQ-20260612-210000-018 |
| UC-019 | PIENV-FRQ-20260612-210000-019 |
| UC-020 | PIENV-FRQ-20260612-210000-020 |
| FLAKE-001 | PIENV-FRQ-20260612-210000-024 |
| FLAKE-002 | PIENV-FRQ-20260612-210000-025 |
| FLAKE-003 | PIENV-FRQ-20260612-210000-026 |
| FLAKE-004 | PIENV-FRQ-20260612-210000-027 |
| FLAKE-005 | PIENV-FRQ-20260612-210000-028 |
| FLAKE-006 | PIENV-FRQ-20260612-210000-029 |
| RUNTIME-001 | PIENV-FRQ-20260612-210000-030 |
| RUNTIME-002 | PIENV-FRQ-20260612-210000-031 |
| RUNTIME-003 | PIENV-FRQ-20260614-180306-001 |
| CMD-027 | PIENV-FRQ-20260720-091901-001 |
| AGENT-018 | PIENV-FRQ-20260720-091904-001 |
| DOC-005 | PIENV-QRQ-20260720-091907-001 |

## 1. Flake outputs

The flake exposes first-class package and app outputs for the launcher tools so
users and tests can invoke the same artifacts. Packages provide installable
programs; apps provide convenient `nix run` entrypoints.

The package boundary separates the core sandbox runtime from optional
coordination helpers while using the current `pi-env-*` command names:

- `pi-core` contains `pi-env`, `pi-env-shell`, `pi-env-bwrap`, and the runtime tools.
- `pi-env-coordination` contains the Git-backed coordination helper commands.
- `pi-runtime` remains the bundle containing both sets of renamed commands for
  consumers that want the full runtime in one package.

Development shells include all tools needed for local validation: shell
utilities, Bubblewrap, Node where required by scripts, and test dependencies.
The shell contract is intentionally broader than a single launcher so
blackbox tests and documentation tooling use one reproducible environment.

## 2. Reusable shell construction

`mkPiShell` is the reusable interface for downstream projects. It packages the
common runtime dependencies and shell initialization while letting callers add
project-specific inputs. The function is the preferred extension point instead
of duplicating package lists across flakes.

`mkPiShell` keeps `includeCoordinationHelpers = true` by default so project
shell consumers receive `pi-env-bootstrap-coordination` and `pi-env-coord-*`
commands. Projects that only need the sandbox/runtime set it to `false` for a
core-only shell.

The reusable shell must remain deterministic. Host-specific state such as auth
files, Git preferences, and Pi resources is imported at launcher runtime rather
than baked into Nix derivations.

## 3. Runtime tools

`RUNTIME-001` and `RUNTIME-002` are satisfied by keeping command execution and
tool discovery inside the flake-defined environment when users opt into Nix.
Scripts should still report clear missing-tool errors when run outside that
environment, but the supported path is the reproducible flake shell.

Project-specific build and test tools are not added to the global pi-env
runtime by default. Instead, `RUNTIME-003` extends the `mkPiShell` contract:
callers declare project tools with `extraPackages`, and the shell exports the
corresponding Nix-store `bin` path for the Bubblewrap launcher to validate and
include inside the sandbox. This keeps the default runtime small while making
project-specific tools reproducible and explicit.

The exported path is an interface between the Nix layer and the sandbox layer,
not a host-path inheritance mechanism. Nix computes package paths;
`pi-env-bwrap` decides whether they are safe to admit.

## 4. Agent-oriented flake integration recipes

External project flakes often already encode domain-specific shell policy:
profile maps, FHS environments, container targets, or custom shell hooks. When a
user asks an agent to make `nix develop .#agent` work for pi-env, the intended
architecture is not a generic project shell named `agent`; it is a pi-env-aware
shell that exposes `pienv`, the Nix-backed pi-env runtime, and optional
coordination helpers.

The stable integration target is therefore additive:

1. add `pi-env` as a flake input and make it follow the project's `nixpkgs`
   input when practical;
2. include `pi-env` in the `outputs` argument set;
3. preserve existing `devShells`, package outputs, FHS/container outputs, and
   project-specific shell policy;
4. merge an agent shell using `pi-env.lib.mkPiShell`; and
5. declare only explicit project tools in `extraPackages`.

A deterministic recipe helper should expose this target shape for humans and
agents. The first version should be non-mutating and print copyable examples
instead of attempting broad AST edits across arbitrary flakes. A packaged skill
should teach agents to consult that helper, to avoid inventing unrelated
`agentProfile` shells, and to ask for clarification when a flake shape cannot
be changed safely with a small textual patch.

## 5. Compatibility

The Nix layer is an enablement layer, not the source of policy for sandboxing,
Git import, or agent resources. Those policies live in the launcher and sandbox
designs. This keeps `UC-017` through `UC-020` focused on distribution and
reproducibility rather than operational side effects.

The flake recipe helper and skill are additive guidance surfaces. They do not
change the `mkPiShell` contract, existing package outputs, default runtime
selection, or Bubblewrap policy. Future apply modes, if any, must be explicit
and must not silently rewrite project-owned flake structure.
