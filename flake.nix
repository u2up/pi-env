{
  description = "Project with Pi agent runtime";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
    common-nix-runtime.url = "git+file:///home/samo/CODEFAB/common-nix-runtime";
  };

  outputs = { self, nixpkgs, flake-utils, common-nix-runtime, ...}:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # Import nixpkgs with rust-overlay
        pkgs = import nixpkgs {
          inherit system;
        };
        commonAgentRuntime = common-nix-runtime.lib.commonAgentRuntime {
          inherit pkgs;
        };
        pi-startup = pkgs.writeShellScriptBin "pi-startup" ''
          echo "Starting PI runtime..."
          pi --tools read,grep,find,ls,edit,write,git --continue
        '';

      in
      {
        packages.pi-start = pi-startup;

        devShells.default = pkgs.mkShell {
          packages = commonAgentRuntime ++ [
            # project-specific tools here
            pi-startup
          ];

          shellHook = ''
            export PS1="(nix-dev) \u@\h:\w$ "
            echo "Pi agent runtime loaded"
          '';
        };
      });
}
