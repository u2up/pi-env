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
- copies host Pi model auth files (`auth.json`, `models.json`) from `~/.pi/agent` into sandbox state by default;
- does **not** mount host `$HOME`, `~/.ssh`, cloud credential directories, or Docker sockets;
- clears the environment, then passes only terminal basics and selected LLM provider variables;
- shares the host network by default so Pi can reach model providers.

Important: with the `bash`/`read` tools enabled, auth copied into the sandbox can be read by commands/tools inside the sandbox. This is still safer than mounting your whole home, but use least-privilege API keys or a provider proxy when possible.

## Useful environment knobs

```bash
PI_BWRAP_PROJECT_ROOT=/path/to/repo     # default: git root, else $PWD
PI_BWRAP_USE_GIT_ROOT=0                 # bind only $PWD
PI_BWRAP_STATE_DIR=/path/to/state       # persistent sandbox home/config
PI_BWRAP_EPHEMERAL_HOME=1               # temporary home/config for this run
PI_BWRAP_IMPORT_AUTH=0                  # do not import host ~/.pi/agent auth files
PI_BWRAP_AUTH_SYNC=missing              # copy auth only if sandbox copy is absent; default is always
PI_BWRAP_HOST_AGENT_DIR=/path/to/agent  # default: $PI_CODING_AGENT_DIR or ~/.pi/agent
PI_BWRAP_DEFAULT_TOOLS="read,bash,..."  # override pi-start/pi-bwrap default tools
PI_BWRAP_NET=0                          # disable network sharing
PI_BWRAP_PASS_ENV="HTTP_PROXY,NO_PROXY" # pass extra env vars by name
```

## Use from another flake

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
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
            # project-specific tools
          ];
          shellHook = ''
            echo "project shell loaded"
          '';
        };
      });
}
```

Alternative if you already have a shell:

```nix
packages = [
  pi-env.packages.${system}.pi-start
  pi-env.packages.${system}.pi-bwrap
];
```

## Notes

- Pi's built-in tool list is `read,bash,edit,write,grep,find,ls`. `pi-start` allowlists those by default. If you need extension/custom tools too, include them in `PI_BWRAP_DEFAULT_TOOLS` or call `pi-bwrap` with your own `--tools` list.
- Use `git` through the `bash` tool unless you install/register a separate Git tool extension.
- Bubblewrap limits filesystem/environment exposure. It does not provide domain-level network allowlists. For tighter network policy, disable network with `PI_BWRAP_NET=0`, use an external firewall/proxy, or add Pi's sandbox extension as an additional layer for `bash` commands.
