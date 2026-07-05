# pi-env

`pi-env` runs Pi Coding Agent safely against one selected project, with optional
guaranteed-reproducible tooling and optional managed agentic coordination.

It is built around three layers:

1. **Sandboxed project isolation with Bubblewrap**

   Every run is confined to a mandatory Bubblewrap sandbox where the selected
   project is mounted read-write at `/workspace`. The agent does not receive
   wholesale access to your home directory, credentials, shell configuration,
   Docker socket, or unrelated projects.

   **Problem addressed:** reducing the blast radius of agentic coding tools
   that can inspect files, run commands, and edit code.

2. **Optional guaranteed-reproducible runtime with Nix**

   When selected, the Nix runtime provides pinned tools and dependencies so
   teams can run the agent with the same command-line environment across
   machines. Direct host-runtime mode remains available for convenience, but is
   intentionally unpinned.

   **Problem addressed:** avoiding “works on my machine” drift in agent runs,
   checks, and development tooling.

3. **Optional coordination repository for managed agentic development**

   `pi-env` includes Git-backed coordination helpers and role workflows for
   teams that want structured multi-agent or multi-role development. This acts
   as a reference implementation of the
   [coordination repository pattern](https://github.com/u2up/coordination-repository-pattern):
   requirements, decisions, ownership, handoffs, and validation can be tracked
   outside the working project.

   **Problem addressed:** preventing ad-hoc agent work from becoming hard to
   audit, reproduce, assign, or hand off.

In short:

```text
Without pi-env:
  Pi -> host environment
     -> home directory, SSH keys, cloud credentials, Docker socket,
        shell config, unrelated projects

With pi-env:
  Pi -> Bubblewrap sandbox
     -> selected repo at /workspace, isolated HOME,
        selected auth/config only
```

Most users start with one of two workflows:

1. **Direct use**: run this checkout's `pi-env` launcher from any project.
2. **Flake integration**: add `pi-env` as an input to a project's own flake so
   the team shares the same pinned runtime.

## 60-second example

Assuming Linux, Git, and a configured host `pi` command are already available,
try pi-env on an existing public repository:

```bash
git clone https://github.com/spog/evm.git
cd evm

git clone https://github.com/u2up/pi-env.git ~/src/pi-env
~/src/pi-env/pi-env \
  "Summarize this repository and suggest safe first checks."
```

That direct checkout command starts in the default **host runtime** mode: Pi
runs inside the Bubblewrap sandbox, but runtime tools are unpinned host tools.
You can make the selection explicit or opt in to the reproducible Nix runtime:

```bash
~/src/pi-env/pi-env --runtime host "Inspect this repo with host tools."
~/src/pi-env/pi-env --runtime nix "Inspect this repo with pinned Nix tools."
```

You can also use the Nix flake app directly when you want the pinned runtime
without cloning first:

```bash
nix run github:u2up/pi-env -- \
  "Summarize this repository and suggest safe first checks."
```

All of these run Pi against the cloned repository with that repository mounted
read-write at `/workspace` inside the Bubblewrap sandbox. They are intended for
inspection. If you ask Pi to build or test a project, supply the project's
build tools with the host runtime policy or declare them in a devshell for the
Nix runtime as described below.

### Optional: enable local coordination for the example

For tracked role-based agent work, enter the pi-env shell:

```bash
cd evm
nix develop github:u2up/pi-env
```

Then bootstrap a local coordination repository for the checkout and run Pi:

```bash
bootstrap-coordination \
  --project-root "$PWD" \
  --project evm \
  --project-key EVM
agent-coord-status
pi-env "Inspect this repository and review its state."
```

This creates local coordination state under `.pi-env/` for agent issue, TODO,
and synchronization tracking. `.pi-env/` is operational state and should
normally stay untracked.

Implementation repositories may commit a small root-level attachment hint named
`.pi-env-coordination.yaml` so helpers can find their shared coordination domain:

```yaml
version: 1
coordination_domain: my-product
coordination_remote: git@example.com:org/my-product-coordination.git
repo_id: backend-api
```

The file is read from the implementation repository root, not from inside the
coordination checkout. Explicit command options and environment variables still
win: repo id resolution is `--repo-id`, `PI_COORD_REPO_ID`,
`.pi-env-coordination.yaml`, then Git remote-name inference; coordination remote
resolution is explicit `--remote`, `PI_COORD_REMOTE_URL`, then
`.pi-env-coordination.yaml`. No legacy implementation attachment filename is
read as a fallback. The coordination repository registry remains authoritative
for canonical and active repo ids when `repositories.yaml` or the
`repos/<repo_id>/REPO.md` registry is present.

Domain-wide generated files that are committed to implementation repositories
are declared in the coordination clone's top-level `PROJECT.md`, not in the
per-repo attachment hint:

```yaml
domain_generated_files:
  - repo_id: backend-api
    paths:
      - REQUIREMENTS.md
      - REQUIREMENTS_COVERAGE.md
```

The `repo_id` must be a canonical active repository id from the coordination
registry, and `paths` are relative to that implementation repository root.
Agents should regenerate and commit those paths only in the named
implementation repository; if the field is absent, empty, or ambiguous, add an
explicit coordination-domain decision before updating generated outputs.

`agent-coord-lint` validates repo manifests and all repo-scoped issue structure
under `repos/<repo_id>/issues/<status>`. Item-matched issue tests are expected
only for the current implementation repo resolved from `--repo-id`,
`PI_COORD_REPO_ID`, `.pi-env-coordination.yaml`, or Git remote registry data.
`--all-repos` keeps structural validation across every registered repo but does
not require tests from unavailable implementation checkouts unless `--repo-id`
selects that repo explicitly. Fresh `agent-coord-init` scaffolds the initial
implementation namespace at
`repos/<repo_id>/issues/{open,blocked,done,closed}` and writes the sole registry
record at `repos/<repo_id>/REPO.md`; no root `REPOS.md` index is generated.
Existing `REPOS.md` files from older coordination repositories are ignored by
tooling and may be deleted manually. Existing root-layout domains can move
tracked root issue files with `agent-coord-repo migrate-root-issues <repo_id>`;
the command creates or validates the target repo manifest, uses `git mv` for
tracked files, and refuses target overwrites or duplicate issue ids. Root
`issues/` paths are migration-compatible by default with warnings; set
`PI_COORD_LINT_ROOT_ISSUES=fail` to reject them.

### Simple coordination workflow

A typical human-and-agent workflow with a coordination repository is:

1. **Bootstrap or clone coordination state** for the project. For local-only
   experiments this is `.pi-env/coordination`; for team use, point it at a
   shared Git remote.
2. **Capture project knowledge there**: requirements, decisions, notes, issues,
   TODOs, ownership, and validation expectations that should survive beyond one
   chat session.
3. **Pick or create a work item** before starting implementation. Pull the
   coordination repo, inspect open items, and claim or assign one when work
   begins.
4. **Run Pi with the project and coordination state mounted**. The agent can use
   the coordination repository as shared memory and should record meaningful
   events, decisions, handoffs, and validation results there.
5. **Review two diffs separately**: project-source changes in the project repo,
   and coordination changes in the coordination repo. Commit/push each to its
   own repository when accepted.
6. **Repeat from coordination state**, not from chat history. The next human or
   agent pulls the coordination repo and sees the current requirements,
   decisions, item status, and handoff notes.

In short, the project repository remains the source of product code, while the
coordination repository is the source of shared process memory and work state.
For a serial automation loop that applies this pattern across developer,
reviewer, and tester roles, see
[Serial role automation](#serial-role-automation).

## 1. Host prerequisites

Install or configure these on the host before using this repository.

### Required host dependencies

- **Linux** with unprivileged user namespaces/Bubblewrap support.
- **`pi-coding-agent`** installed on the host and available as `pi` on `PATH`.
  `pi-env` does not pin or install Pi itself.
- **Model credentials** for Pi, either in Pi's normal auth files under
  `~/.pi/agent` or as provider environment variables such as
  `ANTHROPIC_API_KEY` / `OPENAI_API_KEY`.
- **Git** or another way to fetch this repository.

### Optional Nix dependency

Install **Nix** with flakes enabled for Nix runtime workflows (`--runtime nix`,
`nix run`, `nix develop`, profile installs, or project flake integration). You
can either enable the `nix-command` and `flakes` experimental features globally
or pass them when running Nix. Direct checkout use defaults to the host runtime
and does not require Nix.

Quick checks:

```bash
pi --version
# Needed only for Nix runtime workflows:
nix --version
```

If Pi is not installed yet, install it using the upstream package. A common npm
installation is:

```bash
npm install -g --ignore-scripts @earendil-works/pi-coding-agent@latest
pi --version
```

Node/npm are needed on the host for this Pi installation or upgrade step and
for host-runtime launches that use the npm-installed Pi launcher. In host
runtime mode, `node` for an npm-installed Pi launcher must resolve under
`/usr/local/bin`, `/usr/bin`, or `/bin`; `PI_BWRAP_HOST_EXTRA_PATH` does not
admit that launcher interpreter. The pi-env Nix shell provides Node and the
other runtime tools when you select the Nix runtime.

### Provided by pi-env

When you enter the devshell, select `--runtime nix`, run `nix run`, or consume
pi-env as a flake, Nix supplies the pinned runtime tools used by the wrappers:

```text
bash bubblewrap cacert coreutils fd findutils gawk git gnugrep gnused
gnutar gzip jq nodejs ripgrep which
```

The development shell also includes review and patch utilities for contributor
workflows:

```text
diff diff3 patch
```

Verify the devshell tools with:

```bash
nix develop --command bash -lc 'command -v diff diff3 patch'
```

You normally do not need to install these separately for pi-env itself.

## 2. Install pi-env

Clone this repository for direct host-runtime use:

```bash
git clone https://github.com/u2up/pi-env.git ~/src/pi-env
```

Enter the devshell when you want Nix-pinned pi-env commands and helper tools:

```bash
cd ~/src/pi-env
nix develop
```

If flakes are not enabled globally, use:

```bash
nix --extra-experimental-features 'nix-command flakes' develop
```

Verify the commands are available:

```bash
pi-env --help
pi-bwrap --help
```

### Non-Nix host-runtime installation

For a conventional host-runtime install, use the non-Nix installer from a
release/archive checkout:

```bash
./scripts/install-non-nix --prefix "$HOME/.local" --check-deps
export PATH="$HOME/.local/bin:$PATH"
pi-env --runtime host --help
```

The installer does not invoke Nix and does not install a pinned runtime
toolchain. It copies pi-env commands to `$PREFIX/bin`, support files to
`$PREFIX/share/pi-env`, and writes wrappers that resolve coordination support,
coordination templates, and the role-manager package from that installed
prefix. Host tools such as Bash, Bubblewrap, Git, jq, Node, the `pi` launcher,
and standard POSIX text/file utilities must already be available. Use the Nix
flake, devshell, or profile packages when you need the reproducible pinned
runtime.

Release artifacts can contain only the pi-env payload directories (`scripts/`,
`role-manager/`, and `pi-skill-templates/`); end users do not need a Git clone
for installation. Prefer tagged releases or release artifact URLs for stable
installs, for example `--ref v0.1.0` or `--artifact-url URL`.

For latest/development testing, the installer can bootstrap itself from a
GitHub branch archive when no local payload is present:

```bash
curl -fsSL https://raw.githubusercontent.com/u2up/pi-env/main/scripts/install-non-nix \
  | bash -s -- --ref main --prefix "$HOME/.local" --check-deps
```

`--ref main` is mutable and non-reproducible; treat it as a development/latest
channel, not the recommended stable install path. Use `--repo OWNER/REPO` for
forks, or `--artifact-url URL` to install from a specific archive URL.

Re-run the same command to upgrade or repair an install. To
remove installed files later, use the manifest-backed uninstall command:

```bash
pi-env-uninstall
# or, without PATH setup:
"$HOME/.local/bin/pi-env-uninstall"
```

Inside `nix develop` the prompt is prefixed with `(nix-dev)`. The shell exports
`PI_ENV_ROLE_MANAGER_PACKAGE` to the Nix-built role-manager package path and
prints a short reminder unless `PI_ENV_QUIET` is set.

### Optional profile installation

For the smallest profile that can launch Pi in the sandbox, install the core
runtime package. It puts `pi-env`, `pi-start`, `pi-bwrap`, and the runtime tools
on `PATH` without the Git-backed coordination helper commands:

```bash
nix profile install ~/src/pi-env#pi-core
```

If you also use coordination helpers, either install them separately or keep the
compatibility runtime bundle:

```bash
nix profile install ~/src/pi-env#pi-env-coordination
# or, for the compatibility bundle used by older docs/automation:
nix profile install ~/src/pi-env#pi-runtime
```

`pi-runtime` continues to include the core runtime plus coordination helpers.
None of these packages install `pi-coding-agent`; the host `pi` command must
already exist.

## 3. Use pi-env directly from any project

Use direct mode for local, ad hoc, or internal runs where selecting a pi-env
checkout is enough and the target project does not need to pin pi-env in its
own `flake.lock`. Direct checkout startup defaults to **host runtime** mode:
`pi-env` still enters the Bubblewrap sandbox, but command-line tools are the
unpinned host tools admitted by pi-env's conservative mount policy.

From the target project directory, run this checkout's launcher:

```bash
cd /path/to/project
~/src/pi-env/pi-env
~/src/pi-env/pi-env "Inspect this repo"
~/src/pi-env/pi-env --raw -- --model anthropic/claude-sonnet-4-5 "Inspect this repo"
```

If you installed `#pi-core` or `#pi-runtime` into a profile, you can run the
shorter command:

```bash
cd /path/to/project
pi-env
pi-env "Inspect this repo"
```

The checkout launcher defaults to host runtime mode. It preserves the current
project as the detected project root; inside the sandbox that project is
mounted read-write at `/workspace`. The pi-env checkout is only the source of
launcher code and runtime policy.

Select a runtime explicitly with `--runtime` or `PI_ENV_RUNTIME`:

```bash
~/src/pi-env/pi-env --runtime host "Inspect this repo"
~/src/pi-env/pi-env --runtime nix "Inspect this repo with pinned tools"
PI_ENV_RUNTIME=nix ~/src/pi-env/pi-env
```

Use `--runtime host` for direct startup with unpinned host tools. Use
`--runtime nix`, `nix run`, `nix develop`, profile packages, or project flake
integration when you need the reproducible/pinned Nix runtime. `--runtime auto`
keeps compatibility with environments that already provide pi-env commands and
falls back to the Nix runtime when needed.

Use `--raw --` when you want to pass arguments directly to Pi through
`pi-bwrap` instead of using the `pi-start` defaults:

```bash
pi-env --raw -- --model anthropic/claude-sonnet-4-5 "Inspect this repo"
```

Select another pi-env flake reference with either form:

```bash
PI_ENV_FLAKE=github:u2up/pi-env ~/src/pi-env/pi-env
~/src/pi-env/pi-env --flake github:u2up/pi-env
```

## 4. Use pi-env through a project flake

Use project-integrated mode when a repository should:

- pin pi-env for the team in the repository's `flake.lock`;
- share the same pi-env revision across machines and CI jobs;
- combine pi-env with project-specific Nix dependencies; or
- expose one committed `nix develop` entrypoint for both project tools and Pi.

After integration, the usual workflow is:

```bash
cd /path/to/project
nix develop
pi-env
pi-env "Inspect this repo"
pi-env --raw -- --model anthropic/claude-sonnet-4-5 "Inspect this repo"
```

Both direct and flake-integrated modes keep the selected project root as the
single project mounted at `/workspace`. Direct use gets pi-env from a checkout
or profile; flake integration lets the project pin pi-env in its own
`flake.lock` and combine it with project-specific tools. Neither mode turns
pi-env into a separate workspace-env repository or multi-project manager.

### New project flake

For a project that does not yet have a flake, use this as a starting
`flake.nix`. Replace the `pi-env.url` with either a local checkout or a Git
reference that your team can access.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";

    # Local checkout example. A shared repo could use github:u2up/pi-env.
    pi-env.url = "git+file:///home/me/src/pi-env";
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

          # Smallest project shell: omit agent-coord* helper commands unless
          # this project uses Git-backed coordination.
          includeCoordinationHelpers = false;

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

Then run:

```bash
nix develop
pi-env
```

`mkPiShell` defaults `includeCoordinationHelpers` to `true` so existing
consumers keep `bootstrap-coordination` and `agent-coord*` commands on `PATH`.
Set it to `false` for core-only project shells.

### Existing project flake

If the project already has a `flake.nix`, keep its existing structure and add
only the pi-env pieces.

Add the input:

```nix
inputs = {
  # existing inputs...

  pi-env.url = "git+file:///home/me/src/pi-env";
  # or: pi-env.url = "github:u2up/pi-env";
  pi-env.inputs.nixpkgs.follows = "nixpkgs";
  pi-env.inputs.flake-utils.follows = "flake-utils";
};
```

Include `pi-env` in the outputs arguments:

```nix
outputs = { self, nixpkgs, flake-utils, pi-env, ... }:
  # existing outputs...
```

Then choose one integration style.

#### Wrap the devshell with `mkPiShell`

Use this when you want pi-env to own the shell composition and add your project
tools through `extraPackages`:

```nix
devShells.default = pi-env.lib.mkPiShell {
  inherit pkgs;

  # Keep this false for a core-only runtime shell. Omit the option or set it
  # to true if the project uses bootstrap-coordination or agent-coord* helpers.
  includeCoordinationHelpers = false;

  extraPackages = with pkgs; [
    # existing project tools
  ];

  shellHook = ''
    # existing shell hook
  '';
};
```

### Project-specific build and test tools

pi-env keeps its default runtime intentionally small. Host runtime mode uses
unpinned host tools from the conservative sandbox `PATH`; Nix runtime mode uses
the pinned tools provided by this flake. Neither mode bundles every compiler or
build system a target repository might need. Add host-runtime tools explicitly
with `PI_BWRAP_HOST_EXTRA_PATH`, or declare reproducible project tools in the
consuming project's Nix flake. Bubblewrap remains the isolation boundary in both
modes.

For builds or tests, declare tools in the consuming project's flake:

```nix
devShells.default = pi-env.lib.mkPiShell {
  inherit pkgs;
  includeCoordinationHelpers = false;

  extraPackages = with pkgs; [
    gnumake
    gcc
    pkg-config
  ];
};
```

`mkPiShell` turns the `extraPackages` `bin` outputs into `PI_BWRAP_EXTRA_PATH`.
In Nix runtime mode, `pi-bwrap` validates those entries before starting the
sandbox, accepts only canonical `/nix/store` directories, and then appends them
after the core pi-env runtime path. Since `/nix/store` is already mounted
read-only, no host `/bin`, host `/usr/bin`, project-writable directory, or scan
of the whole store is needed. pi-env does not infer tools from a repository
automatically.

Advanced Nix-runtime users may set `PI_BWRAP_EXTRA_PATH` directly to a
colon-separated list of command directories, but entries must be absolute
existing directories that canonicalize under `/nix/store`; unsafe entries such
as `/tmp/bin`, `$HOME/bin`, `./bin`, `/usr/bin`, or `/bin` are rejected before
Pi starts. Host-runtime users should use `PI_BWRAP_HOST_EXTRA_PATH` instead;
those entries are canonicalized, must exist, are mounted read-only, and are
rejected under host `$HOME`.

#### Add pi-env to an existing devshell

Use this when the project already has a custom `mkShell` and you only want to
add the pi-env commands:

```nix
packages = existingPackages ++ [
  pi-env.packages.${system}.pi-core
];
```

If your shell uses `nativeBuildInputs` or `buildInputs`, add the same package
there instead. Use `pi-env.packages.${system}.pi-env-coordination` when you want
only the optional coordination helpers, or `pi-env.packages.${system}.pi-runtime`
when older automation expects the compatibility bundle containing both the core
runtime and coordination helpers.

Update a consuming project's pinned input with:

```bash
nix flake update pi-env
```

## 5. Command reference

### `pi-env`

Start Pi with pi-env defaults:

```bash
pi-env
```

Direct checkout `pi-env` defaults to host runtime mode. In all runtime modes,
`pi-env` delegates to `pi-start`, which runs the sandbox with the default tool
allowlist, `--continue`, and the default role-manager package when available:

```bash
pi-bwrap --tools read,bash,edit,write,grep,find,ls --continue -e "$PI_ENV_ROLE_MANAGER_PACKAGE"
```

Select the runtime with `--runtime host|nix|auto` or
`PI_ENV_RUNTIME=host|nix|auto`; the command-line option wins. Host runtime is
unpinned and uses admitted host tools. Nix runtime is reproducible and pinned
by the selected pi-env flake, entering `nix develop` when needed.

For custom Pi arguments, use raw mode:

```bash
pi-env --raw -- --model anthropic/claude-sonnet-4-5 "Inspect this repo"
pi-env --runtime nix --raw -- --model anthropic/claude-sonnet-4-5 "Inspect this repo"
```

### `pi-start`

`pi-start` is the default startup wrapper. It chooses the default tool list from
`PI_BWRAP_DEFAULT_TOOLS` when set, otherwise uses Pi's built-in tools:

```text
read,bash,edit,write,grep,find,ls
```

By default, `pi-start` loads the packaged role-manager extension when the
package path exists. The role manager is inactive until you select a role,
restore one from session state, or request one through supported environment
variables. Set `PI_ENV_ROLE_MANAGER_AUTO=0` to omit the automatic per-run
extension argument, especially if you prefer an installed-package workflow.

### `pi-bwrap`

`pi-bwrap` runs `pi-coding-agent` inside the Bubblewrap sandbox. Use it directly
when you want full control over the Pi arguments or when running Pi subcommands:

```bash
pi-bwrap -- --help
pi-bwrap -- config
```

### Running `pi config`

Pi's `config` subcommand enables or disables extensions, skills, prompt
templates, and themes.

To edit the **sandboxed pi-env config**, run it through Bubblewrap:

```bash
pi-bwrap -- config
# or
pi-bwrap config
```

Inside the sandbox, Pi uses `/home/pi/.pi/agent/settings.json`, backed by
pi-env's per-project state directory. Project-local config remains the mounted
repo's `.pi/settings.json` under `/workspace`.

By default, pi-env copies the host `settings.json` into sandbox state on each
run when global extensions/packages are imported. If you want sandbox edits made
by `pi-bwrap -- config` to persist instead of being refreshed from the host
copy, use:

```bash
PI_BWRAP_EXTENSIONS_SYNC=missing pi-bwrap -- config
```

To edit your **real host/global Pi config**, run `pi config` directly after
entering the Nix devshell:

```bash
nix develop
pi config
```

This uses the Nix-provided runtime/tools on `PATH`, but does **not** enter the
Bubblewrap sandbox. It modifies the host Pi agent config, normally
`~/.pi/agent/settings.json` unless `PI_CODING_AGENT_DIR` points elsewhere.

## 6. Runtime and sandbox behavior

A pi-env invocation operates on one selected project root. The launcher detects
or receives that root, and the Bubblewrap layer mounts it read-write at the
fixed in-sandbox path `/workspace`. Complex layouts such as monorepos,
submodules, worktrees, or integration checkouts remain project-owned policy;
pi-env only chooses which root to expose for this run.

`pi-bwrap`:

- mounts the detected project root read-write at `/workspace`;
- mounts `/nix/store` read-only so declared devshell tools can be exposed
  through validated extra command paths;
- constructs the sandbox `PATH` from allowlisted host command directories
  (`/usr/local/bin`, `/usr/bin`, and `/bin`) instead of inheriting the caller's
  full host `PATH`;
- mounts `/usr/local/bin` and the global Pi npm package read-only when present,
  so a global npm-installed `pi` works;
- uses isolated `$HOME=/home/pi`;
- stores sandbox Pi state outside the project by default under
  `$XDG_STATE_HOME/pi-env/<project-hash>` or
  `$HOME/.local/state/pi-env/<project-hash>`;
- imports common Pi rules/skills/prompts/roles from the host Pi agent directory
  by default (`$PI_CODING_AGENT_DIR`, else `~/.pi/agent`), limited to
  `AGENTS.md`, `CLAUDE.md`, `SYSTEM.md`, `APPEND_SYSTEM.md`, `skills/`,
  `prompts/`, and `roles/`;
- exposes global Pi extensions and installed package directories from the host
  Pi agent directory by default (`extensions/`, `npm/`, `git/`) and copies
  `settings.json`, while project-local `.pi/extensions` and `.pi/settings.json`
  are available through `/workspace`;
- copies host Git config into the sandbox by default (`~/.gitconfig` and
  `$XDG_CONFIG_HOME/git/config` / `~/.config/git/config`), but not Git
  credentials or SSH keys;
- copies host Pi model auth files (`auth.json`, `models.json`) from
  `~/.pi/agent` into sandbox state by default;
- bind-mounts only the host Pi session directory for the current working
  directory into the sandbox by default (disabled for ephemeral homes), so
  `/resume` and `--continue` can access sessions for the directory/project
  without exposing all sessions;
- passes `PI_COORD_ROOT`, `PI_COORD_REMOTE_URL`, `PI_COORD_PROJECT`,
  `PI_COORD_AGENT_ID`, `PI_COORD_PROJECT_KEY`, `PI_COORD_ROLE`, and
  coordination directory context, mapping project-local coordination paths to
  `/workspace/...`, binding explicit external `PI_COORD_ROOT` paths at
  `/agent-remotes`, and explicitly mounting an external coordination clone
  with `PI_BWRAP_COORDINATION_DIR`;
- accepts additional host-runtime command directories only through
  `PI_BWRAP_HOST_EXTRA_PATH`; entries must be absolute, existing directories,
  are canonicalized, are mounted read-only, and are rejected under host `$HOME`;
- does **not** mount host `$HOME`, `~/.ssh`, cloud credential directories, or
  Docker sockets;
- clears the environment, then passes only terminal basics and selected LLM
  provider variables;
- shares the host network by default so Pi can reach model providers.

In host runtime mode, pi-env also adds conservative read-only support mounts
for system runtime files: `/lib`, `/lib64`, `/usr/lib`, `/usr/lib64`, `/bin`,
`/usr/bin`, and certificate-related `/etc` paths when they exist. These support
mounts let admitted host binaries run inside Bubblewrap; they are not a general
host filesystem, `/usr/share`, locale, alternatives, or home-directory mount.

If your `pi` command or language-manager shims live under host `$HOME` (for
example `~/.local/bin`, `~/.nvm`, `~/.asdf`, or a per-user npm prefix), host
runtime rejects them by default because host `$HOME` is not mounted. Prefer a
system/global install under `/usr/local/bin`, `/usr/bin`, or `/bin`, move a
custom `pi` launcher or other needed command directory outside `$HOME` and opt
it in with `PI_BWRAP_HOST_EXTRA_PATH`, or use `--runtime nix` for pinned tools.
Custom host tool directories admitted with `PI_BWRAP_HOST_EXTRA_PATH` are
mounted read-only and only after validation.

When an admitted host `pi` launcher uses `#!/usr/bin/env node`, `node` itself
must resolve under `/usr/local/bin`, `/usr/bin`, or `/bin`; the launcher check
does not admit `node` from `PI_BWRAP_HOST_EXTRA_PATH`. Use a system/global Node
install or `--runtime nix` when Node only exists in another custom directory.

Important: with the `bash`/`read` tools enabled, auth copied into the sandbox
and project sessions bind-mounted into the sandbox can be read by commands or
tools inside the sandbox. This is still safer than mounting your whole home, but
use least-privilege API keys or a provider proxy when possible.

## 7. Configuration reference

Common environment knobs:

```bash
PI_BWRAP_PROJECT_ROOT=/path/to/repo     # default: git root, else $PWD
PI_BWRAP_USE_GIT_ROOT=0                 # bind only $PWD
PI_BWRAP_STATE_DIR=/path/to/state       # persistent sandbox home/config; .pi-env/state is opt-in
PI_BWRAP_EPHEMERAL_HOME=1               # temporary home/config for this run
PI_BWRAP_IMPORT_AUTH=0                  # do not import host ~/.pi/agent auth files
PI_BWRAP_AUTH_SYNC=missing              # copy auth only if sandbox copy is absent; default is always
PI_BWRAP_IMPORT_SESSIONS=0              # do not bind host sessions for the current working directory
PI_BWRAP_HOST_AGENT_DIR=/path/to/agent  # default: $PI_CODING_AGENT_DIR or ~/.pi/agent
PI_BWRAP_COMMON_AGENT_DIR=/path/to/dir  # common rules/skills/roles dir; default: host Pi agent dir
PI_BWRAP_IMPORT_COMMON=0                # do not import common AGENTS/SYSTEM files, skills, prompts, or roles
PI_BWRAP_COMMON_SYNC=missing            # copy common files only if sandbox copy is absent; default is always
PI_BWRAP_IMPORT_EXTENSIONS=0            # do not expose global Pi extensions/packages from host agent dir
PI_BWRAP_EXTENSIONS_SYNC=missing        # copy settings.json only if sandbox copy is absent; default is always
PI_BWRAP_IMPORT_GIT_CONFIG=0            # do not import host ~/.gitconfig and XDG git config
PI_BWRAP_GIT_CONFIG_SYNC=missing        # copy git config only if sandbox copy is absent; default is always
PI_BWRAP_HOST_GITCONFIG=/path           # host global git config; default: ~/.gitconfig
PI_BWRAP_HOST_XDG_GIT_CONFIG=/path      # host XDG git config; default: $XDG_CONFIG_HOME/git/config or ~/.config/git/config
PI_BWRAP_COORDINATION_DIR=/path/to/coordination # bind external coordination clone at /coordination
PI_COORD_ROOT=.pi-env/agent-remotes      # explicit bare remotes; project paths map to /workspace, external paths to /agent-remotes
PI_COORD_REMOTE_URL=git@example:repo.git # optional Git-server coordination remote URL; no local remotes mount required
PI_COORD_PROJECT=pi-env                 # coordination project/domain name
PI_COORD_PROJECT_KEY=PIENV              # optional generated item ID prefix
PI_COORD_ROLE=architect                 # active coordination role for helper commits/events
PI_BWRAP_DEFAULT_TOOLS="read,bash,..."  # override pi-start/pi-bwrap default tools
PI_BWRAP_EXTRA_PATH=/nix/store/.../bin   # Nix runtime: validated /nix/store command dirs
PI_BWRAP_HOST_EXTRA_PATH=/opt/tools/bin  # host runtime: validated read-only host command dirs
PI_BWRAP_NET=0                          # disable network sharing
PI_BWRAP_PASS_ENV="HTTP_PROXY,NO_PROXY" # pass extra env vars by name
```

Common per-project overrides can be set before running `pi-start` / `pi-bwrap`,
or exported in the project's shell hook:

```bash
PI_BWRAP_PROJECT_ROOT=/path/to/repo pi-start  # mount this repo at /workspace
PI_BWRAP_USE_GIT_ROOT=0 pi-start              # use $PWD instead of git root
PI_BWRAP_EPHEMERAL_HOME=1 pi-start            # throw away sandbox home after the run
PI_BWRAP_STATE_DIR=$PWD/.pi-env/state pi-start # opt in to project-local sandbox state
PI_BWRAP_IMPORT_AUTH=0 pi-start               # do not copy host Pi auth into sandbox state
PI_BWRAP_NET=0 pi-start                       # disable network access
```

Inside the sandbox, the selected project root is mounted read-write at
`/workspace`, while the sandbox home and Pi config live separately from the
host home. The default state location intentionally stays outside `.pi-env/`
because it can contain copied auth, settings, sessions, and caches; use
`PI_BWRAP_STATE_DIR=$PWD/.pi-env/state` only when you explicitly want that
project-local operational state.

## 8. Common vs project-specific Pi resources

`pi-env` keeps the runtime separate from user-specific agent behavior. It does
not ship common rules, skills, prompts, or custom roles itself. Instead,
`pi-bwrap` imports common Pi resources from an external directory into the
sandbox Pi agent directory.

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
roles/
```

It does not import the whole host home, and auth/session handling remains
controlled separately by `PI_BWRAP_IMPORT_AUTH` and
`PI_BWRAP_IMPORT_SESSIONS`. Global extension/package exposure is controlled
separately by `PI_BWRAP_IMPORT_EXTENSIONS`.

To keep common rules, skills, prompts, or roles in a separate repo or directory,
point `PI_BWRAP_COMMON_AGENT_DIR` at it:

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
  roles/
    domain-architect.md
```

Disable common resource import entirely with:

```bash
PI_BWRAP_IMPORT_COMMON=0 pi-start
```

Project-specific rules, skills, roles, and extensions should live in the
project repository so they are versioned with the project:

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
    roles/
      release-builder.md
    settings.json
```

Pi loads the common/global resources from `/home/pi/.pi/agent` and also
discovers project resources from `/workspace`, giving a clean split:

- common rules/skills/roles and global extensions/packages: user-owned,
  reusable across projects;
- project-specific rules/skills/roles/extensions/packages: committed with the
  project;
- `pi-env`: neutral runtime and isolation layer only.

## 9. Git config and credentials

`pi-bwrap` imports the user's host Git config into the isolated sandbox home by
default:

```text
~/.gitconfig
$XDG_CONFIG_HOME/git/config, or ~/.config/git/config
```

Inside the sandbox these become:

```text
/home/pi/.gitconfig
/home/pi/.config/git/config
```

This lets Git commands run by Pi use the user's normal identity, aliases,
default branch settings, diff settings, and other non-secret Git preferences
while still avoiding a host `$HOME` mount.

Disable this with:

```bash
PI_BWRAP_IMPORT_GIT_CONFIG=0 pi-start
```

Use a different config source with:

```bash
PI_BWRAP_HOST_GITCONFIG=/path/to/gitconfig pi-start
PI_BWRAP_HOST_XDG_GIT_CONFIG=/path/to/xdg-git-config pi-start
```

By default the sandbox copy is refreshed on each run. Preserve an existing
sandbox copy with:

```bash
PI_BWRAP_GIT_CONFIG_SYNC=missing pi-start
```

Git credentials, SSH keys, signing keys, credential helpers' backing stores,
and other files referenced from Git config are not imported automatically.

## 10. Role-manager package

`pi-env` ships a Pi role-manager package for agent roles such as architect,
developer, builder, tester, and reviewer. The package contains a Pi extension
plus Markdown role definitions under `role-manager/`. `pi-start` loads it by
default with Pi's per-run extension/package flag when the package path exists;
this does not modify global or project `settings.json`.

Inside `nix develop`, the shell exports `PI_ENV_ROLE_MANAGER_PACKAGE` to the
Nix-built role-manager package path. To opt out of default loading for one run:

```bash
PI_ENV_ROLE_MANAGER_AUTO=0 pi-start
```

You can still install it into project-local Pi settings if you want Pi to load
it normally without the per-run flag. In that workflow, use the opt-out variable
if you want to avoid loading the same package through both mechanisms:

```bash
pi-bwrap install -l "$PI_ENV_ROLE_MANAGER_PACKAGE"
PI_ENV_ROLE_MANAGER_AUTO=0 pi-start
```

The role-manager package can also be built directly:

```bash
nix build /path/to/pi-env#pi-role-manager
pi-bwrap install -l "$(readlink -f result)"
```

### Role files and precedence

Base roles are bundled with the package:

| Role | Purpose | Default tools |
|------|---------|---------------|
| `architect` | Design, trade-offs, decisions, and plans. | `read`, `grep`, `find`, `ls` |
| `developer` | Focused source changes. | `read`, `grep`, `find`, `ls`, `edit`, `write`, `bash` |
| `builder` | Build, packaging, integration, and release prep. | `read`, `grep`, `find`, `ls`, `bash`, `edit` |
| `tester` | Reproduction, tests, verification, and coverage gaps. | `read`, `grep`, `find`, `ls`, `bash`, `edit`, `write` |
| `reviewer` | Diff, risk, security, and maintainability review. | `read`, `grep`, `find`, `ls`, `bash` |

Role definitions are Markdown files with frontmatter. Project roles live in
`.pi/roles/*.md` beside other project Pi resources. Common roles can live in the
host/common agent resource directory as `roles/*.md`; `pi-bwrap` imports that
`roles/` directory with common `skills/` and `prompts/` when common import is
enabled. A mounted coordination clone may also provide roles for that project
coordination domain.

Roles are merged by `name`; later sources override earlier ones:

1. bundled base package roles;
2. global/common agent roles imported into `/home/pi/.pi/agent/roles`;
3. common roles from `PI_BWRAP_COMMON_AGENT_DIR/roles` when directly visible;
4. coordination-domain roles from `$PI_COORD_DIR/roles`;
5. project roles from `.pi/roles`.

See `role-manager/ROLE_FILE_SCHEMA.md` for the full schema. See
`examples/project-role-override/.pi/roles/domain-architect.md` for a minimal
project-specific role that adds a role without changing the base package.

### Role commands and tools

The extension registers these slash commands:

```text
/role                       select a role interactively
/role <name>                switch the current session to a role
/role-clear                 clear the role and restore prior settings
/role-cycle <name> <goal>   run one bounded role cycle in this session
/role-new <name> <goal>     start a fresh session and run one role cycle
```

When a role is active, only that role's instructions are injected into the
system prompt for each turn. Role frontmatter may request a thinking level,
model/provider, and tool allowlist. Unknown requested tools are warned and
ignored. The default `pi-start` allowlist includes every built-in tool used by
the bundled roles. `/role-cycle` includes the role's one-cycle checklist in the
kickoff prompt, enables the package's `role_cycle_done` tool for that cycle,
and instructs the model to call it as the final action so Pi can terminate the
cycle without an extra follow-up turn. If that tool is unavailable, the prompt
asks for a normal prose final report rather than JSON. `/role-new` requests
that Pi preserve the existing UI screen while switching to the fresh session.

When the role-manager extension has an active role, it sets `PI_COORD_ROLE` for
Pi subprocesses to the role's `coordCommitter` value, or to the role name when
`coordCommitter` is omitted. Coordination helper commands use that value only
for coordination item event actors and per-command coordination Git identity;
project repository commits keep the normal imported Git identity unless the
user explicitly changes it.

See `designs/role-manager.md` for the architecture.

## 11. Agent coordination helpers

`pi-env` includes opt-in helpers for one Git-backed coordination domain per
selected project. A domain can cover multiple implementation repositories, but
each pi-env invocation mounts and works in one implementation repository at
`/workspace`. They are plain Git/text-file tooling and are separate from
`pi-start`. Install `#pi-env-coordination`, use the compatibility `#pi-runtime`
bundle, or leave `includeCoordinationHelpers` enabled in `mkPiShell` when you
want these commands. Projects usually use the project-local
`.pi-env/coordination` clone as their attachment to the shared domain.

Guided setup with inferred, project-specific defaults:

```bash
bootstrap-coordination
# inspect another project root from this devshell
bootstrap-coordination --project-root /path/to/project --print-only
# or only print the suggested PI_COORD_* environment and init command
bootstrap-coordination --print-only
```

Manual minimal setup with a local bare remote:

```bash
export PI_COORD_ROOT=/workspace/.pi-env/agent-remotes
export PI_COORD_PROJECT=pi-env
export PI_COORD_PROJECT_KEY=PIENV
export PI_COORD_DIR=/workspace/.pi-env/coordination
export PI_COORD_AGENT_ID=agent-a

agent-coord-init
```

To use a remote hosted by a Git server, pass it explicitly or set
`PI_COORD_REMOTE_URL`:

```bash
agent-coord-init --project pi-env --remote git@example.com:org/pi-env-coordination.git
agent-coord-clone --remote git@example.com:org/pi-env-coordination.git
bootstrap-coordination --remote git@example.com:org/pi-env-coordination.git --print-only
```

`bootstrap-coordination` is a thin wrapper around `agent-coord-init`: it prints
the inferred root, clone dir, remote, agent ID, project, and project key, then
initializes with those explicit values. Remote selection uses this precedence:
explicit `--remote`, then `PI_COORD_REMOTE_URL`, then the local bare remote
under `PI_COORD_ROOT`. If the local coordination clone already exists but the
planned local bare remote is missing or empty, it recreates that remote from
the clone's committed Git history and repairs `origin` when it is absent or
points to a missing local path.

Without a configured remote URL, this creates a bare remote at:

```text
$PI_COORD_ROOT/$PI_COORD_PROJECT-coordination.git
```

If `PI_COORD_ROOT` is unset, helpers default to the project-local
`.pi-env/agent-remotes` directory. Inside the pi-env sandbox, that is normally
`/workspace/.pi-env/agent-remotes`, available through the standard project
bind mount rather than a separate remotes mount.

If `PI_COORD_ROOT` is set to a project-local path, `pi-bwrap` rewrites it to the
matching `/workspace/...` path. If it is set to an existing local path outside
the project, `pi-bwrap` bind-mounts that directory read-write at
`/agent-remotes` and rewrites `PI_COORD_ROOT=/agent-remotes` inside the
sandbox. Without explicit overrides, the sandbox launcher only recognizes
project-local `.pi-env/coordination` and `.pi-env/agent-remotes`; root-level
`coordination/` and `agent-remotes/` directories are not selected or mounted
automatically.

When `--remote` or `PI_COORD_REMOTE_URL` is set, helpers use that URL directly
and do not create a local bare remote. The remote repository must already exist
and be accessible to Git. Provide SSH keys, tokens, or credential helpers
through narrowly-scoped sandbox/project configuration as needed; pi-env does
not import the host `~/.ssh` directory or all host Git credentials wholesale.

It then clones/scaffolds `$PI_COORD_DIR` with `AGENTS.md`, domain
`PROJECT.md` metadata, a repo namespace at
`repos/<repo_id>/issues/{open,blocked,done,closed}`, shared `requirements/`,
`todos/`, `decisions/`, and `notes/` directories, protocol docs, item-format
docs, and `.pi/skills/agent-coordination/SKILL.md`. The repo manifest at
`repos/<repo_id>/REPO.md` is the authoritative registry record for that
implementation repo. When `PI_COORD_DIR` is unset, fresh projects use
`.pi-env/coordination`.

Top-level `PROJECT.md` can also declare which implementation repo commits
shared generated outputs for the domain, with paths relative to the named
implementation repo root, for example:

```yaml
domain_generated_files:
  - repo_id: pi-env
    paths:
      - REQUIREMENTS.md
      - REQUIREMENTS_COVERAGE.md
```

Clone the same coordination domain elsewhere with:

```bash
agent-coord-clone
```

Create a type-coded timestamp-ID issue in the current repo namespace with:

```bash
agent-coord-new --repo-id pi-env --type issue --category bug \
  "Document pi config behavior"
agent-coord-push -m "Add PIENV documentation item"
```

The resulting issue path is
`repos/pi-env/issues/open/<ITEM-ID>.yaml`. Functional requirements, decisions,
and notes remain common domain records at the coordination root.

Issue items can use optional categories such as `bug`, `feature-request`,
`task`, `question`, or `improvement`; use `--type issue
--category task` for task-category work. Use `agent-coord-list --category
bug issues open` to filter, or `agent-coord-list --group-by-category issues`
to sort grouped issue output.

When top-level `PROJECT.md` exists, omit `--project` for domain-common items;
`PI_COORD_PROJECT` can remain set for coordination-domain selection. For
issues, pass `--repo-id` or set `PI_COORD_REPO_ID`; helpers may also resolve it
from the implementation repo's `.pi-env-coordination.yaml` or registry remote
metadata.

Generated item IDs use a project item key prefix, a type code, a UTC timestamp,
and a three-digit collision/order suffix that starts at `001`:

```text
<PROJECTKEY>-<TYPECODE>-<YYYYMMDD-HHMMSS>-<NNN>
```

For example, an issue can be created as
`PIENV-ISS-20260607-204155-001.yaml`; a functional requirement can be created as
`PIENV-FRQ-20260607-204155-001.yaml`. Use
`agent-coord-init --project-key PIENV` to set the initial project's stored key
during scaffolding. Project-root keys are stored in top-level `PROJECT.md` as `item_key`. Agents
should use stored keys instead of inventing new ones.

Key resolution for `agent-coord-new` is:

1. `--project-key KEY`;
2. stored root project `item_key`;
3. `PI_COORD_PROJECT_KEY` when no stored key exists;
4. derived `--project` / `PI_COORD_PROJECT` for project items;
5. derived coordination clone directory name when no project name is set.

Derived keys are uppercased and all delimiters, whitespace, pipes, slashes,
backslashes, and other non-alphanumeric characters are removed. For example,
`pi-env_test` becomes `PIENVTEST`. `--id ID` overrides the whole item ID.
Built-in type codes are `ISS` for `issue`, `FRQ` for `functional-requirement`,
`QRQ` for `quality-requirement`, `CRQ` for `constraint-requirement`, `TODO` for
`todo`, `DEC` for `decision`, and `NOTE` for `note`.

Lifecycle helpers are also available:

```text
bootstrap-coordination
                      infer defaults and initialize via agent-coord-init
agent-coord-status    show sync status and open/blocked/done items
agent-coord-list      list issues, todos, notes, decisions, requirements, or
                      classes by status
agent-coord-cat       print one resolved item's YAML or repo-relative path
agent-coord-pull      run git pull --rebase --autostash
agent-coord-push      commit and push coordination changes
agent-coord-new       create a templated item
agent-coord-claim     claim an item, commit, and push
agent-coord-done      mark developer work done, commit, and push
agent-coord-review    mark review pass/fail, commit, and push
agent-coord-verify    mark verification pass/fail, commit, and push
agent-coord-close     final-close reviewed+verified done items
agent-coord-lint      lint item IDs, status, and item-matched tests
agent-coord-upgrade-rules --preview
                      preview/apply bundled rule template updates
pi-serial-roles       serially run one developer/reviewer/tester Pi job at a time
```

Items are YAML files with chronological `events` and linked Markdown messages.
Issue state group names are developer-centric: `open` means developer work is
needed, `blocked` means developer work cannot proceed, `done` means the
developer believes implementation is complete, and `closed` means final
accepted after review and verification.

Issue items live under `repos/<repo_id>/issues/<status>/`, and each issue
belongs to exactly one implementation repo by that path. Functional, quality,
and constraint requirements use the root-level `requirements/` directory while
preserving FRQ, QRQ, and CRQ item-ID type codes. TODO items use `todos/` and
single top-level `body: |-` records without issue history. The `agent-coord-list requirements` command reports functional,
quality, and constraint requirement items; use `functional`, `quality`, or
`constraint` for class-specific listings. Done issue listings append
review and verification sub-status after the title. Imported requirement items
record traceability in a top-level `source_refs` list using stable strings such
as old requirement IDs, `REQUIREMENTS.md#heading`, and `USE_CASES.md#section`;
lint checks imported FRQ/QRQ/CRQ items for non-empty source references plus the
standard `testable` metadata.

Decision, note, and other non-issue item types live under their semantic type
directories shared by the coordination domain. Use `agent-coord-list notes` or
`agent-coord-list todos` to list those root-level groups, optionally filtered
by their YAML `status` values. The
accepted TODO type spellings are `todo` and `todos`; `tdo` is
not a supported alias. Stored implementation refs are structured objects with
`repo`,
`branch`, and full `commit` fields. For cross-repo implementation work, create
one issue per affected repo and link them with stable item IDs in `related:` or
messages rather than path-only references; repo renames preserve aliases and
should not require reference rewrites. `agent-coord-done --implementation-ref
pi-env:main@<full-hash>` accepts the compact CLI form and writes the structured
YAML form. `agent-coord-close` finalizes only items that are done, reviewed, and
verified unless forced.

Commands that create item events or coordination commits accept `--role ROLE`
and read `PI_COORD_ROLE`. Item events store actor ID/role metadata explicitly;
helper commits use per-command Git identity overrides such as `pi/architect
<pi+architect@coordination.local>`. These overrides are scoped to the helper's
coordination-repository `git commit`; normal project repository commits keep the
user's imported Git identity unless the user explicitly opts in to another
identity.

Existing coordination repositories are not silently overwritten. Rule upgrades
are explicit and diffable:

```bash
agent-coord-upgrade-rules --preview
agent-coord-upgrade-rules
```

The helpers do not make `pi-start` create, claim, mark done, review, verify,
close, commit, or push coordination state automatically. If a coordination clone
is under the mounted project, `pi-bwrap` only exposes it as normal project files
and sets `PI_COORD_DIR` to the sandbox path. For a coordination clone outside
the project, opt in explicitly:

```bash
PI_BWRAP_COORDINATION_DIR=/path/to/coordination pi-start
```

That clone is mounted read-write at `/coordination` and `PI_COORD_DIR` is set
to `/coordination` inside the sandbox.

When the role-manager extension has an active role, it sets `PI_COORD_ROLE` for
Pi subprocesses to the role's `coordCommitter` value, or to the role name when
`coordCommitter` is omitted. Bash-invoked `agent-coord-*` commands inherit the
active role without changing project Git identity.

### Serial role automation

`pi-serial-roles` is the first, deliberately serial automation mode for
coordination-backed role work. Use it when you want one long-lived shell to
process developer, reviewer, and tester issue jobs over one project clone and
one coordination clone, without concurrent source edits or competing Git
operations in that clone. It is useful for initial small automation and prompt
shake-out before investing in parallel workers.

Serial mode prerequisites:

- run from a clean Git project root, or pass `--project-root DIR`;
- provide a writable coordination checkout. Projects default to
  `.pi-env/coordination`; use `PI_COORD_DIR` or `--coord-dir DIR` for an
  explicit override path;
- run from the pi-env devshell/profile so `pi-env`, `agent-coord-*` helpers,
  and `PI_ENV_ROLE_MANAGER_PACKAGE` are available, or pass explicit `--pi-env`
  and `--role-manager` paths;
- configure Pi model credentials on the host the same way you do for normal
  `pi-env` runs, for example host Pi auth files or provider environment
  variables; and
- allow the orchestrator to mount the selected coordination clone into each raw
  sandbox job. It passes `PI_BWRAP_COORDINATION_DIR`, `PI_COORD_DIR`,
  `PI_COORD_AGENT_ID`, and role context for the job, and exposes packaged
  lifecycle helpers through `PI_BWRAP_EXTRA_PATH` when they live in the Nix
  store.

Start the loop from the project root:

```bash
cd /path/to/project
pi-serial-roles --sleep 30
```

Stop it with `Ctrl-C`, or use bounded modes when you want it to exit on its own:

```bash
pi-serial-roles --once
pi-serial-roles --max-jobs 3
pi-serial-roles --max-idle-polls 1 --sleep 5
pi-serial-roles --dry-run
pi-serial-roles --ui interactive --once
pi-serial-roles --ui json --once
pi-serial-roles --ui none --once
```

Each poll holds `.pi-env/locks/pi-serial-roles.lock` and creates
`.pi-env/locks` as needed. It requires a clean project working tree. A dirty
coordination checkout before selection is treated as busy: the loop skips
pulling, selecting, and claiming, then sleeps or exits according to the bounded
idle options. Clean coordination is still required before a pull, before a Pi
job, and after each job completes. Serial automation logs and future local
diagnostics default under
`.pi-env/logs`. Work priority is:

1. tester: done issues with `reviewed: true` and `verified: false`;
2. reviewer: done issues with `reviewed: false`;
3. developer: open issues that are unowned or already owned by the agent.

Developer items are claimed with `agent-coord-claim` before Pi is invoked.
Reviewer and tester prompts name only the selected done item and instruct the
role to use `agent-coord-review` or `agent-coord-verify`. If no issue is
eligible, the orchestrator sleeps and polls again without invoking Pi.

Every issue job starts a fresh raw Pi session with `pi-env --raw --` and does
not pass `--continue`. The default `--ui interactive` mode launches the normal
Pi TUI with the selected item prompt, active role environment, coordination
mount, and tool allowlist, but without `--mode json`, `--print`, or `-p`. It
also passes the role-manager extension flag that requests graceful TUI shutdown
after `role_cycle_done`, so the orchestrator can continue after the bounded
role cycle finishes.

Use `--ui json` for structured automation. It adds `--mode json` for JSONL
output, which is useful for unattended loops, CI-like supervision, or when you
want to parse the final `role_cycle_done` details from the corresponding
`tool_execution_end` event alongside other structured tool, usage, compaction,
and error events.

Use `--ui none` for non-interactive prompt/response output. It adds `--print`,
prints the generated role report, and exits without a TUI or JSON event stream.

The previous hold-open `interactive` behavior has intentionally been removed
and is not available under another `--ui` value or compatibility alias. If you
need to inspect a completed session, use normal logs/output or run Pi directly
instead of keeping `pi-serial-roles` blocked after each item. Coordination state
and Git history are the memory shared between jobs; a fresh conversation avoids
stale context from a previous issue influencing item selection, review,
verification, or lifecycle helper use.

The command fails closed around role execution. Dirty project trees stop the
loop before polling. A dirty coordination tree during idle pre-selection is
treated as a busy checkout: the loop does not pull, inspect, select, claim,
reset, discard, or stash, and it retries after the normal sleep. Dirty project
or coordination trees after a role job remain fatal. A failed coordination
pull/rebase stops with the helper's error so you can resolve the conflict and
rerun. A non-zero Pi job also stops the loop instead of moving on to another
issue; inspect the terminal output and clean up any project or coordination
changes before restarting.

Serial mode does not require tmux, per-role clones, worktrees, or
reviewer/tester leases, and the local lock prevents two serial loops from
sharing one clone.
Those pieces are future parallel-worker concerns. Parallel mode should use
separate clones/worktrees and additional lease rules before multiple roles edit
or mutate coordination concurrently.

See `designs/serial-role-automation.md` for the full design.

See `designs/agent-coordination.md` for the full design.

## 12. Upgrading

`pi-env` does not pin or install `pi-coding-agent` through Nix. The wrappers
expect a `pi` executable to already exist on the host `PATH`, then `pi-bwrap`
bind-mounts the host/global Pi installation read-only into the sandbox.

When a new Pi version is available, upgrade Pi on the host, outside `pi-start` /
`pi-bwrap`:

```bash
npm install -g --ignore-scripts @earendil-works/pi-coding-agent@latest
pi --version
```

Then continue using `pi-env` normally:

```bash
nix develop
pi-start
```

Do not run Pi self-updates from inside the Bubblewrap sandbox: `/usr/local/bin`
and the global Pi npm package are mounted read-only there.

If your current global Pi supports self-update and your user has permission to
update the global install, this can also be run on the host:

```bash
pi update --self
```

That updates Pi itself. It is separate from updating a project's `pi-env` flake
input. If another project consumes this repository as a flake input and pi-env
changed, update that input in the consuming project with:

```bash
nix flake update pi-env
```

## 13. Development and tests

Run the whole project test suite with:

```bash
tests/run.sh
```

Coordination helper smoke tests:

```bash
tests/agent-coord-blackbox.sh
tests/agent-coord-concurrency.sh
tests/agent-coord-lint.sh
tests/coordination-items-closed-or-done.sh
```

Role-manager package, schema/template, loader, and command smoke tests:

```bash
tests/role-manager-package.sh
tests/role-manager-schema.sh
tests/role-manager-loader.sh
tests/role-manager-commands.sh
```

Item-matched tests live in the owning implementation repository under
`tests/items/` and match the item ID by filename stem. Issue items belong to a
single repo namespace under `repos/{repo_id}/issues/{status}`, but project item
tests mirror only the root item type; they do not mirror repo namespaces or
issue lifecycle status directories:

```text
.pi-env/coordination/repos/pi-env/issues/closed/PIENV-ISS-20260607-204155-001.yaml
tests/items/issues/PIENV-ISS-20260607-204155-001.sh

.pi-env/coordination/requirements/PIENV-FRQ-20260607-204155-001.yaml
tests/items/requirements/PIENV-FRQ-20260607-204155-001.sh
```

## 14. Notes

- Pi's built-in tool list is `read,bash,edit,write,grep,find,ls`.
  `pi-start` allowlists those by default. If you need extension/custom tools
  too, include them in `PI_BWRAP_DEFAULT_TOOLS` or call `pi-bwrap` with your own
  `--tools` list.
- Global Pi extensions and globally installed Pi packages are exposed read-only
  from the host agent directory by default. Disable this with
  `PI_BWRAP_IMPORT_EXTENSIONS=0`. Project-local extensions/packages under
  `.pi/` are available because the project is mounted at `/workspace`.
- Use `git` through the `bash` tool unless you install/register a separate Git
  tool extension.
- Bubblewrap limits filesystem/environment exposure. It does not provide
  domain-level network allowlists. For tighter network policy, disable network
  with `PI_BWRAP_NET=0`, use an external firewall/proxy, or add Pi's sandbox
  extension as an additional layer for `bash` commands.
