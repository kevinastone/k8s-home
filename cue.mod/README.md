# Vendored Grafana CUE Schemas

This directory contains vendored official CUE definitions from [`grafana/grafana`](https://github.com/grafana/grafana).

These schemas are imported by [`cue/grafana`](../cue/grafana) to validate dashboard structures, variables, links, and panel configurations against official Grafana specifications.

______________________________________________________________________

## Vendored Components

The vendored files in `cue.mod/pkg/github.com/grafana/grafana/` include:

1. **Dashboard Kind**: `kinds/dashboard/dashboard_kind.cue`
   - Defines `#Panel`, `#RowPanel`, `#VariableModel`, `#DashboardLink`, `#FieldConfig`, and `#DashboardSpec`.
1. **Common Schema**: `packages/grafana-schema/src/common/*.cue`
   - Common types like `VizOrientation`, `VizLegendOptions`, `VizTooltipOptions`, `GraphFieldConfig`, `ReduceDataOptions`, etc.
1. **Panel Plugins**: `public/app/plugins/panel/*/panelcfg.cue`
   - Canonical panel options and field configs for `timeseries`, `stat`, `gauge`, `state-timeline`, `table`, etc.

______________________________________________________________________

## How to Synchronize Schemas

To update or re-synchronize the vendored schemas from `grafana/grafana` (e.g. from `main` or a tagged release like `v11.x.x`):

```bash
# 1. Choose target ref (branch or tag)
GRAFANA_REF="main"
TARGET_DIR="cue.mod/pkg/github.com/grafana/grafana"

# 2. Download and extract required schema trees (using curl + tar)
mkdir -p "$TARGET_DIR"

curl -sL "https://github.com/grafana/grafana/tarball/${GRAFANA_REF}" | tar -xz \
  --strip-components=1 \
  -C "$TARGET_DIR" \
  --wildcards \
  '*/kinds/dashboard/*.cue' \
  '*/packages/grafana-schema/src/common/*.cue' \
  '*/public/app/plugins/panel/*/panelcfg.cue' \
  '*/cue.mod/module.cue'

# 3. Verify dashboard export compiles cleanly
nix develop --command build-dashboards monitoring/ apps/

# 4. Format files
nix fmt
```

> **Note:**
> Do not download via ad-hoc python scripts. Use standard `curl` and `tar` pipeline commands.
