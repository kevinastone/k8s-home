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

        build-dashboards =
          with pkgs;
          writeShellApplication {
            name = "build-dashboards";
            runtimeInputs = [ cue ];
            text = builtins.readFile ./scripts/build_dashboards.sh;
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
                nativeBuildInputs = [
                  pkgs.cue
                  pkgs.diffutils
                  pkgs.fd
                ];
              }
              ''
                fd --base-directory ${self} --extension cue --exclude 'cue.mod' --full-path 'dashboards/' \
                  --exec bash -c '
                    set -o pipefail
                    json="''${1%.cue}.json"
                    echo "Validating $1 against $json..."
                    cue --chdir ${self} export "$1" --expression out --out json | diff --unified "${self}/$json" -
                  ' _ {}
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
              fluxcd
              kubectl
              kubectl-cnpg
              kubectl-rook-ceph
              kubent
              kustomize
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
