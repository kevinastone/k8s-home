_: {
  perSystem =
    { pkgs, ... }:
    {
      checks = {
        vector-validate =
          pkgs.runCommandLocal "vector-validate"
            {
              nativeBuildInputs = [ pkgs.vector ];
            }
            ''
              set -o pipefail
              vector validate --deny-warnings --no-environment --config-dir ${./config} | tee $out
            '';
      };

      devShellPackages = with pkgs; [
        vector
      ];
    };
}
