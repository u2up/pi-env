{
  description = "Reusable Pi coding-agent runtime with bubblewrap isolation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    let
      defaultTools = "read,bash,edit,write,grep,find,ls";

      mkRuntime = pkgs:
        with pkgs; [
          bash
          bubblewrap
          cacert
          coreutils
          fd
          findutils
          gawk
          git
          gnugrep
          gnused
          gnutar
          gzip
          jq
          nodejs
          ripgrep
          which
        ];

      mkDevShellTools = pkgs:
        with pkgs; [
          diffutils
          patch
        ];

      mkPiBwrap = pkgs:
        let
          runtimePackages = mkRuntime pkgs;
          runtimePath = pkgs.lib.makeBinPath runtimePackages;
        in
        pkgs.writeShellScriptBin "pi-bwrap" ''
          set -euo pipefail

          export PATH="${runtimePath}:''${PATH:-}"
          DEFAULT_PI_TOOLS="${defaultTools}"
          if [ -n "''${PI_BWRAP_DEFAULT_TOOLS:-}" ]; then
            DEFAULT_PI_TOOLS="$PI_BWRAP_DEFAULT_TOOLS"
          fi

          usage() {
            cat <<'USAGE'
          pi-bwrap - run pi-coding-agent inside a rootless bubblewrap sandbox

          Usage:
            pi-bwrap [pi args...]
            pi-bwrap -- [pi args...]

          Defaults when no pi args are given:
            pi --tools read,bash,edit,write,grep,find,ls --continue

          Security model:
            - mounts the detected project root read-write at /workspace
            - mounts /nix/store read-only for devshell tools
            - mounts /usr/local/bin and the global pi npm package read-only when present
            - uses an isolated HOME at /home/pi
            - imports common Pi rules/skills/prompts/roles from the host Pi agent dir by default
            - exposes global Pi extensions/packages from the host Pi agent dir by default
            - copies host Git config into sandbox HOME by default, but not credentials or SSH keys
            - copies host pi auth.json/models.json into sandbox state by default
            - bind-mounts only the host pi sessions for the current working directory by default (disabled for ephemeral homes)
            - does not mount host $HOME, ~/.ssh, cloud credentials, or docker sockets
            - clears the environment, then passes terminal basics and selected LLM provider vars

          Environment knobs:
            PI_BWRAP_PROJECT_ROOT=/path   Project to mount; default: git root, else $PWD
            PI_BWRAP_USE_GIT_ROOT=0       Use $PWD instead of auto git-root detection
            PI_BWRAP_STATE_DIR=/path      Persistent sandbox home/config; default: XDG state per project
                                           Use $PWD/.pi-env/state only as explicit project-local opt-in
            PI_BWRAP_EPHEMERAL_HOME=1     Use a temporary sandbox home/config for this run
            PI_BWRAP_IMPORT_AUTH=0        Do not import host ~/.pi/agent auth files
            PI_BWRAP_AUTH_SYNC=missing    Copy auth only if sandbox copy is absent (default: always)
            PI_BWRAP_IMPORT_SESSIONS=0    Do not bind project sessions from host ~/.pi/agent (default: 1, or 0 with ephemeral home)
            PI_BWRAP_HOST_AGENT_DIR=/path Host pi agent dir (default: $PI_CODING_AGENT_DIR or ~/.pi/agent)
            PI_BWRAP_COMMON_AGENT_DIR=/path Common rules/skills/roles dir (default: host pi agent dir)
            PI_BWRAP_IMPORT_COMMON=0       Do not import common AGENTS/SYSTEM files, skills, prompts, or roles
            PI_BWRAP_COMMON_SYNC=missing   Copy common files only if sandbox copy is absent (default: always)
            PI_BWRAP_IMPORT_EXTENSIONS=0   Do not expose global Pi extensions/packages from host agent dir
            PI_BWRAP_EXTENSIONS_SYNC=missing Copy settings.json only if sandbox copy is absent (default: always)
            PI_BWRAP_IMPORT_GIT_CONFIG=0   Do not import host ~/.gitconfig and XDG git config
            PI_BWRAP_GIT_CONFIG_SYNC=missing Copy git config only if sandbox copy is absent (default: always)
            PI_BWRAP_HOST_GITCONFIG=/path  Host global git config (default: ~/.gitconfig)
            PI_BWRAP_HOST_XDG_GIT_CONFIG=/path Host XDG git config (default: $XDG_CONFIG_HOME/git/config or ~/.config/git/config)
            PI_BWRAP_DEFAULT_TOOLS="..."  Override default --tools list
            PI_BWRAP_EXTRA_PATH=/nix/store/.../bin[:...] Add validated Nix-store command dirs after pi-env runtime tools
            PI_BWRAP_NET=0                Disable network namespace sharing
            PI_BWRAP_COORDINATION_DIR=/path Bind external coordination clone at /coordination
            PI_COORD_ROOT=.pi-env/agent-remotes Bare remotes root; project paths stay under /workspace,
                                           external paths bind at /agent-remotes
            PI_COORD_REMOTE_URL=url       Coordination Git remote URL passed through without local mounts
            PI_COORD_ROLE=architect       Active coordination role passed to helpers
            PI_BWRAP_PASS_ENV="A B,C"     Extra environment variable names to pass through

          To pass pi's own -h/--help, use:
            pi-bwrap -- --help
          USAGE
          }

          if [ "''${1:-}" = "--help" ] || [ "''${1:-}" = "-h" ]; then
            usage
            exit 0
          fi

          if [ "''${1:-}" = "--" ]; then
            shift
          fi

          if ! command -v pi >/dev/null 2>&1; then
            echo "pi-bwrap: pi was not found on PATH before entering the sandbox." >&2
            echo "Install pi globally, or enter a shell that provides it, then retry." >&2
            exit 127
          fi

          project_root="''${PI_BWRAP_PROJECT_ROOT:-}"
          if [ -z "$project_root" ]; then
            if [ "''${PI_BWRAP_USE_GIT_ROOT:-1}" = "1" ] && command -v git >/dev/null 2>&1; then
              project_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
            fi
            if [ -z "$project_root" ]; then
              project_root="$PWD"
            fi
          fi
          project_root="$(realpath -m "$project_root")"
          if [ ! -d "$project_root" ]; then
            echo "pi-bwrap: project root does not exist: $project_root" >&2
            exit 2
          fi

          host_cwd="$(realpath -m "$PWD")"
          case "$host_cwd" in
            "$project_root")
              inside_cwd="/workspace"
              ;;
            "$project_root"/*)
              inside_cwd="/workspace''${host_cwd#"$project_root"}"
              ;;
            *)
              inside_cwd="/workspace"
              ;;
          esac

          if [ "''${PI_BWRAP_EPHEMERAL_HOME:-0}" = "1" ]; then
            state_base="$(mktemp -d "''${TMPDIR:-/tmp}/pi-bwrap.XXXXXX")"
            cleanup_tmp="$state_base"
            trap 'rm -rf "$cleanup_tmp"' EXIT
          else
            project_hash="$(printf '%s' "$project_root" | sha256sum | awk '{print $1}' | cut -c1-16)"
            state_parent="''${XDG_STATE_HOME:-''${HOME:-/tmp}/.local/state}"
            state_base="''${PI_BWRAP_STATE_DIR:-$state_parent/pi-env/$project_hash}"
            state_base="$(realpath -m "$state_base")"
          fi

          mkdir -p \
            "$state_base/home/.pi/agent" \
            "$state_base/home/.cache" \
            "$state_base/home/.config/git" \
            "$state_base/agent/sessions" \
            "$state_base/cache"
          chmod 700 "$state_base" "$state_base/home" "$state_base/home/.pi" "$state_base/home/.cache" "$state_base/home/.config" "$state_base/home/.config/git" "$state_base/agent" "$state_base/agent/sessions" "$state_base/cache" 2>/dev/null || true

          host_home="''${HOME:-}"

          host_agent_dir="''${PI_BWRAP_HOST_AGENT_DIR:-}"
          if [ -z "$host_agent_dir" ] && [ -n "''${PI_CODING_AGENT_DIR:-}" ]; then
            host_agent_dir="$PI_CODING_AGENT_DIR"
          fi
          if [ -z "$host_agent_dir" ] && [ -n "''${HOME:-}" ]; then
            host_agent_dir="$HOME/.pi/agent"
          fi
          if [ -n "$host_agent_dir" ]; then
            host_agent_dir="$(realpath -m "$host_agent_dir")"
          fi

          common_agent_dir="''${PI_BWRAP_COMMON_AGENT_DIR:-$host_agent_dir}"
          if [ -n "$common_agent_dir" ]; then
            common_agent_dir="$(realpath -m "$common_agent_dir")"
          fi

          should_sync_common() {
            local target="$1"
            [ "''${PI_BWRAP_COMMON_SYNC:-always}" = "always" ] || [ ! -e "$target" ]
          }

          if [ "''${PI_BWRAP_IMPORT_COMMON:-1}" = "1" ] && [ -n "$common_agent_dir" ] && [ -d "$common_agent_dir" ] && [ "$common_agent_dir" != "$state_base/agent" ]; then
            for common_file in AGENTS.md CLAUDE.md SYSTEM.md APPEND_SYSTEM.md; do
              if [ -f "$common_agent_dir/$common_file" ] && should_sync_common "$state_base/agent/$common_file"; then
                cp -p "$common_agent_dir/$common_file" "$state_base/agent/$common_file"
              fi
            done

            for common_dir_name in skills prompts roles; do
              if [ -d "$common_agent_dir/$common_dir_name" ] && should_sync_common "$state_base/agent/$common_dir_name"; then
                rm -rf "$state_base/agent/$common_dir_name"
                mkdir -p "$state_base/agent"
                cp -a "$common_agent_dir/$common_dir_name" "$state_base/agent/$common_dir_name"
              fi
            done
          fi

          should_sync_git_config() {
            local target="$1"
            [ "''${PI_BWRAP_GIT_CONFIG_SYNC:-always}" = "always" ] || [ ! -e "$target" ]
          }

          if [ "''${PI_BWRAP_IMPORT_GIT_CONFIG:-1}" = "1" ]; then
            host_gitconfig="''${PI_BWRAP_HOST_GITCONFIG:-}"
            if [ -z "$host_gitconfig" ] && [ -n "$host_home" ]; then
              host_gitconfig="$host_home/.gitconfig"
            fi
            if [ -n "$host_gitconfig" ]; then
              host_gitconfig="$(realpath -m "$host_gitconfig")"
              if [ -f "$host_gitconfig" ] && should_sync_git_config "$state_base/home/.gitconfig"; then
                cp -p "$host_gitconfig" "$state_base/home/.gitconfig"
                chmod 600 "$state_base/home/.gitconfig" 2>/dev/null || true
              fi
            fi

            host_xdg_git_config="''${PI_BWRAP_HOST_XDG_GIT_CONFIG:-}"
            if [ -z "$host_xdg_git_config" ] && [ -n "''${XDG_CONFIG_HOME:-}" ]; then
              host_xdg_git_config="''${XDG_CONFIG_HOME}/git/config"
            fi
            if [ -z "$host_xdg_git_config" ] && [ -n "$host_home" ]; then
              host_xdg_git_config="$host_home/.config/git/config"
            fi
            if [ -n "$host_xdg_git_config" ]; then
              host_xdg_git_config="$(realpath -m "$host_xdg_git_config")"
              if [ -f "$host_xdg_git_config" ] && should_sync_git_config "$state_base/home/.config/git/config"; then
                mkdir -p "$state_base/home/.config/git"
                cp -p "$host_xdg_git_config" "$state_base/home/.config/git/config"
                chmod 600 "$state_base/home/.config/git/config" 2>/dev/null || true
              fi
            fi
          fi

          if [ "''${PI_BWRAP_IMPORT_AUTH:-1}" = "1" ] && [ -n "$host_agent_dir" ] && [ -d "$host_agent_dir" ]; then
            for auth_file in auth.json models.json; do
              if [ -f "$host_agent_dir/$auth_file" ]; then
                if [ "''${PI_BWRAP_AUTH_SYNC:-always}" = "always" ] || [ ! -e "$state_base/agent/$auth_file" ]; then
                  cp -p "$host_agent_dir/$auth_file" "$state_base/agent/$auth_file"
                  chmod 600 "$state_base/agent/$auth_file" 2>/dev/null || true
                fi
              fi
            done
          fi

          extension_bind_args=()
          should_sync_extensions() {
            local target="$1"
            [ "''${PI_BWRAP_EXTENSIONS_SYNC:-always}" = "always" ] || [ ! -e "$target" ]
          }

          if [ "''${PI_BWRAP_IMPORT_EXTENSIONS:-1}" = "1" ] && [ -n "$host_agent_dir" ] && [ -d "$host_agent_dir" ] && [ "$host_agent_dir" != "$state_base/agent" ]; then
            if [ -f "$host_agent_dir/settings.json" ] && should_sync_extensions "$state_base/agent/settings.json"; then
              cp -p "$host_agent_dir/settings.json" "$state_base/agent/settings.json"
              chmod 600 "$state_base/agent/settings.json" 2>/dev/null || true
            fi

            for extension_dir_name in extensions npm git; do
              if [ -d "$host_agent_dir/$extension_dir_name" ]; then
                mkdir -p "$state_base/agent/$extension_dir_name"
                extension_bind_args+=(--ro-bind "$host_agent_dir/$extension_dir_name" "/home/pi/.pi/agent/$extension_dir_name")
              fi
            done
          fi

          session_bind_args=()
          session_dir_for_path() {
            local normalized stripped replaced
            normalized="$(realpath -m "$1")"
            stripped="''${normalized#/}"
            replaced="''${stripped//\//-}"
            replaced="''${replaced//:/-}"
            printf -- '--%s--' "$replaced"
          }

          import_sessions_default=1
          if [ "''${PI_BWRAP_EPHEMERAL_HOME:-0}" = "1" ]; then
            import_sessions_default=0
          fi

          if [ "''${PI_BWRAP_IMPORT_SESSIONS:-$import_sessions_default}" = "1" ] && [ -n "$host_agent_dir" ]; then
            host_session_dir_name="$(session_dir_for_path "$host_cwd")"
            sandbox_session_dir_name="$(session_dir_for_path "$inside_cwd")"
            host_project_session_dir="$host_agent_dir/sessions/$host_session_dir_name"
            state_workspace_session_dir="$state_base/agent/sessions/$sandbox_session_dir_name"

            if mkdir -p "$host_project_session_dir" "$state_workspace_session_dir" 2>/dev/null; then
              chmod 700 "$host_agent_dir" "$host_agent_dir/sessions" "$host_project_session_dir" "$state_workspace_session_dir" 2>/dev/null || true
              if [ -d "$state_workspace_session_dir" ] && [ "$state_workspace_session_dir" != "$host_project_session_dir" ]; then
                find "$state_workspace_session_dir" -maxdepth 1 -type f -name '*.jsonl' -exec cp -n {} "$host_project_session_dir/" \; 2>/dev/null || true
              fi
              session_bind_args=(--bind "$host_project_session_dir" "/home/pi/.pi/agent/sessions/$sandbox_session_dir_name")
            else
              echo "pi-bwrap: warning: could not prepare host project session dir: $host_project_session_dir" >&2
            fi
          fi

          coord_root_bind_args=()
          sandbox_coord_root=""
          if [ -n "''${PI_COORD_ROOT:-}" ]; then
            case "$PI_COORD_ROOT" in
              /*)
                host_coord_root="$(realpath -m "$PI_COORD_ROOT")"
                ;;
              *)
                host_coord_root="$(realpath -m "$project_root/$PI_COORD_ROOT")"
                ;;
            esac
            case "$host_coord_root" in
              "$project_root")
                sandbox_coord_root="/workspace"
                ;;
              "$project_root"/*)
                sandbox_coord_root="/workspace''${host_coord_root#"$project_root"}"
                ;;
              *)
                if [ -d "$host_coord_root" ]; then
                  sandbox_coord_root="/agent-remotes"
                  coord_root_bind_args=(--dir /agent-remotes --bind "$host_coord_root" /agent-remotes)
                  echo "pi-bwrap: coordination remotes available at /agent-remotes" >&2
                else
                  sandbox_coord_root="$PI_COORD_ROOT"
                  echo "pi-bwrap: warning: PI_COORD_ROOT outside project is not an existing directory and will not be mounted: $PI_COORD_ROOT" >&2
                fi
                ;;
            esac
          elif [ -z "''${PI_COORD_REMOTE_URL:-}" ] && [ ! -d "$project_root/agent-remotes" ] && [ -d /workspace/agent-remotes ]; then
            host_common_coord_root="$(realpath -m /workspace/agent-remotes)"
            project_coord_root="$(realpath -m "$project_root/agent-remotes")"
            if [ "$host_common_coord_root" != "$project_coord_root" ]; then
              coord_root_bind_args=(--bind "$host_common_coord_root" /workspace/agent-remotes)
              echo "pi-bwrap: compatibility: host /workspace/agent-remotes available at /workspace/agent-remotes" >&2
            fi
          fi

          coord_bind_args=()
          sandbox_coord_dir=""
          host_coord_dir=""
          coord_dir_explicit=0

          if [ -n "''${PI_BWRAP_COORDINATION_DIR:-}" ]; then
            host_coord_dir="$(realpath -m "$PI_BWRAP_COORDINATION_DIR")"
            coord_dir_explicit=1
          elif [ -n "''${PI_COORD_DIR:-}" ]; then
            coord_dir_explicit=1
            case "$PI_COORD_DIR" in
              /*)
                host_coord_dir="$(realpath -m "$PI_COORD_DIR")"
                ;;
              *)
                host_coord_dir="$(realpath -m "$project_root/$PI_COORD_DIR")"
                ;;
            esac
          elif [ -d "$project_root/.pi-env/coordination" ]; then
            host_coord_dir="$(realpath -m "$project_root/.pi-env/coordination")"
          elif [ -d "$project_root/coordination" ]; then
            host_coord_dir="$(realpath -m "$project_root/coordination")"
          fi

          if [ -n "$host_coord_dir" ]; then
            if [ -d "$host_coord_dir" ]; then
              case "$host_coord_dir" in
                "$project_root")
                  sandbox_coord_dir="/workspace"
                  ;;
                "$project_root"/*)
                  sandbox_coord_dir="/workspace''${host_coord_dir#"$project_root"}"
                  ;;
                *)
                  sandbox_coord_dir="/coordination"
                  coord_bind_args=(--dir /coordination --bind "$host_coord_dir" /coordination)
                  ;;
              esac

              if [ -d "$host_coord_dir/.git" ] || [ -f "$host_coord_dir/AGENTS.md" ]; then
                echo "pi-bwrap: coordination repo available at $sandbox_coord_dir" >&2
                echo "pi-bwrap: pull/rebase before changing shared state" >&2
              fi
            elif [ "$coord_dir_explicit" = "1" ]; then
              echo "pi-bwrap: warning: coordination dir not found: $host_coord_dir" >&2
            fi
          fi

          if [ "$#" -eq 0 ]; then
            pi_args=(--tools "$DEFAULT_PI_TOOLS" --continue)
          else
            pi_args=("$@")
          fi

          env_args=(--clearenv)

          set_env() {
            env_args+=(--setenv "$1" "$2")
          }

          copy_env() {
            local name="$1"
            local value
            if value="$(printenv "$name" 2>/dev/null)" && [ -n "$value" ]; then
              set_env "$name" "$value"
            fi
          }

          set_env TERM "''${TERM:-xterm-256color}"
          copy_env COLORTERM
          copy_env NO_COLOR
          copy_env FORCE_COLOR

          for name in \
            ANTHROPIC_API_KEY \
            OPENAI_API_KEY OPENAI_BASE_URL \
            AZURE_OPENAI_API_KEY AZURE_OPENAI_BASE_URL AZURE_OPENAI_RESOURCE_NAME AZURE_OPENAI_API_VERSION AZURE_OPENAI_DEPLOYMENT_NAME_MAP \
            DEEPSEEK_API_KEY GEMINI_API_KEY MISTRAL_API_KEY GROQ_API_KEY CEREBRAS_API_KEY \
            CLOUDFLARE_API_KEY CLOUDFLARE_ACCOUNT_ID CLOUDFLARE_GATEWAY_ID \
            XAI_API_KEY OPENROUTER_API_KEY AI_GATEWAY_API_KEY ZAI_API_KEY OPENCODE_API_KEY \
            HF_TOKEN FIREWORKS_API_KEY TOGETHER_API_KEY KIMI_API_KEY MINIMAX_API_KEY MINIMAX_CN_API_KEY \
            XIAOMI_API_KEY XIAOMI_TOKEN_PLAN_CN_API_KEY XIAOMI_TOKEN_PLAN_AMS_API_KEY XIAOMI_TOKEN_PLAN_SGP_API_KEY
          do
            copy_env "$name"
          done

          if [ -n "''${PI_BWRAP_PASS_ENV:-}" ]; then
            for name in $(printf '%s' "''${PI_BWRAP_PASS_ENV}" | tr ',:' '  '); do
              copy_env "$name"
            done
          fi

          validated_extra_path=""
          append_validated_extra_path() {
            if [ -z "$validated_extra_path" ]; then
              validated_extra_path="$1"
            else
              validated_extra_path="$validated_extra_path:$1"
            fi
          }

          if [ -n "''${PI_BWRAP_EXTRA_PATH:-}" ]; then
            old_ifs="$IFS"
            IFS=:
            for extra_path_entry in $PI_BWRAP_EXTRA_PATH; do
              IFS="$old_ifs"
              [ -n "$extra_path_entry" ] || { IFS=:; continue; }
              case "$extra_path_entry" in
                /*) ;;
                *)
                  echo "pi-bwrap: unsafe PI_BWRAP_EXTRA_PATH entry is not absolute: $extra_path_entry" >&2
                  exit 2
                  ;;
              esac
              if [ ! -d "$extra_path_entry" ]; then
                echo "pi-bwrap: unsafe PI_BWRAP_EXTRA_PATH entry is not an existing directory: $extra_path_entry" >&2
                exit 2
              fi
              canonical_extra_path="$(realpath "$extra_path_entry")"
              case "$canonical_extra_path" in
                /nix/store/*)
                  append_validated_extra_path "$canonical_extra_path"
                  ;;
                *)
                  echo "pi-bwrap: unsafe PI_BWRAP_EXTRA_PATH entry outside /nix/store: $extra_path_entry -> $canonical_extra_path" >&2
                  exit 2
                  ;;
              esac
              IFS=:
            done
            IFS="$old_ifs"
          fi

          sandbox_path="${runtimePath}"
          if [ -n "$validated_extra_path" ]; then
            sandbox_path="$sandbox_path:$validated_extra_path"
          fi
          sandbox_path="$sandbox_path:/usr/local/bin:/usr/bin:/bin"

          if [ -n "''${PI_COORD_ROOT:-}" ]; then
            set_env PI_COORD_ROOT "$sandbox_coord_root"
          fi
          copy_env PI_COORD_REMOTE_URL
          copy_env PI_COORD_PROJECT
          copy_env PI_COORD_WORKSPACE
          copy_env PI_COORD_AGENT_ID
          copy_env PI_COORD_PROJECT_KEY
          copy_env PI_COORD_ROLE
          if [ -n "$sandbox_coord_dir" ]; then
            set_env PI_COORD_DIR "$sandbox_coord_dir"
          else
            copy_env PI_COORD_DIR
          fi

          bwrap_args=(
            --die-with-parent
            --unshare-all
            --new-session
            --proc /proc
            --dev /dev
            --tmpfs /tmp
            --dir /run
            --dir /var
            --tmpfs /var/tmp
            --dir /etc
            --dir /etc/ssl
            --dir /bin
            --dir /nix
            --dir /usr
            --dir /usr/bin
            --dir /usr/local
            --dir /usr/local/bin
            --dir /usr/local/lib
            --dir /usr/local/lib/node_modules
            --dir /usr/local/lib/node_modules/@earendil-works
            --dir /home
            --ro-bind /nix/store /nix/store
            --ro-bind-try /etc/passwd /etc/passwd
            --ro-bind-try /etc/group /etc/group
            --ro-bind-try /etc/nsswitch.conf /etc/nsswitch.conf
            --ro-bind-try /etc/hosts /etc/hosts
            --ro-bind-try /etc/resolv.conf /etc/resolv.conf
            --ro-bind-try /etc/ssl/certs /etc/ssl/certs
            --ro-bind-try /etc/ca-certificates /etc/ca-certificates
            --ro-bind-try /etc/pki /etc/pki
            --ro-bind-try /usr/local/bin /usr/local/bin
            --ro-bind-try /usr/local/lib/node_modules/@earendil-works/pi-coding-agent /usr/local/lib/node_modules/@earendil-works/pi-coding-agent
            --symlink ${pkgs.bash}/bin/bash /bin/bash
            --symlink ${pkgs.bash}/bin/bash /bin/sh
            --symlink ${pkgs.coreutils}/bin/env /usr/bin/env
            --bind "$project_root" /workspace
            "''${coord_root_bind_args[@]}"
            --bind "$state_base/home" /home/pi
            --bind "$state_base/agent" /home/pi/.pi/agent
            "''${extension_bind_args[@]}"
            "''${session_bind_args[@]}"
            "''${coord_bind_args[@]}"
            --bind "$state_base/cache" /home/pi/.cache
            --chdir "$inside_cwd"
            --setenv HOME /home/pi
            --setenv SHELL /bin/bash
            --setenv USER pi
            --setenv LOGNAME pi
            --setenv PWD "$inside_cwd"
            --setenv PI_CODING_AGENT_DIR /home/pi/.pi/agent
            --setenv PI_CODING_AGENT_SESSION_DIR /home/pi/.pi/agent/sessions
            --setenv XDG_CACHE_HOME /home/pi/.cache
            --setenv TMPDIR /tmp
            --setenv PATH "$sandbox_path"
            --setenv SSL_CERT_FILE "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
            --setenv NIX_SSL_CERT_FILE "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
            --setenv GIT_CONFIG_NOSYSTEM 1
            --setenv PI_SKIP_VERSION_CHECK "''${PI_SKIP_VERSION_CHECK:-1}"
            --setenv PI_TELEMETRY "''${PI_TELEMETRY:-0}"
          )

          if [ "''${PI_BWRAP_NET:-1}" = "1" ]; then
            bwrap_args+=(--share-net)
          fi

          exec ${pkgs.bubblewrap}/bin/bwrap \
            "''${env_args[@]}" \
            "''${bwrap_args[@]}" \
            -- ${pkgs.bash}/bin/bash -lc 'exec pi "$@"' pi "''${pi_args[@]}"
        '';

      mkPiStart = pkgs:
        let
          piBwrap = mkPiBwrap pkgs;
          roleManagerPackage = mkRoleManagerPackage pkgs;
        in
        pkgs.writeShellScriptBin "pi-start" ''
          set -euo pipefail
          tools="${defaultTools}"
          if [ -n "''${PI_BWRAP_DEFAULT_TOOLS:-}" ]; then
            tools="$PI_BWRAP_DEFAULT_TOOLS"
          fi

          role_manager_args=()
          if [ "''${PI_ENV_ROLE_MANAGER_AUTO:-1}" != "0" ]; then
            role_manager_package="''${PI_ENV_ROLE_MANAGER_PACKAGE:-${roleManagerPackage}}"
            if [ -n "$role_manager_package" ] && [ -e "$role_manager_package" ]; then
              role_manager_args=(-e "$role_manager_package")
            fi
          fi

          exec ${piBwrap}/bin/pi-bwrap --tools "$tools" --continue "''${role_manager_args[@]}" "$@"
        '';

      mkPiEnv = pkgs:
        let
          piStart = mkPiStart pkgs;
          piBwrap = mkPiBwrap pkgs;
          runtimePath = pkgs.lib.makeBinPath (mkRuntime pkgs);
        in
        pkgs.writeShellScriptBin "pi-env" ''
          set -euo pipefail
          export PATH="${runtimePath}:''${PATH:-}"

          usage() {
            cat <<'USAGE'
          pi-env - run Pi through the pi-env launcher

          Usage:
            pi-env [pi args...]
            pi-env --raw -- [pi args...]
            pi-env --help

          Default mode delegates to pi-start, preserving pi-env defaults.
          Raw mode delegates to pi-bwrap for fully custom Pi arguments.
          The packaged command ignores --flake; checkout direct mode uses it
          before entering nix develop.
          USAGE
          }

          raw=0
          while [ "$#" -gt 0 ]; do
            case "$1" in
              -h|--help)
                usage
                exit 0
                ;;
              --raw)
                raw=1
                shift
                if [ "''${1:-}" = "--" ]; then
                  shift
                fi
                break
                ;;
              --flake)
                shift
                if [ "$#" -eq 0 ]; then
                  echo "pi-env: --flake requires an argument" >&2
                  exit 2
                fi
                shift
                ;;
              --flake=*)
                shift
                ;;
              --)
                shift
                break
                ;;
              *)
                break
                ;;
            esac
          done

          if [ "$raw" = "1" ]; then
            exec ${piBwrap}/bin/pi-bwrap -- "$@"
          fi

          exec ${piStart}/bin/pi-start "$@"
        '';

      agentCoordCommandNames = [
        "bootstrap-coordination"
        "agent-coord-init"
        "agent-coord-clone"
        "agent-coord-status"
        "agent-coord-list"
        "agent-coord-cat"
        "agent-coord-pull"
        "agent-coord-push"
        "agent-coord-new"
        "agent-coord-claim"
        "agent-coord-done"
        "agent-coord-review"
        "agent-coord-verify"
        "agent-coord-close"
        "agent-coord-lint"
        "agent-coord-generate-requirements"
        "agent-coord-generate-requirements-coverage"
        "agent-coord-upgrade-rules"
        "pi-serial-roles"
      ];

      mkAgentCoordSupport = pkgs:
        pkgs.runCommand "pi-env-agent-coordination-support" { } ''
          mkdir -p "$out/share/pi-env"
          cp -R ${./pi-skill-templates} "$out/share/pi-env/pi-skill-templates"
          cp -R ${./scripts} "$out/share/pi-env/scripts"
          chmod +x "$out/share/pi-env/scripts"/agent-coord-* \
            "$out/share/pi-env/scripts/bootstrap-coordination" \
            "$out/share/pi-env/scripts/pi-serial-roles"
        '';

      mkAgentCoordCommand = pkgs: name:
        let
          runtimePath = pkgs.lib.makeBinPath (mkRuntime pkgs);
          support = mkAgentCoordSupport pkgs;
          roleManagerPackage = mkRoleManagerPackage pkgs;
        in
        pkgs.writeShellScriptBin name ''
          set -euo pipefail
          export PATH="${runtimePath}:''${PATH:-}"
          export PI_ENV_COORD_TEMPLATE_DIR="${support}/share/pi-env/pi-skill-templates/agent-coordination"
          export PI_ENV_COORD_LIB="${support}/share/pi-env/scripts/agent-coord-lib.sh"
          export PI_ENV_ROLE_MANAGER_PACKAGE="''${PI_ENV_ROLE_MANAGER_PACKAGE:-${roleManagerPackage}}"
          exec ${pkgs.bash}/bin/bash "${support}/share/pi-env/scripts/${name}" "$@"
        '';

      mkAgentCoordCommands = pkgs:
        builtins.listToAttrs (map (name: {
          inherit name;
          value = mkAgentCoordCommand pkgs name;
        }) agentCoordCommandNames);

      mkRoleManagerPackage = pkgs:
        pkgs.runCommand "pi-env-role-manager" { } ''
          mkdir -p "$out"
          cp -R ${./role-manager}/. "$out/"
        '';

      mkPiShell =
        { pkgs
        , extraPackages ? [ ]
        , shellHook ? ""
        , includeCoordinationHelpers ? true
        }:
        let
          piBwrap = mkPiBwrap pkgs;
          piStart = mkPiStart pkgs;
          piEnv = mkPiEnv pkgs;
          agentCoordCommands = builtins.attrValues (mkAgentCoordCommands pkgs);
          coordinationPackages = if includeCoordinationHelpers then agentCoordCommands else [ ];
          roleManagerPackage = mkRoleManagerPackage pkgs;
          extraPackagePath = pkgs.lib.makeBinPath extraPackages;
        in
        pkgs.mkShell {
          packages = (mkRuntime pkgs) ++ (mkDevShellTools pkgs) ++ [
            piBwrap
            piStart
            piEnv
          ] ++ coordinationPackages ++ extraPackages;

          shellHook = ''
            export PS1="(nix-dev) \u@\h:\w$ "
            export PI_ENV_ROLE_MANAGER_PACKAGE="${roleManagerPackage}"
            if [ -n "${extraPackagePath}" ]; then
              if [ -n "''${PI_BWRAP_EXTRA_PATH:-}" ]; then
                export PI_BWRAP_EXTRA_PATH="${extraPackagePath}:$PI_BWRAP_EXTRA_PATH"
              else
                export PI_BWRAP_EXTRA_PATH="${extraPackagePath}"
              fi
            fi
            if [ -z "''${PI_ENV_QUIET:-}" ]; then
              echo "Pi agent runtime loaded"
              echo "Use 'pi-env' for default startup, or 'pi-env --raw -- <pi args>' for custom runs."
            fi
          '' + shellHook;
        };
    in
    {
      lib = {
        inherit
          defaultTools
          mkRuntime
          mkDevShellTools
          mkPiBwrap
          mkPiStart
          mkPiEnv
          agentCoordCommandNames
          mkAgentCoordSupport
          mkAgentCoordCommand
          mkAgentCoordCommands
          mkRoleManagerPackage
          mkPiShell;
      };
    }
    // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        piBwrap = mkPiBwrap pkgs;
        piStart = mkPiStart pkgs;
        piEnv = mkPiEnv pkgs;
        agentCoordCommands = mkAgentCoordCommands pkgs;
        agentCoordCommandPackages = builtins.attrValues agentCoordCommands;
        roleManagerPackage = mkRoleManagerPackage pkgs;
        coreRuntimePaths = (mkRuntime pkgs) ++ [
          piBwrap
          piStart
          piEnv
        ];
        piCore = pkgs.buildEnv {
          name = "pi-env-core";
          paths = coreRuntimePaths;
        };
        piCoordination = pkgs.buildEnv {
          name = "pi-env-coordination";
          paths = agentCoordCommandPackages;
        };
        piRuntime = pkgs.buildEnv {
          name = "pi-env-runtime";
          paths = coreRuntimePaths ++ agentCoordCommandPackages;
        };
        smokeCheck = name: nativeBuildInputs: script:
          pkgs.runCommand name { inherit nativeBuildInputs; } ''
            set -euo pipefail
            ${script}
            touch "$out"
          '';
      in
      {
        packages = {
          default = piEnv;
          pi-env = piEnv;
          pi-start = piStart;
          pi-bwrap = piBwrap;
          pi-core = piCore;
          pi-runtime = piRuntime;
          pi-coordination = piCoordination;
          pi-role-manager = roleManagerPackage;
        } // agentCoordCommands;

        apps = {
          default = {
            type = "app";
            program = "${piEnv}/bin/pi-env";
          };
          pi-env = {
            type = "app";
            program = "${piEnv}/bin/pi-env";
          };
          pi-start = {
            type = "app";
            program = "${piStart}/bin/pi-start";
          };
          pi-bwrap = {
            type = "app";
            program = "${piBwrap}/bin/pi-bwrap";
          };
        };

        checks = {
          pi-core-smoke = smokeCheck "pi-env-core-smoke" [ piCore ] ''
            command -v pi-env >/dev/null
            command -v pi-start >/dev/null
            command -v pi-bwrap >/dev/null
            pi-env --help >/dev/null
            pi-bwrap --help >/dev/null
            if command -v agent-coord-status >/dev/null 2>&1; then
              echo "agent coordination helpers leaked into pi-core" >&2
              exit 1
            fi
          '';

          pi-runtime-compat-smoke = smokeCheck "pi-env-runtime-compat-smoke" [ piRuntime ] ''
            command -v pi-env >/dev/null
            command -v pi-start >/dev/null
            command -v pi-bwrap >/dev/null
            command -v agent-coord-status >/dev/null
            command -v bootstrap-coordination >/dev/null
            pi-env --help >/dev/null
            agent-coord-status --help >/dev/null
          '';

          pi-coordination-smoke = smokeCheck "pi-env-coordination-smoke" [ piCoordination ] ''
            command -v agent-coord-status >/dev/null
            command -v agent-coord-lint >/dev/null
            command -v bootstrap-coordination >/dev/null
            agent-coord-lint --help >/dev/null
            bootstrap-coordination --help >/dev/null
          '';
        };

        devShells.default = mkPiShell { inherit pkgs; };
      });
}
