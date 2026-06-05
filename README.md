# pi-env

Reusable Nix devshell for `pi-coding-agent` with a Bubblewrap launcher.

This project keeps the Nix devshell role separate from the security boundary:

- **Nix devshell**: reproducible tools on `PATH` (`node`, `git`, `rg`, `jq`, `fd`, `tar`, etc.).
- **Bubblewrap**: filesystem/environment isolation for the whole `pi` process.

## Commands

Inside `nix develop` the prompt is prefixed with `(nix-dev)`. Start Pi with:

```bash
pi-start
```

`pi-start` runs:

```bash
pi-bwrap --tools read,bash,edit,write,grep,find,ls --continue
```

For custom Pi arguments:

```bash
pi-bwrap -- --model anthropic/claude-sonnet-4-5 "Inspect this repo"
```

### Running `pi config`

Pi's `config` subcommand is used to enable or disable extensions, skills, prompt templates, and themes.

To edit the **sandboxed pi-env config**, run it through Bubblewrap:

```bash
pi-bwrap -- config
# or
pi-bwrap config
```

Inside the sandbox, Pi uses `/home/pi/.pi/agent/settings.json`, backed by pi-env's per-project state directory. Project-local config remains the mounted repo's `.pi/settings.json` under `/workspace`.

By default, pi-env copies the host `settings.json` into sandbox state on each run when global extensions/packages are imported. If you want sandbox edits made by `pi-bwrap -- config` to persist instead of being refreshed from the host copy, use:

```bash
PI_BWRAP_EXTENSIONS_SYNC=missing pi-bwrap -- config
```

To edit your **real host/global Pi config**, run `pi config` directly after entering the Nix devshell:

```bash
nix develop
pi config
```

This uses the Nix-provided runtime/tools on `PATH`, but does **not** enter the Bubblewrap sandbox. It modifies the host Pi agent config, normally `~/.pi/agent/settings.json` unless `PI_CODING_AGENT_DIR` points elsewhere.

## Agent coordination helpers

`pi-env` includes opt-in helpers for Git-backed coordination repositories.
They are plain Git/Markdown tooling and are separate from `pi-start`.

Minimal setup:

```bash
export PI_COORD_ROOT=~/agent-remotes
export PI_COORD_WORKSPACE=piws
export PI_COORD_DIR=coordination
export PI_COORD_AGENT_ID=agent-a

agent-coord-init --project pi-env
```

This creates a bare remote at:

```text
$PI_COORD_ROOT/$PI_COORD_WORKSPACE-coordination.git
```

and clones/scaffolds `$PI_COORD_DIR` with `AGENTS.md`, protocol docs,
item-format docs, and `.pi/skills/agent-coordination/SKILL.md`.

Clone the same coordination domain elsewhere with:

```bash
agent-coord-clone
```

Create a timestamp-ID item with:

```bash
agent-coord-new --project pi-env "Document pi config behavior"
agent-coord-push -m "Add PI-ENV documentation item"
```

Lifecycle helpers are also available:

```text
agent-coord-status    show sync status and open/blocked items
agent-coord-pull      run git pull --rebase --autostash
agent-coord-push      commit and push coordination changes
agent-coord-claim     claim an item, commit, and push
agent-coord-close     close an item, commit, and push
```

The helpers do not make `pi-start` create, claim, close, commit, or push
coordination state automatically. If a coordination clone is under the
mounted project, `pi-bwrap` only exposes it as normal project files and sets
`PI_COORD_DIR` to the sandbox path. For a coordination clone outside the
project, opt in explicitly:

```bash
PI_BWRAP_COORDINATION_DIR=/path/to/coordination pi-start
```

That clone is mounted read-write at `/coordination` and `PI_COORD_DIR` is
set to `/coordination` inside the sandbox. See
`AGENT_COORDINATION_DESIGN.md` for the full design.

## Bubblewrap safety defaults

`pi-bwrap`:

