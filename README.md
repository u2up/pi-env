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

`pi-startup` is kept as a backwards-compatible alias.

`pi-start` runs:

```bash
pi-bwrap --tools read,bash,edit,write,grep,find,ls --continue
```

For custom Pi arguments:

```bash
pi-bwrap -- --model anthropic/claude-sonnet-4-5 "Inspect this repo"
```

## Bubblewrap safety defaults

`pi-bwrap`:

- mounts the detected project root read-write at `/workspace`;
- mounts `/nix/store` read-only so devshell tools work;
- mounts `/usr/local/bin` and the global Pi npm package read-only when present, so a global npm-installed `pi` works;
- uses isolated `$HOME=/home/pi`;
- stores sandbox Pi state outside the project by default under `$XDG_STATE_HOME/pi-env/<project-hash>`;
- imports common Pi rules/skills/prompts from the host Pi agent directory by default (`$PI_CODING_AGENT_DIR`, else `~/.pi/agent`), limited to `AGENTS.md`, `CLAUDE.md`, `SYSTEM.md`, `APPEND_SYSTEM.md`, `skills/`, and `prompts/`;
- copies host Pi model auth files (`auth.json`, `models.json`) from `~/.pi/agent` into sandbox state by default;
- bind-mounts only the host Pi session directory for the current working directory into the sandbox by default (disabled for ephemeral homes), so `/resume` and `--continue` can access sessions for the directory/project without exposing all sessions;
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
PI_BWRAP_DEFAULT_TOOLS="read,bash,..."  # override pi-start/pi-bwrap default tools
PI_BWRAP_NET=0                          # disable network sharing
PI_BWRAP_PASS_ENV="HTTP_PROXY,NO_PROXY" # pass extra env vars by name
```

## Use in another project

`pi-env` is intended to be reused from other project flakes. How you wire it in depends on whether the target project already has a `flake.nix`.

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

It does not import the whole host home, and auth/session handling remains controlled separately by `PI_BWRAP_IMPORT_AUTH` and `PI_BWRAP_IMPORT_SESSIONS`.

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

Project-specific rules and skills should live in the project repository so they are versioned with the project:

```text
project/
  AGENTS.md
  .pi/
    skills/
      project-skill/
        SKILL.md
    prompts/
    settings.json
```

Pi loads the common resources from `/home/pi/.pi/agent` and also discovers project resources from `/workspace`, so this gives a clean split:

- common rules/skills: user-owned, reusable across projects;
- project-specific rules/skills: committed with the project;
- `pi-env`: neutral runtime and isolation layer only.

## Notes

- Pi's built-in tool list is `read,bash,edit,write,grep,find,ls`. `pi-start` allowlists those by default. If you need extension/custom tools too, include them in `PI_BWRAP_DEFAULT_TOOLS` or call `pi-bwrap` with your own `--tools` list.
- Use `git` through the `bash` tool unless you install/register a separate Git tool extension.
- Bubblewrap limits filesystem/environment exposure. It does not provide domain-level network allowlists. For tighter network policy, disable network with `PI_BWRAP_NET=0`, use an external firewall/proxy, or add Pi's sandbox extension as an additional layer for `bash` commands.
