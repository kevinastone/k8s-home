_: {
  perSystem =
    { pkgs, ... }:
    {
      checks = {
        home-monitoring-vector-validate =
          pkgs.runCommandLocal "home-monitoring-vector-validate"
            {
              nativeBuildInputs = [ pkgs.vector ];
            }
            ''
              set -o pipefail
              vector validate --deny-warnings --no-environment --config-dir ${./config} | tee $out
            '';
      };
    };
}