- mounts the detected project root read-write at `/workspace`;
- mounts `/nix/store` read-only so devshell tools work;
- mounts `/usr/local/bin` and the global Pi npm package read-only when present, so a global npm-installed `pi` works;
- uses isolated `$HOME=/home/pi`;
- stores sandbox Pi state outside the project by default under `$XDG_STATE_HOME/pi-env/<project-hash>`;
- imports common Pi rules/skills/prompts from the host Pi agent directory by default (`$PI_CODING_AGENT_DIR`, else `~/.pi/agent`), limited to `AGENTS.md`, `CLAUDE.md`, `SYSTEM.md`, `APPEND_SYSTEM.md`, `skills/`, and `prompts/`;
- exposes global Pi extensions and installed package directories from the host Pi agent directory by default (`extensions/`, `npm/`, `git/`) and copies `settings.json`, while project-local `.pi/extensions` and `.pi/settings.json` are available through `/workspace`;
- copies host Git config into the sandbox by default (`~/.gitconfig` and `$XDG_CONFIG_HOME/git/config` / `~/.config/git/config`), but not Git credentials or SSH keys;
- copies host Pi model auth files (`auth.json`, `models.json`) from `~/.pi/agent` into sandbox state by default;
- bind-mounts only the host Pi session directory for the current working directory into the sandbox by default (disabled for ephemeral homes), so `/resume` and `--continue` can access sessions for the directory/project without exposing all sessions;
- passes `PI_COORD_WORKSPACE`, `PI_COORD_AGENT_ID`, and coordination directory context when set, and can explicitly mount an external coordination clone with `PI_BWRAP_COORDINATION_DIR`;
- does **not** mount host `$HOME`, `~/.ssh`, cloud credential directories, or Docker sockets;
- clears the environment, then passes only terminal basics and selected LLM provider variables;
- shares the host network by default so Pi can reach model providers.

Important: with the `bash`/`read` tools enabled, auth copied into the sandbox and project sessions bind-mounted into the sandbox can be read by commands/tools inside the sandbox. This is still safer than mounting your whole home, but use least-privilege API keys or a provider proxy when possible.

## Useful environment knobs

```bash
PI_BWRAP_PROJECT_ROOT=/path/to/repo     # default: git root, else $PWD
PI_BWRAP_USE_GIT_ROOT=0                 # bind only $PWD
PI_BWRAP_STATE_DIR=/path/to/state       # persistent sandbox home/config
PI_BWRAP_EPHEMERAL_HOME=1               # temporary home/config for this run
PI_BWRAP_IMPORT_AUTH=0                  # do not import host ~/.pi/agent auth files
PI_BWRAP_AUTH_SYNC=missing              # copy auth only if sandbox copy is absent; default is always
PI_BWRAP_IMPORT_SESSIONS=0              # do not bind host sessions for the current working directory; defaults to 1 unless PI_BWRAP_EPHEMERAL_HOME=1
PI_BWRAP_HOST_AGENT_DIR=/path/to/agent  # default: $PI_CODING_AGENT_DIR or ~/.pi/agent
PI_BWRAP_COMMON_AGENT_DIR=/path/to/dir  # common rules/skills dir; default: host Pi agent dir
PI_BWRAP_IMPORT_COMMON=0                # do not import common AGENTS/SYSTEM files, skills, or prompts
PI_BWRAP_COMMON_SYNC=missing            # copy common files only if sandbox copy is absent; default is always
PI_BWRAP_IMPORT_EXTENSIONS=0            # do not expose global Pi extensions/packages from host agent dir
PI_BWRAP_EXTENSIONS_SYNC=missing        # copy settings.json only if sandbox copy is absent; default is always
PI_BWRAP_IMPORT_GIT_CONFIG=0            # do not import host ~/.gitconfig and XDG git config
PI_BWRAP_GIT_CONFIG_SYNC=missing        # copy git config only if sandbox copy is absent; default is always
PI_BWRAP_HOST_GITCONFIG=/path           # host global git config; default: ~/.gitconfig
PI_BWRAP_HOST_XDG_GIT_CONFIG=/path      # host XDG git config; default: $XDG_CONFIG_HOME/git/config or ~/.config/git/config
PI_BWRAP_COORDINATION_DIR=/path/to/coordination # bind external coordination clone at /coordination
PI_BWRAP_DEFAULT_TOOLS="read,bash,..."  # override pi-start/pi-bwrap default tools
PI_BWRAP_NET=0                          # disable network sharing
PI_BWRAP_PASS_ENV="HTTP_PROXY,NO_PROXY" # pass extra env vars by name
```

## Use in another project

`pi-env` can be used directly from another project, or wired into that project's own flake.

