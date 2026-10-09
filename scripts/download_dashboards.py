#!/usr/bin/env python3
import pathlib
import re
import sys
import typing as t
import urllib.request
from dataclasses import InitVar, dataclass

import tomllib


@dataclass
class Dashboard:
    datasource: dict | str | None = None
    url: str = ""
    id: InitVar[int | None] = None
    revision: InitVar[int] = 1

    def __post_init__(self, id: int | None, revision: int):
        if not self.url:
            if id:
                # From https://github.com/grafana/helm-charts/blob/main/charts/grafana/templates/_config.tpl#L120
                self.url = f"https://grafana.com/api/dashboards/{id}/revisions/{revision}/download"
            else:
                raise ValueError("Either url or id must be set")


def fetch(url: str, destination: pathlib.Path, datasource: t.Optional[dict | str] = None):
    print(f"Downloading {destination} from {url}")
    with (
        open(destination, "w", encoding="utf-8") as output,
        urllib.request.urlopen(url) as request,
    ):
        charset = request.info().get_content_charset()
        data = request.read().decode(charset)
        if isinstance(datasource, str):
            data = re.sub(r'"datasource":.*,', rf'"datasource": "{datasource}",', data)
        elif isinstance(datasource, dict):
            for key, val in datasource.items():
                data = re.sub(rf'"\${{{key}}}"', rf'"{val}"', data)
        output.write(data)


def process_config(cfg_file: str):
    cwd = pathlib.Path(cfg_file).parent
    with open(cfg_file, "rb") as f:
        dashboards = tomllib.load(f)
        for filename, config in dashboards.items():
            try:
                dashboard = Dashboard(**config)
            except ValueError as e:
                print(f"Skipping {filename} because it is not valid: {e}")
                continue
            dest_file = cwd / f"{filename}.json"
            fetch(dashboard.url, dest_file, dashboard.datasource)


def main() -> int:
    for cfg_file in sys.argv[1:]:
        process_config(cfg_file)
    return 0


if __name__ == "__main__":
    sys.exit(main())
