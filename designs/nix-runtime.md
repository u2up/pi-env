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

## 1. Flake outputs

The flake exposes first-class package and app outputs for the launcher tools so
users and tests can invoke the same artifacts. Packages provide installable
programs; apps provide convenient `nix run` entrypoints.

Development shells include all tools needed for local validation: shell
utilities, Bubblewrap, Node where required by scripts, and test dependencies.
The shell contract is intentionally broader than a single launcher so
blackbox tests and documentation tooling use one reproducible environment.

## 2. Reusable shell construction

`mkPiShell` is the reusable interface for downstream workspaces. It packages
the common runtime dependencies and shell initialization while letting callers
add project-specific inputs. The function is the preferred extension point
instead of duplicating package lists across flakes.

The reusable shell must remain deterministic. Host-specific state such as auth
files, Git preferences, and Pi resources is imported at launcher runtime rather
than baked into Nix derivations.

## 3. Runtime tools

`RUNTIME-001` and `RUNTIME-002` are satisfied by keeping command execution and
tool discovery inside the flake-defined environment when users opt into Nix.
Scripts should still report clear missing-tool errors when run outside that
environment, but the supported path is the reproducible flake shell.

## 4. Compatibility

The Nix layer is an enablement layer, not the source of policy for sandboxing,
Git import, or agent resources. Those policies live in the launcher and sandbox
designs. This keeps `UC-017` through `UC-020` focused on distribution and
reproducibility rather than operational side effects.