If the target project does not need additional Nix dependencies, you do not need to create or edit its `flake.nix`. From the target project directory, enter the `pi-env` shell directly:

```bash
cd /path/to/other-project
nix develop /home/location/pi-env
pi-start
```

Or run Pi in one command:

```bash
cd /path/to/other-project
nix develop /home/location/pi-env -c pi-start
```

The current working directory remains the target project. `pi-start` / `pi-bwrap` detects the project root from `$PWD` / Git and mounts that project at `/workspace`.

Wire `pi-env` into the target project's own flake when you want project-specific Nix dependencies, a committed/shared devshell, shell hooks, or a pinned `pi-env` input in the project's `flake.lock`.

- **Project has no flake yet:** use the full example below as a starting `flake.nix`.
- **Project already has its own flake:** do not replace it. Add `pi-env` to the existing `inputs`, add `pi-env` to the `outputs = { ... }:` argument list, then either wrap the existing devshell with `mkPiShell` or add the `pi-start` / `pi-bwrap` packages to it.

### New project flake / replace the project's devshell

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";

    # Replace this path with wherever this pi-env repository lives.
    pi-env.url = "git+file:///home/samo/CODEFAB/PIWS/pi-env";
    pi-env.inputs.nixpkgs.follows = "nixpkgs";
    pi-env.inputs.flake-utils.follows = "flake-utils";
  };

  outputs = { nixpkgs, flake-utils, pi-env, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in {
        devShells.default = pi-env.lib.mkPiShell {
          inherit pkgs;

          extraPackages = with pkgs; [
            # project-specific tools, for example:
            # nodejs
            # python3
          ];

          shellHook = ''
            echo "project shell loaded"
          '';
        };
      });
}
```

Then run from the other project:

```bash
nix develop
pi-start
```

For custom Pi arguments:

```bash
pi-bwrap -- --model anthropic/claude-sonnet-4-5 "Inspect this repo"
```

`pi-start` starts Pi in the Bubblewrap sandbox with the default tool allowlist and `--continue`. `pi-bwrap -- ...` passes the arguments after `--` directly to Pi.

### Project already has its own flake

If the project already has a `flake.nix`, keep its existing structure and only add the `pi-env` pieces.

First add the input:

```nix
inputs = {
  # existing inputs...

  pi-env.url = "git+file:///home/samo/CODEFAB/PIWS/pi-env";
  pi-env.inputs.nixpkgs.follows = "nixpkgs";
  pi-env.inputs.flake-utils.follows = "flake-utils";
};
```

Then include `pi-env` in the outputs arguments:

```nix
outputs = { self, nixpkgs, flake-utils, pi-env, ... }:
  # existing outputs...
```

#### Add to an existing devshell

If the project already has a devshell, add the wrappers to its package list:

```nix
packages = [
  pi-env.packages.${system}.pi-start
  pi-env.packages.${system}.pi-bwrap
];
```

Or, if your shell uses `nativeBuildInputs` / `buildInputs`, add the same packages there.

### Common per-project overrides

These can be set before running `pi-start` / `pi-bwrap`, or exported in the project's shell hook:

```bash
PI_BWRAP_PROJECT_ROOT=/path/to/repo pi-start  # mount this repo at /workspace
PI_BWRAP_USE_GIT_ROOT=0 pi-start              # use $PWD instead of git root
PI_BWRAP_EPHEMERAL_HOME=1 pi-start            # throw away sandbox home after the run
PI_BWRAP_IMPORT_AUTH=0 pi-start               # do not copy host Pi auth into sandbox state
PI_BWRAP_NET=0 pi-start                       # disable network access
```

Inside the sandbox, the selected project is mounted read-write at `/workspace`, while the sandbox home and Pi config live separately from the host home.

## Common vs project-specific rules and skills

`pi-env` keeps the runtime separate from user-specific agent behavior. It does not ship common rules or skills itself. Instead, `pi-bwrap` imports common Pi resources from an external directory into the sandbox Pi agent directory.

By default, the common directory is the user's normal Pi agent directory:

```bash
$PI_CODING_AGENT_DIR   # if set
~/.pi/agent            # otherwise
```

From that directory, `pi-bwrap` imports only common agent resources:

```text
AGENTS.md
CLAUDE.md
SYSTEM.md
APPEND_SYSTEM.md
skills/
prompts/
```

It does not import the whole host home, and auth/session handling remains controlled separately by `PI_BWRAP_IMPORT_AUTH` and `PI_BWRAP_IMPORT_SESSIONS`. Global extension/package exposure is controlled separately by `PI_BWRAP_IMPORT_EXTENSIONS`.

To keep common rules/skills in a separate repo or directory, point `PI_BWRAP_COMMON_AGENT_DIR` at it:

```bash
PI_BWRAP_COMMON_AGENT_DIR=~/CODE/my-pi-common pi-start
```

Expected layout:

```text
my-pi-common/
  AGENTS.md
  skills/
    common-skill/
      SKILL.md
  prompts/
    review.md
