# pi-env Requirements and Blackbox Test Blueprint

This document is derived from the current source tree and git history of `pi-env`. It is intended to be both an implementation contract and a blackbox testing checklist.

## 1. Product scope

`pi-env` provides a reusable Nix development shell and Bubblewrap launcher for `pi-coding-agent`.

An optional extension for Git-backed multi-agent coordination is described in [Agent Coordination Repository Design](AGENT_COORDINATION_DESIGN.md). That design is intentionally separate from the current required runtime/sandbox contract unless requirements in this document explicitly reference it.

Coordination support must be implemented as an opt-in layer. It must not make `pi-start` create, claim, mark done, review, verify, close, commit, push, or otherwise mutate coordination state automatically. Any coordination helper that changes shared state must be explicit, inspectable, and backed by normal Git commits.

The project must keep two responsibilities separate:

- **Nix devshell/runtime:** reproducibly provide command-line tools on `PATH`.
- **Bubblewrap launcher:** isolate the `pi` process from the host filesystem and environment while still allowing controlled access to the current project and selected Pi state.

## 2. History-derived intent

The git history establishes these product requirements:

1. The project started as a Nix flake providing a Pi agent runtime devshell.
2. A startup command was added for running `pi` with an explicit tool allowlist and `--continue`.
3. The launcher evolved from an ad-hoc script to flake-generated commands.
4. The runtime became self-contained and no longer depends on a local `common-nix-runtime` flake.
5. Bubblewrap isolation became the primary runtime boundary.
6. Project-specific Pi sessions were intentionally exposed inside the sandbox, but only for the active project/path.
7. The flake is intended for reuse by other projects through `lib.mkPiShell` or packages.
8. Common Pi rules/skills/prompts/roles are imported from an external user-controlled directory, not shipped by `pi-env`.
9. Host Git configuration is copied into the sandbox by default, but credentials, SSH keys, and host home are not mounted.

## 3. Flake requirements

### FLAKE-001 Inputs

The flake must declare only these normal inputs:

- `nixpkgs` pointing at `github:NixOS/nixpkgs/nixos-25.05`
- `flake-utils` pointing at `github:numtide/flake-utils`

It must not require a local `common-nix-runtime` or other machine-specific flake input.

### FLAKE-002 Systems

The flake must use `flake-utils.lib.eachDefaultSystem` to expose packages, apps, and devshells for default systems.

### FLAKE-003 Library API

The flake must expose `lib` attributes:

- `defaultTools`
- `mkRuntime`
- `mkPiBwrap`
- `mkPiStart`
- `mkPiShell`
- `mkRoleManagerPackage`

### FLAKE-004 Packages

For each supported system the flake must expose packages:

- `default` equal to `pi-start`
- `pi-start`
- `pi-bwrap`
- `pi-runtime`
- `pi-role-manager`
- `bootstrap-coordination`
- `agent-coord-init`
- `agent-coord-clone`
- `agent-coord-new`
- `agent-coord-status`
- `agent-coord-pull`
- `agent-coord-push`
- `agent-coord-claim`
- `agent-coord-done`
- `agent-coord-review`
- `agent-coord-verify`
- `agent-coord-close`
- `agent-coord-upgrade-rules`

### FLAKE-005 Apps

For each supported system the flake must expose apps:

- `default` running `pi-start`
- `pi-start`
- `pi-bwrap`

### FLAKE-006 Devshell

The default devshell must include the runtime packages and wrappers and must print a helpful startup message unless `PI_ENV_QUIET` is set.

The shell prompt must be prefixed with `(nix-dev)`. The shell must export
`PI_ENV_ROLE_MANAGER_PACKAGE` to the Nix-built role-manager Pi package path.

## 4. Runtime package requirements

### RUNTIME-001 Included tools

`mkRuntime` must include at least:

- `bash`
- `bubblewrap`
- `cacert`
- `coreutils`
- `fd`
- `findutils`
- `gawk`
- `git`
- `gnugrep`
- `gnused`
- `gnutar`
- `gzip`
- `jq`
- `nodejs`
- `ripgrep`
- `which`

### RUNTIME-002 Path construction

