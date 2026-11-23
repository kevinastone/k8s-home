_: {
  perSystem =
    { pkgs, ... }:
    {
      checks = {
        sabnzbd-config-vet =
          pkgs.runCommandLocal "sabnzbd-config-vet"
            {
              nativeBuildInputs = [ pkgs.cue ];
            }
            ''
              set -o pipefail
              cue --chdir ${./resources/sabnzbd.ini} export \
                :sabnzbd \
                ./categories.yaml \
                ./filters.yaml \
                ./servers.yaml \
                ./shows.yaml \
                -t NZBGEEK_API_KEY=mock \
                -t NEWSHOSTING_USERNAME=mock \
                -t NEWSHOSTING_PASSWORD=mock \
                -t TWEAKNEWS_USERNAME=mock \
                -t TWEAKNEWS_PASSWORD=mock \
                -e out \
                --out text > $out
            '';
      };
    };
}
