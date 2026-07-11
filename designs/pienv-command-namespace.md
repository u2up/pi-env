# pienv command namespace

## Goal

Introduce `pienv` as the new canonical user-facing command namespace while
keeping existing `.pi-env/` state paths and `PI_ENV_*` environment variables
unchanged. This design intentionally does not decide whether existing
user-facing commands are deprecated or removed; that decision is deferred until
the new command set is implemented and operational.

## Command model

`pienv` owns naming, grouping, help, and shell completion. Existing scripts
continue to own behavior. The first implementation should therefore be a thin
Bash dispatcher that resolves a subcommand path and then `exec`s the matching
existing command with unchanged remaining arguments.

`pienv` without a subcommand behaves like today's `pi-env` default launcher.
`pienv run` is an explicit alias for the same behavior.

## Canonical command mapping

| New command | Existing behavior source |
| --- | --- |
| `pienv [pi args...]` | `pi-env [pi args...]` |
| `pienv run [pi args...]` | `pi-env [pi args...]` |
| `pienv raw -- [pi args...]` | `pi-env --raw -- [pi args...]` |
| `pienv shell [shell args...]` | `pi-env-shell [shell args...]` |
| `pienv sandbox [pi args...]` | `pi-bwrap [pi args...]` |
| `pienv sandbox shell [shell args...]` | `pi-bwrap --shell -- [shell args...]` |
| `pienv coord bootstrap [options]` | `bootstrap-coordination [options]` |
| `pienv coord init [options]` | `agent-coord-init [options]` |
| `pienv coord clone [options] [remote]` | `agent-coord-clone [options] [remote]` |
| `pienv coord status [options]` | `agent-coord-status [options]` |
| `pienv coord list [options] TYPE [STATUS]` | `agent-coord-list [options] TYPE [STATUS]` |
| `pienv coord show [options] ITEM` | `agent-coord-cat [options] ITEM` |
| `pienv coord new [options] "title"` | `agent-coord-new [options] "title"` |
| `pienv coord claim [options] ITEM` | `agent-coord-claim [options] ITEM` |
| `pienv coord done [options] ITEM` | `agent-coord-done [options] ITEM` |
| `pienv coord review [options] ITEM` | `agent-coord-review [options] ITEM` |
| `pienv coord verify [options] ITEM` | `agent-coord-verify [options] ITEM` |
| `pienv coord close [options] ITEM` | `agent-coord-close [options] ITEM` |
| `pienv coord pull [options] [git args...]` | `agent-coord-pull [options] [git args...]` |
| `pienv coord push [options] [git args...]` | `agent-coord-push [options] [git args...]` |
| `pienv coord lint [options]` | `agent-coord-lint [options]` |
| `pienv coord repo ...` | `agent-coord-repo ...` |
| `pienv coord rules upgrade [options]` | `agent-coord-upgrade-rules [options]` |
| `pienv coord requirements generate [...]` | `agent-coord-generate-requirements [...]` |
| `pienv coord requirements coverage [...]` | `agent-coord-generate-requirements-coverage [...]` |
| `pienv roles serial [options]` | `pi-serial-roles [options]` |
| `pienv install [options]` | `scripts/install-non-nix [options]` or installed installer wrapper |
| `pienv uninstall [options]` | installed uninstall behavior |
| `pienv completion bash` | print Bash completion for `pienv` |

## Behavioral parity rules

Replacement commands must honor exactly the same parameters and behavior as the
old commands after the new subcommand path is consumed. This includes exit
status, stdout/stderr behavior, working directory assumptions, environment
variable handling, support-file resolution, and all existing options.

The dispatcher must not reimplement coordination, sandbox, runtime-selection,
or install behavior. It should select the existing implementation and preserve
argument order. Representative examples:

```bash
pienv coord status --repo-id pi-env
# execs agent-coord-status --repo-id pi-env

pienv shell --runtime nix
# execs pi-env-shell --runtime nix

pienv sandbox shell -- -l
# execs pi-bwrap --shell -- -l
```

Because `pienv` also means "run Pi", top-level subcommand names are reserved
first arguments. Users who need to pass a first Pi argument that looks like a
subcommand should use `--`:

```bash
pienv -- shell
pienv -- coord status
```

## Runtime and packaging requirements

The `pienv` command set must work in all currently supported entry contexts:

a direct checkout, a host-runtime non-Nix installation, `nix develop`, and
`nix run`/flake app usage. Nix and host wrappers must expose the same command
namespace and must resolve the same support files as the existing commands.

The implementation must keep `.pi-env/` operational state paths and `PI_ENV_*`
environment variables unchanged. New command names are UX aliases over the
current runtime and coordination model, not a storage or configuration
migration.

## Help and Bash completion

The command set should include both installed Bash completion and a portable
completion printer:

```bash
pienv completion bash
source <(pienv completion bash)
```

Completion should cover top-level commands, nested `coord`, `roles`,
`sandbox`, and `completion` subcommands, and known options for leaf commands.
Path-valued options should keep path completion. Rich descriptions are not a
Bash completion requirement; command discovery should rely on completion while
explanatory text comes from help.

Help should support:

```bash
pienv help
pienv help coord
pienv help coord status
pienv coord status --help
```

Leaf help may dispatch to the existing command's `--help` output. Group help
should list available subcommands and their existing-command equivalents.

## Deferred compatibility decision

This design does not deprecate, warn on, hide, or remove existing user-facing
commands. Compatibility policy for `pi-env`, `pi-env-shell`, `pi-bwrap`,
`agent-coord-*`, `bootstrap-coordination`, and `pi-serial-roles` will be decided
after `pienv` is implemented, packaged, documented, and verified.

## Covers

| Requirement | Coordination item |
|-------------|-------------------|
| CMD-023 | PIENV-FRQ-20260711-092100-001 |
| CMD-024 | PIENV-FRQ-20260711-092100-002 |
| CMD-025 | PIENV-FRQ-20260711-092100-003 |
| CRQ-015 | PIENV-CRQ-20260711-092100-001 |