`pi-bwrap` must prepend the runtime package bin path to the host `PATH` before checking for `pi`.

## 5. Command requirements

### CMD-001 `pi-bwrap` existence

The package `pi-bwrap` must install an executable named `pi-bwrap`.

### CMD-002 `pi-start` existence

The package `pi-start` must install an executable named `pi-start`.

### CMD-003 Default tool allowlist

The canonical default Pi tool list is:

```text
read,bash,edit,write,grep,find,ls
```

### CMD-004 `pi-bwrap` default invocation

When called without Pi arguments, `pi-bwrap` must run Pi with:

```bash
pi --tools read,bash,edit,write,grep,find,ls --continue
```

or with the same structure but replacing the tool list with `PI_BWRAP_DEFAULT_TOOLS` when set.

### CMD-005 `pi-start` invocation

`pi-start` must run `pi-bwrap` with:

```bash
--tools "$tools" --continue "$@"
```

where `$tools` is the default tool list or `PI_BWRAP_DEFAULT_TOOLS` when set.

### CMD-006 Argument separator

`pi-bwrap -- <args>` must strip the separator and pass `<args>` to Pi.

### CMD-007 Help

`pi-bwrap -h` and `pi-bwrap --help` must print launcher help and exit successfully without entering Bubblewrap.

### CMD-008 Missing Pi executable

If `pi` is not found on `PATH` before sandbox entry, `pi-bwrap` must exit with code `127` and print an actionable error.

### CMD-009 Coordination helper commands

The flake/devshell must provide these opt-in coordination commands:

- `bootstrap-coordination`
- `agent-coord-init`
- `agent-coord-clone`
- `agent-coord-status`
- `agent-coord-pull`
- `agent-coord-push`
- `agent-coord-new`
- `agent-coord-claim`
- `agent-coord-done`
- `agent-coord-review`
- `agent-coord-verify`
- `agent-coord-close`
- `agent-coord-upgrade-rules`

`bootstrap-coordination` must remain a thin wrapper around
`agent-coord-init`: it prints the inferred `PI_COORD_*` settings and the
corresponding initialization command, then initializes with those explicit
values unless `--print-only`/`--dry-run` is used. When project/workspace
values are unset, it must infer useful defaults from `PI_COORD_PROJECT`,
the Git origin repository name, the Git root basename, or the current
directory basename, in that order. It must support `--project-root DIR`
to infer and initialize relative to another project/workspace directory;
when doing so, stale context values from `PI_COORD_WORKSPACE`,
`PI_COORD_DIR`, `PI_COORD_PROJECT`, and `PI_COORD_PROJECT_KEY` must not
override the target directory's inferred defaults unless explicit options
are supplied. If the selected coordination clone already exists but the
planned local bare remote is missing or does not contain the clone's
current branch, it must restore that bare remote from committed clone
history, adding `origin` when absent and updating `origin` only when it
points to a missing local path.
`--print-only`/`--dry-run` must not create or restore anything. It must not
claim, mark done, review, verify, close, or otherwise mutate item state
automatically.

### CMD-010 `agent-coord-init`

`agent-coord-init` must create a local bare coordination remote and, unless
`--bare-only` is used, clone and scaffold a working coordination repository.
It must install the rule/protocol templates into:

- `AGENTS.md`
- `docs/SYNC_PROTOCOL.md`
- `docs/ITEM_FORMAT.md`
- `.pi/skills/agent-coordination/SKILL.md`

It must also create the standard workspace/project directory skeleton,
write `WORKSPACE.md` and initial project `PROJECT.md` item-key metadata,
and configure the clone with `pull.rebase=true` and
`rebase.autoStash=true`.

When `--root` and `PI_COORD_ROOT` are omitted, coordination helpers must
use a project-visible `agent-remotes` directory instead of the isolated
sandbox `$HOME`. If `/workspace` resolves to the current project root, the
default root must be `/workspace/agent-remotes`; otherwise it must be
`<project-root>/agent-remotes`.

### CMD-011 `agent-coord-clone`

`agent-coord-clone` must clone a coordination remote into the selected
workspace directory and configure the clone with `pull.rebase=true` and
`rebase.autoStash=true`.

