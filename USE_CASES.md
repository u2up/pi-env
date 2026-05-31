# pi-env Use Cases

`pi-env` is a reusable Nix development shell and Bubblewrap launcher for running `pi-coding-agent` with reproducible tools and a controlled filesystem/environment boundary.

This document summarizes the practical ways the current project can be used.

## 1. Run Pi in the current repository

Use `pi-env` directly as a development shell for this repository or any checkout using the flake:

```bash
nix develop
pi-start
```

This starts Pi through Bubblewrap with the default built-in tool allowlist:

```text
read,bash,edit,write,grep,find,ls
```

`pi-start` runs Pi with `--continue`, so existing scoped sessions for the current project can be resumed.

## 2. Run Pi with custom arguments

Use `pi-bwrap` when you want to pass your own Pi arguments instead of the default startup arguments:

```bash
pi-bwrap -- --model anthropic/claude-sonnet-4-5 "Inspect this repo"
```

If no arguments are supplied, `pi-bwrap` defaults to:

```bash
pi --tools read,bash,edit,write,grep,find,ls --continue
```

Use `pi-bwrap --help` for launcher help. Use `pi-bwrap -- --help` to pass `--help` to Pi itself.

## 3. Use a reproducible Pi runtime shell

Inside `nix develop`, `pi-env` provides a reproducible toolset on `PATH`, including:

- Bash and core GNU utilities
- Bubblewrap
- Git
- Node.js
- ripgrep / fd / jq
- tar/gzip/find/grep/sed/awk
- CA certificates

This lets Pi and its tool calls run with predictable command-line dependencies independent of the host distribution.

## 4. Run Pi inside a filesystem sandbox

`pi-bwrap` is useful whenever Pi should access the current project but not the whole host home directory.

By default it:

- mounts the selected project read-write at `/workspace`;
- uses an isolated sandbox home at `/home/pi`;
- mounts `/nix/store` read-only;
- mounts global npm Pi install paths read-only when present;
- avoids mounting host `$HOME`, `~/.ssh`, cloud credential directories, and Docker sockets;
- clears the environment and passes only selected variables;
- shares the host network unless disabled.

This is the main security-oriented use case for the project.

## 5. Select what project Pi can see

The sandboxed project root can be selected in several ways:

- default: Git repository root, when detected;
- fallback: current working directory;
- disable Git-root detection:

  ```bash
  PI_BWRAP_USE_GIT_ROOT=0 pi-start
  ```

- explicit project root:

  ```bash
  PI_BWRAP_PROJECT_ROOT=/path/to/repo pi-start
  ```

Inside the sandbox, the selected root appears as `/workspace`, and the current working directory is mapped under `/workspace` when possible.

## 6. Keep per-project sandbox state

By default, `pi-env` stores persistent sandbox state outside the project under:

```text
$XDG_STATE_HOME/pi-env/<project-hash>
```

or:

```text
$HOME/.local/state/pi-env/<project-hash>
```

Use this when you want Pi auth/config/cache/session state to persist across runs without placing it in the repository.

You can override the state directory:

```bash
PI_BWRAP_STATE_DIR=/path/to/state pi-start
```

## 7. Run with an ephemeral sandbox home

Use an ephemeral home when you want Pi state to be discarded after the run:

```bash
PI_BWRAP_EPHEMERAL_HOME=1 pi-start
```

This is useful for one-off reviews, demos, CI-like checks, or when testing without contaminating persistent state.

Project session import is disabled by default for ephemeral homes, unless explicitly enabled.

## 8. Import Pi model authentication into the sandbox

By default, `pi-bwrap` copies selected Pi auth/model files from the host Pi agent directory:

```text
auth.json
models.json
```

This allows Pi inside the sandbox to use existing model/provider configuration without mounting the whole host Pi directory.

Disable this behavior with:

```bash
PI_BWRAP_IMPORT_AUTH=0 pi-start
```

Copy only missing files with:

```bash
PI_BWRAP_AUTH_SYNC=missing pi-start
```

## 9. Resume only the current project's Pi sessions

For persistent homes, `pi-env` bind-mounts only the Pi session directory corresponding to the current working directory/project path.

This enables `/resume` and `--continue` for the active project while avoiding exposure of all host Pi sessions.

Disable session import:

```bash
PI_BWRAP_IMPORT_SESSIONS=0 pi-start
```

Enable it explicitly, including for ephemeral homes:

```bash
PI_BWRAP_IMPORT_SESSIONS=1 pi-start
```

## 10. Use common Pi rules, skills, and prompts

`pi-env` can import common user-owned Pi resources into the sandbox agent directory. By default it uses:

```text
$PI_CODING_AGENT_DIR
~/.pi/agent
```

Only these common resources are imported:

```text
AGENTS.md
CLAUDE.md
SYSTEM.md
APPEND_SYSTEM.md
skills/
prompts/
```

Use a separate shared rules/skills repository:

```bash
PI_BWRAP_COMMON_AGENT_DIR=~/CODE/my-pi-common pi-start
```

Disable common resource import:

```bash
PI_BWRAP_IMPORT_COMMON=0 pi-start
```

Preserve existing sandbox copies when present:

```bash
PI_BWRAP_COMMON_SYNC=missing pi-start
```

## 11. Combine common and project-specific Pi behavior

A common setup is:

- common personal/team rules and skills outside the project;
- project-specific rules, skills, and extensions committed inside the project.

Example project layout:

```text
project/
  AGENTS.md
  .pi/
    extensions/
      project-extension.ts
    skills/
      project-skill/
        SKILL.md
    prompts/
    settings.json
```

