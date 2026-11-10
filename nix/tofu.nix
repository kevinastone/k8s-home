{ self, ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      checks.tofu-lint =
        pkgs.runCommandLocal "tofu-lint"
          {
            nativeBuildInputs = [ pkgs.tflint ];
          }
          ''
            set -o pipefail
            tflint --recursive --chdir=${self}
            touch $out
          '';
    };
}