### CMD-012 `agent-coord-new`

`agent-coord-new` must create a YAML item with timestamp-based ID,
top-level current-state fields, `done: null`, `closed: null`,
`reviewed: false`, `verified: false`, title, acceptance-criteria
placeholder, chronological `events`, and linked Markdown `messages`. It must
not commit or push automatically.

The generated item ID prefix must resolve in this order:

1. explicit `--project-key`;
2. stored `item_key` metadata for the selected project or workspace;
3. `PI_COORD_PROJECT_KEY` when no stored key exists;
4. derived `--project` / `PI_COORD_PROJECT` for project items;
5. derived workspace directory name for workspace-level items.

Derived keys must be uppercased with delimiters, whitespace, pipes,
slashes, backslashes, and other non-alphanumeric characters removed.
`--id` must override the whole item ID.

Project item keys must be stored in `projects/<project>/PROJECT.md` as
`item_key`; workspace-level item keys must be stored in `WORKSPACE.md` as
`item_key`.

### CMD-013 Coordination lifecycle helpers

The lifecycle helpers must remain thin wrappers around Git and YAML item
file edits:

- `agent-coord-status` shows Git status and open/blocked/done item summaries;
- `agent-coord-pull` runs `git pull --rebase --autostash`;
- `agent-coord-push` commits staged/all changes and pushes;
- coordination commands that create item events or commits accept
  `--role ROLE`, read `PI_COORD_ROLE`, store actor ID/role metadata in
  events, and use per-command Git identity overrides for coordination
  commits;
- `agent-coord-claim` pulls, sets `status: claimed`, sets `owner:`, updates
  `current:`, appends a `claimed` event/message, commits, and pushes unless
  disabled by options;
- `agent-coord-done` pulls, moves issue items to `done/`, sets
  `status: done`, `done: <timestamp>`, `closed: null`, `reviewed: false`,
  and `verified: false`, appends a `done` event/message with optional
  structured implementation refs (`repo`, `branch`, full `commit`), commits,
  and pushes unless disabled by options. Its `--implementation-ref` option may
  accept `repo:branch@full-commit` as a compact CLI input format;
- `agent-coord-review` pulls, marks done items reviewed on pass, or moves
  them back to `open/` with `reviewed: false`, `verified: false`, and a
  `review_failed` event on failure, then commits and pushes unless disabled
  by options;
- `agent-coord-verify` pulls, marks done items verified on pass, or moves
  them back to `open/` with `reviewed: false`, `verified: false`, and a
  `verification_failed` event on failure, then commits and pushes unless
  disabled by options;
- `agent-coord-close` pulls, requires `status: done`, `reviewed: true`, and
  `verified: true` unless forced, moves issue items to `closed/`, sets closed
  YAML current-state fields, appends a `closed` event/message, commits, and
  pushes unless disabled by options.

Commands that create commits must reject subject lines longer than 72
characters.

### CMD-014 `agent-coord-upgrade-rules`

`agent-coord-upgrade-rules --preview` must show template diffs without
changing files. Without `--preview`, it must require a clean worktree, copy
bundled coordination rule templates into their installed locations, and
commit the changes when any template differs. It must not push unless
`--push` is used.

### CMD-015 Role-manager package

The role-manager resources must be packaged as an installable Pi package or
equivalent local resource bundle. The package must include:

- `package.json` with the `pi-package` keyword and a `pi.extensions` manifest;
- `extensions/role-manager.ts`;
- `lib/role-loader.mjs` and `lib/role-schema.mjs`;
- bundled base roles under `roles/`;
- schema and user documentation.

The flake package `pi-role-manager` must expose this package directory so it
can be loaded with `pi-start -e "$PI_ENV_ROLE_MANAGER_PACKAGE"` from the
devshell or installed with `pi-bwrap install -l <path>`.

## 6. Project root and working directory requirements

### PATH-001 Project root detection

Unless `PI_BWRAP_PROJECT_ROOT` is set, `pi-bwrap` must use `git rev-parse --show-toplevel` when `PI_BWRAP_USE_GIT_ROOT` is unset or `1`.

If git-root detection fails or is disabled, it must use `$PWD`.

