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

      in
      {
        formatter = treefmtConfig.config.build.wrapper;
        checks = {
          formatting = treefmtConfig.config.build.check self;
        };
        devShells.default =
          with pkgs;
          mkShell {
            nativeBuildInputs = [ treefmtConfig.config.build.wrapper ];
            packages = [
              # keep-sorted start
              age
              crane
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
              skopeo
              sops
              # keep-sorted end
            ];
          };
      }
    );
}
