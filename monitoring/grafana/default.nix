{ lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      root = ../..;
      cueSrc = lib.fileset.toSource {
        inherit root;
        fileset = lib.fileset.unions [
          (root + "/cue")
          (root + "/cue.mod")
        ];
      };
      dashboardsSrc = lib.fileset.toSource {
        inherit root;
        fileset = lib.fileset.unions [
          (root + "/cue")
          (root + "/cue.mod")
          (lib.fileset.fileFilter (file: file.hasExt "cue" || file.hasExt "json") root)
        ];
      };
      writeNuBin =
        {
          name ? pkgs.lib.removeSuffix ".nu" (baseNameOf script),
          script,
          runtimeInputs ? [ ],
        }:
        let
          writer = pkgs.writers.makeScriptWriter (
            {
              interpreter = "${pkgs.nushell}/bin/nu";
            }
            // (pkgs.lib.optionalAttrs (runtimeInputs != [ ]) {
              makeWrapperArgs = [
                "--prefix"
                "PATH"
                ":"
                (pkgs.lib.makeBinPath runtimeInputs)
              ];
            })
          );
        in
        writer "/bin/${name}" (builtins.readFile script);

      build-dashboards = writeNuBin {
        name = "build-dashboards";
        script = ./scripts/build_dashboards.nu;
        runtimeInputs = with pkgs; [
          cue
          diffutils
        ];
      };

      download-dashboards = pkgs.writeShellApplication {
        name = "download-dashboards";
        runtimeInputs = [ pkgs.python3 ];
        text = ''
          python3 "${./scripts/download_dashboards.py}" "$@"
        '';
      };
    in
    {
      treefmt = {
        programs.cue.enable = true;
        settings.formatter.nufmt = {
          command = "${pkgs.nufmt}/bin/nufmt";
          includes = [ "*.nu" ];
        };
      };

      packages = {
        inherit build-dashboards download-dashboards;
      };

      checks = {
        cue-vet =
          pkgs.runCommandLocal "cue-vet"
            {
              nativeBuildInputs = [ pkgs.cue ];
            }
            ''
              set -o pipefail
              cue --chdir ${cueSrc} vet --concrete ./cue/grafana/ | tee $out
            '';

        dashboards-in-sync =
          pkgs.runCommandLocal "dashboards-in-sync"
            {
              nativeBuildInputs = [ build-dashboards ];
            }
            ''
              build-dashboards --check ${dashboardsSrc}
              touch $out
            '';
      };

      devShellPackages = [
        build-dashboards
        download-dashboards
      ];
    };
}
