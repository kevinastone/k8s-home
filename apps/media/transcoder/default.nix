_: {
  perSystem =
    { pkgs, ... }:
    {
      checks = {
        transcoder-opa-test =
          pkgs.runCommandLocal "transcoder-opa-test"
            {
              nativeBuildInputs = [ pkgs.open-policy-agent ];
            }
            ''
              set -o pipefail
              opa test ${./.}/policy --verbose | tee $out
            '';

        transcoder-regal-lint =
          pkgs.runCommandLocal "transcoder-regal-lint"
            {
              nativeBuildInputs = [ pkgs.regal ];
            }
            ''
              set -o pipefail
              regal lint ${./.}/policy | tee $out
            '';

        transcoder-shellcheck =
          pkgs.runCommandLocal "transcoder-shellcheck"
            {
              nativeBuildInputs = [ pkgs.shellcheck ];
            }
            ''
              set -o pipefail
              shellcheck ${./.}/scripts/*.sh | tee $out
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
