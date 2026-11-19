{
  perSystem =
    { pkgs, ... }:
    let
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

      bootstrap-cluster = writeNuBin {
        name = "bootstrap-cluster";
        script = ./bootstrap.nu;
        runtimeInputs = with pkgs; [
          fluxcd
          kubectl
          kubernetes-helm
        ];
      };
    in
    {
      packages = {
        inherit bootstrap-cluster;
      };

      devShellPackages = [ bootstrap-cluster ];
    };
}
