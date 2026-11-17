{ lib, ... }:
let
  policySrc = lib.fileset.toSource {
    root = ./.;
    fileset = ./policy;
  };
  scriptsSrc = lib.fileset.toSource {
    root = ./.;
    fileset = ./scripts;
  };
in
{
  perSystem =
    { pkgs, ... }:
    {
      treefmt.programs.opa.enable = true;

      checks = {
        transcoder-opa-test =
          pkgs.runCommandLocal "transcoder-opa-test"
            {
              nativeBuildInputs = [ pkgs.open-policy-agent ];
            }
            ''
              set -o pipefail
              opa test ${policySrc}/policy --verbose | tee $out
            '';

        transcoder-regal-lint =
          pkgs.runCommandLocal "transcoder-regal-lint"
            {
              nativeBuildInputs = [ pkgs.regal ];
            }
            ''
              set -o pipefail
              regal lint ${policySrc}/policy | tee $out
            '';

        transcoder-shellcheck =
          pkgs.runCommandLocal "transcoder-shellcheck"
            {
              nativeBuildInputs = [ pkgs.shellcheck ];
            }
            ''
              set -o pipefail
              shellcheck ${scriptsSrc}/scripts/*.sh | tee $out
            '';
      };

      devShellPackages = with pkgs; [
        open-policy-agent
        regal
        shellcheck
        jq
      ];
    };
}