### PATH-002 Project root override

`PI_BWRAP_PROJECT_ROOT=/path` must force the mounted project root.

### PATH-003 Existing project root

If the resolved project root is not a directory, `pi-bwrap` must exit with code `2`.

### PATH-004 Workspace mount

The selected project root must be mounted read-write at `/workspace`.

### PATH-005 Sandbox cwd mapping

If the host cwd is inside the project root, the sandbox cwd must be the corresponding path under `/workspace`. Otherwise, the sandbox cwd must be `/workspace`.

## 7. Sandbox filesystem requirements

### FS-001 Home isolation

The sandbox `HOME` must be `/home/pi`; the host home directory must not be mounted wholesale.

### FS-002 State directory

By default, persistent sandbox state must be stored outside the project under:

```text
$XDG_STATE_HOME/pi-env/<project-hash>
```

or `$HOME/.local/state/pi-env/<project-hash>` when `XDG_STATE_HOME` is unset.

`<project-hash>` must be a deterministic hash of the resolved project root, truncated to 16 hex characters.

### FS-003 Explicit state directory

`PI_BWRAP_STATE_DIR=/path` must override the persistent state directory.

### FS-004 Ephemeral home

`PI_BWRAP_EPHEMERAL_HOME=1` must use a temporary state directory and remove it when the launcher exits.

### FS-005 State layout

The launcher must create these directories as needed:

- `$state_base/home/.pi/agent`
- `$state_base/home/.cache`
- `$state_base/home/.config/git`
- `$state_base/agent/sessions`
- `$state_base/cache`

### FS-006 State permissions

Best-effort permissions for private state directories must be `0700`; copied auth and git config files must be best-effort `0600`.

### FS-007 Nix store

`/nix/store` must be mounted read-only so Nix-provided runtime tools work inside the sandbox.

### FS-008 Global Pi install support

When present, `/usr/local/bin` and `/usr/local/lib/node_modules/@earendil-works/pi-coding-agent` must be mounted read-only so a global npm-installed `pi` can run.

### FS-009 System support files

The sandbox must make reasonable read-only host support files available when present, including passwd/group, nsswitch, hosts, resolver config, and certificate locations.

### FS-010 No sensitive host mounts

The launcher must not mount host `~/.ssh`, cloud credential directories, Docker sockets, or the host home directory by default.

## 8. Pi agent resource requirements

### AGENT-001 Agent dir inside sandbox

Inside the sandbox:

- `PI_CODING_AGENT_DIR` must be `/home/pi/.pi/agent`
- `PI_CODING_AGENT_SESSION_DIR` must be `/home/pi/.pi/agent/sessions`

### AGENT-002 Host agent directory detection

The host Pi agent directory must be selected in this order:

1. `PI_BWRAP_HOST_AGENT_DIR`
2. `PI_CODING_AGENT_DIR`
3. `$HOME/.pi/agent`

### AGENT-003 Common agent resource directory

The common resource directory must default to the selected host agent directory and be overridable with `PI_BWRAP_COMMON_AGENT_DIR`.

### AGENT-004 Common resources imported

When common import is enabled and the common directory exists, the launcher must import only:

- `AGENTS.md`
- `CLAUDE.md`
- `SYSTEM.md`
- `APPEND_SYSTEM.md`
- `skills/`
- `prompts/`
- `roles/`

### AGENT-005 Common import disable

`PI_BWRAP_IMPORT_COMMON=0` must disable common resource import.

### AGENT-006 Common sync policy

`PI_BWRAP_COMMON_SYNC=always` or unset must refresh common resources each run.

`PI_BWRAP_COMMON_SYNC=missing` must copy only resources that are absent in sandbox state.

### AGENT-007 Auth files imported

When auth import is enabled and the host agent directory exists, the launcher must copy only these auth/model files:

- `auth.json`
- `models.json`

### AGENT-008 Auth import disable

`PI_BWRAP_IMPORT_AUTH=0` must prevent copying `auth.json` and `models.json`.

### AGENT-009 Auth sync policy

`PI_BWRAP_AUTH_SYNC=always` or unset must refresh auth/model files each run.

`PI_BWRAP_AUTH_SYNC=missing` must copy only absent auth/model files.

