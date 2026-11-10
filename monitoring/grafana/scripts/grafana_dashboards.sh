#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

find . -name grafana_dashboards.toml -print0 | xargs -0 "${SCRIPT_DIR}/download_dashboards.py"
