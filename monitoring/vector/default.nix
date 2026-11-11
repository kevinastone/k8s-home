_: {
  perSystem =
    { pkgs, ... }:
    {
      devShellPackages = with pkgs; [
        vector
      ];
    };
}
