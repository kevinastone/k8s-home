_:

{
  perSystem =
    { pkgs, ... }:
    {
      checks.renovate-config =
        pkgs.runCommandLocal "renovate-config-validator"
          {
            nativeBuildInputs = [ pkgs.renovate ];
          }
          ''
            set -o pipefail
            renovate-config-validator ${./renovate.jsonc} | tee $out
          '';
    };
}
