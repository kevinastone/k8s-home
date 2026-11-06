{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      utils,
      treefmt-nix,
      ...
    }:
    utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        treefmtConfig = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;

        writeNuBin =
          {
            name ? pkgs.lib.removeSuffix ".nu" (baseNameOf script),
            script,
            runtimeInputs ? [ ],
          }:
          let
            writer = pkgs.writers.makeScriptWriter (
              {
                interpreter = "${pkgs.nushell}/bin/nu";
              }
              // (pkgs.lib.optionalAttrs (runtimeInputs != [ ]) {
                makeWrapperArgs = [
                  "--prefix"
                  "PATH"
                  ":"
                  (pkgs.lib.makeBinPath runtimeInputs)
                ];
              })
            );
          in
          writer "/bin/${name}" (builtins.readFile script);

        build-dashboards = writeNuBin {
          name = "build-dashboards";
          script = ./scripts/build_dashboards.nu;
          runtimeInputs = with pkgs; [
            cue
            diffutils
          ];
        };

      in
      {
        formatter = treefmtConfig.config.build.wrapper;
        checks = {
          formatting = treefmtConfig.config.build.check self;
          renovate-config =
            pkgs.runCommandLocal "renovate-config-validator"
              {
                nativeBuildInputs = [ pkgs.renovate ];
              }
              ''
                set -o pipefail
                renovate-config-validator ${./.github/renovate.jsonc} | tee $out
              '';
          cue-vet =
            pkgs.runCommandLocal "cue-vet"
              {
                nativeBuildInputs = [ pkgs.cue ];
              }
              ''
                set -o pipefail
                cue --chdir ${self} vet --concrete ./lib/grafana/ | tee $out
              '';
          opa-test =
            pkgs.runCommandLocal "opa-test"
              {
                nativeBuildInputs = [ pkgs.open-policy-agent ];
              }
              ''
                set -o pipefail
                opa test ${self}/apps/media/transcoder/policy --verbose | tee $out
              '';
          regal-lint =
            pkgs.runCommandLocal "regal-lint"
              {
                nativeBuildInputs = [ pkgs.regal ];
              }
              ''
                set -o pipefail
                regal lint ${self}/apps/media/transcoder/policy | tee $out
              '';
          dashboards-in-sync =
            pkgs.runCommandLocal "dashboards-in-sync"
              {
                nativeBuildInputs = [ build-dashboards ];
              }
              ''
                build-dashboards --check ${self}
                touch $out
              '';
        };
        devShells.default =
          with pkgs;
          mkShell {
            nativeBuildInputs = [ treefmtConfig.config.build.wrapper ];
            packages = [
              # keep-sorted start
              age
              build-dashboards
              crane
              cue
              fd
              fluxcd
              kubectl
              kubectl-cnpg
              kubectl-rook-ceph
              kubent
              kustomize
              nushell
              open-policy-agent
              oras
              pluto
              python3
              regal
              renovate
              skopeo
              sops
              # keep-sorted end
            ];
          };
      }
    );
}