### AGENT-010 Global extensions and packages

When extension import is enabled and the host agent directory exists, the launcher must make globally available Pi extensions and installed Pi packages usable inside the sandbox:

- copy `settings.json` into the sandbox agent directory;
- expose `extensions/`, `npm/`, and `git/` from the host agent directory read-only when present.

Project-local `.pi/extensions`, `.pi/settings.json`, `.pi/npm`, and `.pi/git` are available through the `/workspace` project mount.

### AGENT-010a Extension import disable

`PI_BWRAP_IMPORT_EXTENSIONS=0` must prevent copying `settings.json` and exposing host global `extensions/`, `npm/`, and `git/` directories.

### AGENT-010b Extension sync policy

`PI_BWRAP_EXTENSIONS_SYNC=always` or unset must refresh the sandbox copy of `settings.json` each run.

`PI_BWRAP_EXTENSIONS_SYNC=missing` must copy `settings.json` only when it is absent in sandbox state.

### AGENT-011 Sessions default

Project sessions must be imported/bind-mounted by default for persistent homes, and disabled by default for ephemeral homes.

### AGENT-012 Sessions override

`PI_BWRAP_IMPORT_SESSIONS=0` must disable session bind mounting.

`PI_BWRAP_IMPORT_SESSIONS=1` must enable session bind mounting, including with ephemeral homes.

### AGENT-013 Session scope

The launcher must bind only the host Pi session directory corresponding to the current host cwd into the sandbox session directory corresponding to the mapped sandbox cwd.

It must not mount all host Pi sessions.

### AGENT-014 Session naming

Session directory names must be derived by normalizing the path, stripping the leading slash, replacing `/` and `:` with `-`, and surrounding the result with `--`.

### AGENT-015 Session migration

Before bind-mounting host sessions, the launcher may copy existing sandbox session `*.jsonl` files into the host project session directory without overwriting existing files.

## 9. Git configuration requirements

### GIT-001 Git config import default

Host Git configuration import must be enabled by default.

### GIT-002 Global git config source

The global Git config source must default to `$HOME/.gitconfig` and be overridable with `PI_BWRAP_HOST_GITCONFIG`.

### GIT-003 XDG git config source

The XDG Git config source must default to `$XDG_CONFIG_HOME/git/config` when `XDG_CONFIG_HOME` is set, otherwise `$HOME/.config/git/config`, and be overridable with `PI_BWRAP_HOST_XDG_GIT_CONFIG`.

### GIT-004 Git config targets

Copied Git config files must appear inside the sandbox as:

- `/home/pi/.gitconfig`
- `/home/pi/.config/git/config`

### GIT-005 Git config disable

`PI_BWRAP_IMPORT_GIT_CONFIG=0` must prevent importing Git config.

### GIT-006 Git config sync policy

`PI_BWRAP_GIT_CONFIG_SYNC=always` or unset must refresh copied Git config each run.

`PI_BWRAP_GIT_CONFIG_SYNC=missing` must preserve existing sandbox copies.

### GIT-007 No credential import

Git credentials, SSH keys, signing keys, credential helper backing stores, and other referenced files must not be imported automatically.

### GIT-008 System Git config

The sandbox must set `GIT_CONFIG_NOSYSTEM=1`.

## 10. Environment requirements

### ENV-001 Clear environment

Bubblewrap must be invoked with `--clearenv`.

### ENV-002 Basic terminal variables

The launcher must set or pass through terminal-related variables:

- set `TERM`, defaulting to `xterm-256color`
- pass `COLORTERM` when set and non-empty
- pass `NO_COLOR` when set and non-empty
- pass `FORCE_COLOR` when set and non-empty

### ENV-003 Provider credentials

The launcher may pass selected LLM provider variables, including API keys and base URLs listed in `flake.nix`. No arbitrary host environment variable may be passed unless explicitly requested.

### ENV-004 Extra environment pass-through

`PI_BWRAP_PASS_ENV` must accept extra environment variable names separated by spaces, commas, or colons and pass through only those names when set and non-empty.

### ENV-005 Sandbox identity/env

Inside the sandbox the launcher must set:

