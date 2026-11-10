{
  nixConfig = {
    extra-substituters = [ "https://nkl-sofka.cachix.org" ];
    extra-trusted-public-keys = [
      "nkl-sofka.cachix.org-1:hLg9frFNJynrxe7SSBb/p6pbawlpZmG10bw+wLsTufw="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    sofka.url = "github:nklmilojevic/sofka/v0.34.0";
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
        ./nix/tofu.nix
        ./.github
        ./apps/media/transcoder
        ./apps/media/sabnzbd
        ./monitoring/grafana
      ];

      perSystem =
        {
          config,
          inputs',
          pkgs,
          ...
        }:
        let
          sofka = inputs'.sofka.packages.default;
        in
        {
          treefmt = import ./treefmt.nix { inherit pkgs; };

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
                skopeo
                sofka
                sops
                # keep-sorted end
              ]
              ++ config.devShellPackages;
          };
        };
    };
}
