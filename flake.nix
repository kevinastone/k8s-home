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
              # Need to patch open-policy-agent to fix darwin bugs in nixpkgs
              (open-policy-agent.overrideAttrs (_old: {
                preCheck =
                  # Feed in all but the e2e tests for testing
                  # This is because subPackages above limits what is built to just what we
                  # want but also limits the tests
                  # Also avoid wasm tests on darwin due to wasmtime-go build issues
                  ''
                    getGoDirs() {
                      go list ./... | grep -v -e e2e ${lib.optionalString pkgs.stdenv.hostPlatform.isDarwin "-e wasm"}
                    }
                  '';
              }))
              # keep-sorted start
              age
              crane
              kubectl
              kubectl-cnpg
              kubectl-rook-ceph
              kustomize
              oras
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