- `HOME=/home/pi`
- `SHELL=/bin/bash`
- `USER=pi`
- `LOGNAME=pi`
- `PWD` to the mapped sandbox cwd
- `XDG_CACHE_HOME=/home/pi/.cache`
- `TMPDIR=/tmp`
- `PATH` to include the Nix runtime path, `/usr/local/bin`, `/usr/bin`, and `/bin`
- `SSL_CERT_FILE` and `NIX_SSL_CERT_FILE` to Nix `cacert`
- `PI_SKIP_VERSION_CHECK`, defaulting to `1`
- `PI_TELEMETRY`, defaulting to `0`

### ENV-006 Coordination context

When set, the launcher must pass safe coordination context into the
sandbox:

- `PI_COORD_ROOT`
- `PI_COORD_WORKSPACE`
- `PI_COORD_AGENT_ID`
- `PI_COORD_PROJECT_KEY`
- `PI_COORD_ROLE`

If `PI_COORD_ROOT` points inside the selected project, the launcher must
pass it into the sandbox as the corresponding `/workspace/...` path.

If host `/workspace/agent-remotes` exists and is not already provided by
the selected project mount, the launcher must bind it into the sandbox at
`/workspace/agent-remotes` so common bare coordination remotes are available
from inside and outside Bubblewrap through the same path.

If a coordination clone is detected under the selected project, or selected
with `PI_COORD_DIR`/`PI_BWRAP_COORDINATION_DIR`, the launcher must set
`PI_COORD_DIR` inside the sandbox to the sandbox-visible path.

`PI_BWRAP_COORDINATION_DIR=/path/to/coordination` must explicitly bind an
external coordination clone read-write at `/coordination`. The launcher may
print a reminder when a coordination repository is available, but it must
not mutate coordination state.

## 11. Network requirements

### NET-001 Default network

The sandbox must share the host network by default so Pi can reach model providers.

### NET-002 Disable network

`PI_BWRAP_NET=0` must avoid adding Bubblewrap `--share-net`.

## 12. Documentation requirements

### DOC-000 Design documents

Design proposals that are not yet mandatory runtime behavior must be documented separately and referenced from requirements/use-case documentation. The Git-backed multi-agent coordination design is documented in [Agent Coordination Repository Design](AGENT_COORDINATION_DESIGN.md). Implemented coordination behavior is limited to explicit requirements for concrete commands, files, and environment variables in this document.

### DOC-001 README coverage

`README.md` must document:

- project purpose
- `pi-start` and `pi-bwrap` commands
- default tool list
- Bubblewrap safety defaults
- environment knobs
- reuse from another project with and without an existing flake
- common vs project-specific rules, skills, prompts, and roles
- optional role-manager package setup, role sources, commands, and tool allowlists
- Git config import behavior
- opt-in coordination helper basics
- safe coordination context/mount behavior
- security notes and limitations

## 13. Blackbox test blueprint

These tests should be run from outside implementation internals where possible, using a temporary project and temporary host home/agent directories. A fake `pi` executable can be placed early on `PATH` to record argv, cwd, environment, and visible files.

### TEST-001 Flake metadata

Command:

```bash
nix flake show
```

Expected:

- packages include `pi-start`, `pi-bwrap`, `pi-runtime`, `pi-role-manager`, and `default`
- apps include `pi-start`, `pi-bwrap`, and `default`
- `devShells.default` exists

### TEST-002 Flake builds

Commands:

```bash
nix build .#pi-bwrap
nix build .#pi-start
nix build .#pi-runtime
nix build .#pi-role-manager
nix build .#agent-coord-init
nix build .#agent-coord-clone
nix build .#agent-coord-new
nix build .#agent-coord-status
nix build .#agent-coord-pull
nix build .#agent-coord-push
nix build .#agent-coord-claim
nix build .#agent-coord-done
nix build .#agent-coord-review
nix build .#agent-coord-verify
nix build .#agent-coord-close
nix build .#agent-coord-upgrade-rules
```

Expected: all builds succeed.

### TEST-003 Help does not require Pi

Command with `PATH` excluding real/fake `pi`:

```bash
nix run .#pi-bwrap -- --help
```

