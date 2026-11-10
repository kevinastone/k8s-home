{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      imports = [
        inputs.treefmt-nix.flakeModule
        ./nix/devshell.nix
        ./apps/media/transcoder
        ./apps/media/sabnzbd
        ./monitoring/grafana
      ];

      perSystem =
        {
          config,
          pkgs,
          ...
        }:
        {
          treefmt = import ./treefmt.nix { inherit pkgs; };

          checks = {
            renovate-config =
              pkgs.runCommandLocal "renovate-config-validator"
                {
                  nativeBuildInputs = [ pkgs.renovate ];
                }
                ''
                  set -o pipefail
                  renovate-config-validator ${./.github/renovate.jsonc} | tee $out
                '';
          };

          devShells.default = pkgs.mkShell {
            nativeBuildInputs = [ config.treefmt.build.wrapper ];
            packages =
              with pkgs;
              [
                # keep-sorted start
                age
                crane
                fd
                fluxcd
                kubectl
                kubectl-cnpg
                kubent
                kustomize
                oras
                pluto
                renovate
                skopeo
                sops
                # keep-sorted end
              ]
              ++ config.devShellPackages;
          };
        };
    };
}