```

Disable common resource import entirely with:

```bash
PI_BWRAP_IMPORT_COMMON=0 pi-start
```

Project-specific rules, skills, and extensions should live in the project repository so they are versioned with the project:

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

Pi loads the common/global resources from `/home/pi/.pi/agent` and also discovers project resources from `/workspace`, so this gives a clean split:

- common rules/skills and global extensions/packages: user-owned, reusable across projects;
- project-specific rules/skills/extensions/packages: committed with the project;
- `pi-env`: neutral runtime and isolation layer only.

## Git config

`pi-bwrap` imports the user's host Git config into the isolated sandbox home by default:

```text
~/.gitconfig
$XDG_CONFIG_HOME/git/config, or ~/.config/git/config
```

Inside the sandbox these become:

```text
/home/pi/.gitconfig
/home/pi/.config/git/config
```

This lets Git commands run by Pi use the user's normal identity, aliases, default branch settings, diff settings, and other non-secret Git preferences while still avoiding a host `$HOME` mount.

Disable this with:

```bash
PI_BWRAP_IMPORT_GIT_CONFIG=0 pi-start
```

Use a different config source with:

```bash
PI_BWRAP_HOST_GITCONFIG=/path/to/gitconfig pi-start
PI_BWRAP_HOST_XDG_GIT_CONFIG=/path/to/xdg-git-config pi-start
```

By default the sandbox copy is refreshed on each run. Preserve an existing sandbox copy with:

```bash
PI_BWRAP_GIT_CONFIG_SYNC=missing pi-start
```

Git credentials, SSH keys, signing keys, credential helpers' backing stores, and other files referenced from Git config are not imported automatically.

## Upgrading pi-coding-agent

`pi-env` does not pin or install `pi-coding-agent` through Nix. The wrappers expect a `pi` executable to already exist on the host `PATH`, then `pi-bwrap` bind-mounts the host/global Pi installation read-only into the sandbox.

When a new Pi version is available, upgrade Pi on the host, outside `pi-start` / `pi-bwrap`:

```bash
npm install -g --ignore-scripts @earendil-works/pi-coding-agent@latest
pi --version
```

Then continue using `pi-env` normally:

```bash
nix develop
pi-start
```

Do not run Pi self-updates from inside the Bubblewrap sandbox: `/usr/local/bin` and the global Pi npm package are mounted read-only there.

If your current global Pi supports self-update and your user has permission to update the global install, this can also be run on the host:

```bash
pi update --self
```

That updates Pi itself. It is separate from updating a project's `pi-env` flake input. If another project consumes this repository as a flake input and `pi-env` changed, update that input in the consuming project with:

```bash
nix flake update pi-env
```

## Notes

- Pi's built-in tool list is `read,bash,edit,write,grep,find,ls`. `pi-start` allowlists those by default. If you need extension/custom tools too, include them in `PI_BWRAP_DEFAULT_TOOLS` or call `pi-bwrap` with your own `--tools` list.
- Global Pi extensions and globally installed Pi packages are exposed read-only from the host agent directory by default. Disable this with `PI_BWRAP_IMPORT_EXTENSIONS=0`. Project-local extensions/packages under `.pi/` are available because the project is mounted at `/workspace`.
- Use `git` through the `bash` tool unless you install/register a separate Git tool extension.
- Bubblewrap limits filesystem/environment exposure. It does not provide domain-level network allowlists. For tighter network policy, disable network with `PI_BWRAP_NET=0`, use an external firewall/proxy, or add Pi's sandbox extension as an additional layer for `bash` commands.
