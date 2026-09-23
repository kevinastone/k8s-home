_: {
  projectRootFile = ".git/config";

  settings.global.excludes = [
    "**/secrets/*.encrypted"
    "**/*sops.yaml"
    ".sops.yaml"
  ];

  # Shell formatting
  programs.shfmt.enable = true;

  # JSON/YAML formatter
  programs.yamlfmt.enable = true;
  programs.yamlfmt.settings = {
    formatter = {
      type = "basic";
      indent = 2;
      # This is the "K8s look": - name starts at same level as key
      indentless_arrays = true;
      retain_line_breaks = true;
    };
  };

  # toml formatter
  programs.taplo.enable = true;

  # Terraform/tofu formatter
  programs.terraform.enable = true;

  programs.mdformat.enable = true;

  programs.cue.enable = true;

  programs.keep-sorted.enable = true;

  # Nix formatters
  programs.nixfmt.enable = true;
  programs.statix.enable = true;
  programs.deadnix.enable = true;
  settings.formatter = {
    deadnix.priority = 1;
    statix.priority = 2;
    nixfmt.priority = 3;
  };
}