Expected: help text is printed and exit code is `0`.

### TEST-004 Missing Pi

Run `pi-bwrap` where no `pi` executable is on `PATH`.

Expected:

- exit code `127`
- stderr says `pi was not found on PATH before entering the sandbox`

### TEST-005 Default Pi arguments

With fake `pi` on `PATH`, run:

```bash
pi-bwrap
```

Expected fake Pi sees:

```text
--tools read,bash,edit,write,grep,find,ls --continue
```

### TEST-006 Argument separator

With fake `pi`, run:

```bash
pi-bwrap -- --model test/model "hello"
```

Expected fake Pi sees exactly:

```text
--model test/model hello
```

### TEST-007 `pi-start` preserves extra args

With fake `pi`, run:

```bash
pi-start --model test/model
```

Expected fake Pi sees `--tools <default-tools> --continue --model test/model`.

### TEST-008 Default tools override

With fake `pi`, run:

```bash
PI_BWRAP_DEFAULT_TOOLS=read,grep pi-start
```

Expected fake Pi sees `--tools read,grep --continue`.

### TEST-009 Project root is mounted at `/workspace`

Create a git repo with a subdirectory, run from the subdirectory, and have fake Pi record cwd.

Expected:

- cwd inside sandbox is `/workspace/<subdir>`
- files from git root are visible under `/workspace`

### TEST-010 Disable git-root detection

From a subdirectory in a git repo, run:

```bash
PI_BWRAP_USE_GIT_ROOT=0 pi-bwrap -- <fake args>
```

Expected `/workspace` corresponds to the subdirectory, not the git root.

### TEST-011 Project root override

Run with:

```bash
PI_BWRAP_PROJECT_ROOT=/tmp/other-project pi-bwrap
```

Expected `/workspace` contains `/tmp/other-project`.

### TEST-012 Missing project root

Run with a nonexistent `PI_BWRAP_PROJECT_ROOT`.

Expected exit code `2`.

### TEST-013 Persistent state location

With temporary `HOME` and `XDG_STATE_HOME`, run `pi-bwrap`.

Expected a deterministic directory is created under `$XDG_STATE_HOME/pi-env/<16-char-hash>` with the required state layout.

### TEST-014 Explicit state location

Run with `PI_BWRAP_STATE_DIR=/tmp/pi-state`.

Expected state is created under `/tmp/pi-state` and not under the default state parent.

### TEST-015 Ephemeral state cleanup

Run with `PI_BWRAP_EPHEMERAL_HOME=1` and have fake Pi record `$HOME` and create a marker in it.

Expected:

- inside sandbox `HOME=/home/pi`
- temporary state directory is removed after exit
- project session import defaults to disabled

### TEST-016 Common resource import

Create host common dir containing all supported common files plus unsupported files.

Run with `PI_BWRAP_COMMON_AGENT_DIR=<dir>`.

Expected inside `/home/pi/.pi/agent`:

- supported files/dirs are present
- unsupported files are absent

### TEST-017 Common import disabled

Run with `PI_BWRAP_IMPORT_COMMON=0`.

Expected no common resources are copied into sandbox state.

### TEST-018 Common sync missing

Pre-create a sandbox common file, then run with `PI_BWRAP_COMMON_SYNC=missing` and a different host version.

Expected the existing sandbox file is not overwritten.

### TEST-019 Auth import

Create host `auth.json` and `models.json` plus unrelated files.

Expected only `auth.json` and `models.json` are copied to the sandbox agent state, mode best-effort `0600`.

### TEST-020 Auth import disabled

Run with `PI_BWRAP_IMPORT_AUTH=0`.

Expected no auth/model files are copied.

### TEST-021 Session scope

Create several host session directories, including one for the current cwd and one unrelated.

Expected inside sandbox only the mapped current-cwd session directory is visible/bound; unrelated sessions are not visible.

### TEST-022 Session import disabled

Run with `PI_BWRAP_IMPORT_SESSIONS=0`.

Expected no host session directory is bind-mounted.

### TEST-023 Git config import

Create temporary host `.gitconfig` and `.config/git/config`.

Expected inside sandbox:

