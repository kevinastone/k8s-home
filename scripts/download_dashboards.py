#!/usr/bin/env python3
import io
import pathlib
import re
import sys
import urllib.request

import tomllib


def url_for_dashboard(dashboard) -> str:
    return dashboard.get('url') or \
        f"https://grafana.com/api/dashboards/{dashboard['id']}/revisions/{dashboard.get('revision', 1)}/download"


def fetch(url, destination, datasource):
    print(f"Downloading {destination} from {url}")
    with io.open(destination, "w", encoding='utf-8') as output, urllib.request.urlopen(url) as request:
        charset = request.info().get_content_charset()
        data = request.read().decode(charset)
        if isinstance(datasource, str):
            # From https://github.com/grafana/helm-charts/blob/main/charts/grafana/templates/_config.tpl#L120
            data = re.sub(r'"datasource":.*,', rf'"datasource": "{dashboard["datasource"]}",', data)
        elif isinstance(datasource, dict):
            for key, val in datasource.items():
                data = re.sub(rf'"\${{{key}}}"', rf'"{val}"', data)
        output.write(data)


def process_config(cfg_file):
    cwd = pathlib.Path(cfg_file).parent
    with open(cfg_file, "rb") as f:
        dashboards = tomllib.load(f)
        for filename, dashboard in dashboards.items():
            url = url_for_dashboard(dashboard)
            datasource = dashboard.get('datasource')
            dest_file = cwd / f"{filename}.json"
            fetch(url, dest_file, datasource)


def main() -> int:
    for cfg_file in sys.argv[1:]:
        process_config(cfg_file)
    return 0


if __name__ == '__main__':
    sys.exit(main())
