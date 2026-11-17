{ lib, ... }:
let
  tfSrc = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.fileFilter (file: file.hasExt "tf") ../.;
  };
in
{
  perSystem =
    { pkgs, ... }:
    {
      treefmt.programs.terraform.enable = true;

      checks.tofu-lint =
        pkgs.runCommandLocal "tofu-lint"
          {
            nativeBuildInputs = [ pkgs.tflint ];
          }
          ''
            set -o pipefail
            tflint --recursive --chdir=${tfSrc}
            touch $out
          '';
    };
}
