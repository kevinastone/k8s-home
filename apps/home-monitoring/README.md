# Home Monitoring

This app provisions home environment and power monitoring dashboards into Grafana, replacing the legacy Home Assistant Lovelace dashboard UI with metrics collected by VictoriaMetrics.

## Overview

- **Source Metrics**: Sensor and power metrics collected from Zigbee devices via `zigbee2mqtt` and pushed into VictoriaMetrics through the InfluxDB line-protocol compatibility endpoint (`influxdb.k8s.kevinastone.com`).
- **Templating**: The dashboard is modeled in **[CUE](https://cuelang.org/)** under [`dashboards/home.cue`](dashboards/home.cue), providing strongly-typed, reusable components for room cards and power tiles without hand-writing monolithic JSON files.
- **GitOps & Deployment**: The compiled [`dashboards/home.json`](dashboards/home.json) is packaged into a Kubernetes `ConfigMap` labeled `grafana_dashboard: "true"` by [`kustomization.yaml`](kustomization.yaml). Grafana's sidecar automatically discovers this ConfigMap across namespaces and imports it.

## Dashboard Components

The dashboard mimics [`apps/home-assistant/resources/ui-lovelace.yaml`](../home-assistant/resources/ui-lovelace.yaml):

1. **Room Environment Cards** (Bedroom, Office, Living Room):
   - Stat panels with sparklines for **Temperature** (`°F`), **Humidity** (`%`), and **Pressure** (`inHg`).
   - 24-hour temperature history graph (matching the Lovelace graph footer).
1. **Device Power Tiles**:
   - Power stat panels with sparklines in Watts (`W`) for **Rack Power**, **Media Power**, and **Desk Power**.
1. **Appliance Status**:
   - **Washing Machine**: Binary state indicator (`Idle` / `Running`) derived from `laundry_power_power > 10W`.

## Re-generating Dashboards

Whenever you update [`dashboards/home.cue`](dashboards/home.cue), re-generate the JSON dashboard using either:

1. **Via the Nix Development Shell** (with `nix develop` or direnv):

   ```bash
   build-dashboards apps/home-monitoring/dashboards
   ```

1. **Via Script Directly**:

   ```bash
   ./scripts/build_dashboards.sh apps/home-monitoring/dashboards
   ```

1. **Or via `cue` directly**:

   ```bash
   cue export apps/home-monitoring/dashboards/home.cue -e out --out json > apps/home-monitoring/dashboards/home.json
   ```

Before committing, format files with:

```bash
nix fmt
```