Pi can load imported common/global resources from `/home/pi/.pi/agent` and discover project-specific resources from `/workspace`.

## 12. Use Pi extensions and packages

Project-local extensions and project-installed packages under `.pi/` are available because the project is mounted at `/workspace`.

Global Pi extensions and globally installed Pi packages from the host Pi agent directory are exposed by default:

```text
~/.pi/agent/extensions/
~/.pi/agent/npm/
~/.pi/agent/git/
~/.pi/agent/settings.json
```

The extension/package directories are mounted read-only into `/home/pi/.pi/agent`; `settings.json` is copied into sandbox state. Disable this with:

```bash
PI_BWRAP_IMPORT_EXTENSIONS=0 pi-start
```

If an extension registers custom tools, include those tool names in `PI_BWRAP_DEFAULT_TOOLS` or pass a custom `--tools` list to `pi-bwrap`.

## 13. Use host Git preferences without exposing credentials

`pi-env` copies host Git configuration into the sandbox by default:

```text
~/.gitconfig
$XDG_CONFIG_HOME/git/config or ~/.config/git/config
```

Inside the sandbox these become:

```text
/home/pi/.gitconfig
/home/pi/.config/git/config
```

This lets Git commands use normal identity, aliases, default branch names, and diff preferences.

Git credentials, SSH keys, signing keys, credential-helper stores, and referenced secret files are not imported automatically.

Disable Git config import:

```bash
PI_BWRAP_IMPORT_GIT_CONFIG=0 pi-start
```

Use alternate config files:

```bash
PI_BWRAP_HOST_GITCONFIG=/path/to/gitconfig pi-start
PI_BWRAP_HOST_XDG_GIT_CONFIG=/path/to/xdg-git-config pi-start
```

## 14. Customize Pi tool access

Override the default Pi tool allowlist:

```bash
PI_BWRAP_DEFAULT_TOOLS="read,grep" pi-start
```

This is useful for least-privilege runs, tool experiments, or enabling additional extension/custom tools registered with Pi.

## 15. Control network and environment exposure

Pi needs network access for most model providers, so the sandbox shares host networking by default.

Disable network sharing:

```bash
PI_BWRAP_NET=0 pi-start
```

Pass selected extra environment variables:

```bash
PI_BWRAP_PASS_ENV="HTTP_PROXY,NO_PROXY" pi-start
```

`pi-env` also passes selected LLM provider variables when set, such as API keys and base URLs for supported providers.

## 16. Use with a globally installed Pi CLI

If Pi is installed globally via npm, `pi-bwrap` can run it by mounting these host paths read-only when present:

```text
/usr/local/bin
/usr/local/lib/node_modules/@earendil-works/pi-coding-agent
```

This supports the common workflow where Nix provides runtime tools while the Pi CLI itself is installed globally.

## 17. Reuse `pi-env` from a new project flake

For a project without an existing flake, add `pi-env` as an input and use `mkPiShell`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
    pi-env.url = "git+file:///path/to/pi-env";
    pi-env.inputs.nixpkgs.follows = "nixpkgs";
    pi-env.inputs.flake-utils.follows = "flake-utils";
  };

  outputs = { nixpkgs, flake-utils, pi-env, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs { inherit system; };
      in {
        devShells.default = pi-env.lib.mkPiShell {
          inherit pkgs;
          extraPackages = [ ];
          shellHook = ''
            echo "project shell loaded"
          '';
        };
      });
}
```

Then run:

```bash
nix develop
pi-start
```

## 18. Add Pi wrappers to an existing project devshell

For a project that already has a flake/devshell, keep the existing shell and add the wrapper packages:

```nix
packages = [
  pi-env.packages.${system}.pi-start
  pi-env.packages.${system}.pi-bwrap
];
```

This lets an existing project keep its own dependencies while gaining sandboxed Pi startup commands.

## 19. Use `pi-env` as a flake package or app

The flake exposes packages:

```text
default
pi-start
pi-bwrap
pi-runtime
```

It also exposes apps:

```text
default
pi-start
pi-bwrap
```

Examples:

```bash
nix run .#pi-bwrap -- --model test/model "hello"
nix build .#pi-runtime
```

## 20. Use the library API in other flakes

`pi-env` exposes these library attributes:

```text
defaultTools
mkRuntime
mkPiBwrap
mkPiStart
mkPiShell
```

Use them to construct project-specific shells, packages, or wrappers while reusing the same runtime and Bubblewrap behavior.

## 21. Test or validate the environment

`pi-env` can be validated through blackbox-style checks:

```bash
nix flake show
nix build .#pi-bwrap
nix build .#pi-start
nix build .#pi-runtime
```

A fake `pi` executable can be placed early on `PATH` to inspect arguments, cwd, environment, and visible files inside the sandbox.

## 22. Safer code-review and automation workflows

Use cases for the isolated launcher include:

- reviewing unfamiliar repositories;
- limiting Pi to a selected workspace;
- avoiding accidental access to host secrets;
- running with a reduced tool allowlist;
- disabling network for offline inspections;
- using ephemeral state for disposable runs;
- importing only the auth/session/config needed for the current project.

## Non-goals and limitations

`pi-env` does not:

- ship personal or team rules/skills/prompts itself;
- mount the whole host home by default;
- import SSH keys, Git credentials, signing keys, cloud credentials, or Docker sockets;
- provide domain-level network allowlisting;
- make enabled Pi tools harmless.

If `read` or `bash` tools are enabled, copied auth files and mounted project sessions can be read by commands/tools inside the sandbox. Use least-privilege API keys, provider proxies, reduced tool allowlists, or `PI_BWRAP_NET=0` when appropriate.