- `/home/pi/.gitconfig` exists with same content
- `/home/pi/.config/git/config` exists with same content
- `GIT_CONFIG_NOSYSTEM=1`

### TEST-024 Git config import disabled

Run with `PI_BWRAP_IMPORT_GIT_CONFIG=0`.

Expected git config files are absent unless already present from prior state.

### TEST-025 Git config sync missing

Pre-create sandbox Git config, run with `PI_BWRAP_GIT_CONFIG_SYNC=missing` and different host config.

Expected sandbox config is preserved.

### TEST-026 Environment clearing

Set arbitrary host variables and selected pass-through variables.

Expected:

- arbitrary unlisted variable is absent inside sandbox
- selected provider variables are present when non-empty
- `PI_BWRAP_PASS_ENV` variables are present when non-empty

### TEST-027 Network flag default and disable

Use a fake `bwrap` wrapper or inspect behavior in an environment where Bubblewrap invocation can be recorded.

Expected:

- default invocation includes `--share-net`
- `PI_BWRAP_NET=0` invocation does not include `--share-net`

### TEST-028 Sensitive host filesystem isolation

With fake Pi, attempt to read host-only files such as host home markers, `.ssh`, and Docker socket path.

Expected they are not visible unless they are inside the selected project root or explicitly copied by supported import behavior.

### TEST-029 Coordination MVP helpers

Run `tests/agent-coord-blackbox.sh` from the repository root.

Expected:

- `agent-coord-init` creates a bare remote and scaffolded clone;
- generated rules, docs, Pi skill files, and key metadata files exist;
- clone Git settings enable rebase and autostash;
- `agent-coord-clone` can clone the same domain;
- `agent-coord-new` creates a timestamp-ID YAML item;
- status, push, claim, done, review, verify, and close helpers perform the
  expected file and Git state transitions;
- rule upgrade preview runs without mutating coordination state.

### TEST-030 Coordination conflict hardening

Run `tests/agent-coord-concurrency.sh` from the repository root.

Expected:

- a stale no-pull claim cannot push over another agent's claim;
- a pulled clone refuses to claim or mark done an item owned by another
  agent;
- a done item cannot be final-closed before both review and verification
  pass;
- reviewers/testers can record pass/fail evidence and other clones can pull
  the final closed result;
- helper-generated commit subjects longer than 72 characters are rejected.

### TEST-031 Role-manager package and commands

Run the role-manager smoke tests from the repository root:

```bash
tests/role-manager-package.sh
tests/role-manager-schema.sh
tests/role-manager-loader.sh
tests/role-manager-commands.sh
```

Expected:

- the role-manager manifest is a Pi package with the expected extension;
- the flake exposes `pi-role-manager` and the devshell package path;
- common-resource handling includes `roles/` directories;
- bundled and example project roles validate;
- loader precedence, active-role prompt injection, command behavior,
  one-cycle termination, UI setup, and role-aware coordination environment
  behavior pass.

## 14. Coordination implementation guard

Git-backed coordination support, when enabled, must keep the same design boundaries:

- one bare coordination repository is one coordination domain;
- coordination repositories are plain Git repositories containing Markdown and small metadata blocks;
- helper commands are thin wrappers around Git and file scaffolding/editing;
- `pi-start` may only provide safe context, reminders, or mounts for coordination repositories;
- `pi-start` must not create, claim, mark done, review, verify, close, commit, push, or otherwise mutate coordination state automatically;
- no daemon, database, background push, force-push, hidden lock service, or non-Git synchronization mechanism may be introduced for coordination state.

Coordination behavior becomes mandatory only when a requirement in this document names a concrete command, file, or environment variable.

## 15. Non-goals and caveats

- Agent coordination repository infrastructure is optional unless implemented and promoted into explicit requirements above.
- Bubblewrap does not provide domain-level network allowlisting.
- If `read`/`bash` tools are enabled, copied auth files, exposed global extensions/packages, and bound project sessions are readable by commands/tools inside the sandbox.
- `pi-env` does not ship user-specific common rules, skills, prompts, or extensions; it imports/exposes them from an external directory when configured.
- Git credential stores and SSH/signing keys are intentionally not imported automatically.
