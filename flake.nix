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
          export PI_ENV_RUNTIME_PATH="${runtimePath}"
          export PI_BWRAP_COMPILED_DEFAULT_TOOLS="${defaultTools}"
          export PI_BWRAP_BASH="${pkgs.bash}/bin/bash"
          export PI_BWRAP_ENV="${pkgs.coreutils}/bin/env"
          export PI_BWRAP_CA_BUNDLE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
          export PI_BWRAP_BWRAP="${pkgs.bubblewrap}/bin/bwrap"
          exec ${pkgs.bash}/bin/bash ${./scripts/pi-bwrap} "$@"
        '';

      mkPiStart = pkgs:
        let
          piBwrap = mkPiBwrap pkgs;
          roleManagerPackage = mkRoleManagerPackage pkgs;
        in
        pkgs.writeShellScriptBin "pi-start" ''
          set -euo pipefail
          export PI_BWRAP_COMPILED_DEFAULT_TOOLS="${defaultTools}"
          export PI_ENV_ROLE_MANAGER_PACKAGE="''${PI_ENV_ROLE_MANAGER_PACKAGE:-${roleManagerPackage}}"
          export PI_ENV_PI_BWRAP="${piBwrap}/bin/pi-bwrap"
          exec ${pkgs.bash}/bin/bash ${./scripts/pi-start} "$@"
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
          export PI_ENV_PI_START="${piStart}/bin/pi-start"
          export PI_ENV_PI_BWRAP="${piBwrap}/bin/pi-bwrap"
          exec ${pkgs.bash}/bin/bash ${./scripts/pi-env-launcher} "$@"
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
        "agent-coord-repo"
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
          pi-env-coordination = piCoordination;
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

          pi-env-coordination-smoke = smokeCheck "pi-env-coordination-smoke" [ piCoordination ] ''
            command -v agent-coord-status >/dev/null
            command -v agent-coord-repo >/dev/null
            command -v agent-coord-lint >/dev/null
            command -v bootstrap-coordination >/dev/null
            agent-coord-lint --help >/dev/null
            bootstrap-coordination --help >/dev/null
          '';
        };

        devShells.default = mkPiShell { inherit pkgs; };
      });
}
