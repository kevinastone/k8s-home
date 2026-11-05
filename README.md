# K8s at Home

GitOps repository managing my homelab Kubernetes cluster using [FluxCD](https://fluxcd.io/).

______________________________________________________________________

## Architecture Overview

```mermaid
flowchart TD
    subgraph External ["External Network & Services"]
        Router["Upstream Router (FRR / BGP 65000)"]
        OnePassword["1Password (Vaults)"]
        Cloudflare["Cloudflare (DNS & Edge)"]
        S3Remote["Off-site Backups"]
    end

    subgraph Cluster ["Kubernetes Cluster (BGP 65020)"]
        subgraph Networking ["Networking & Gateway API"]
            Cilium["Cilium CNI (eBPF, KPR, LB-IPAM, BGP)"]
            Envoy["Envoy Gateway (Gateway API / HTTPRoute)"]
            Blocky["Blocky & k8s-gateway (Internal DNS)"]
            ExternalDNS["external-dns"]
        end

        subgraph CoreGitOps ["GitOps & Orchestration"]
            Flux["FluxCD (v2, OCI Repositories)"]
            Tofu["tofu-controller (OpenTofu / Terraform)"]
        end

        subgraph Security ["Secrets & Policy"]
            ESO["External Secrets Operator"]
            SOPS["SOPS (age encryption)"]
        end

        subgraph StorageData ["Storage & State"]
            Longhorn["Longhorn (Distributed Block)"]
            OpenEBS["OpenEBS (LocalPV)"]
            CNPG["CloudNativePG (Postgres HA)"]
            RustFS["rustfs (In-cluster S3)"]
            Dragonfly["Dragonfly (Redis / Caching)"]
        end

        subgraph Observability ["Observability & Alerting"]
            VM["VictoriaMetrics (vmagent, vmalert, vmcluster)"]
            AM["Alertmanager & Karma"]
            Grafana["Grafana (CUE Dashboards)"]
            Loki["Grafana Loki (Logs)"]
        end

        subgraph Apps ["Workloads"]
            HA["Home Assistant"]
            Media["Media Stack (Radarr, Sonarr, qBittorrent, etc.)"]
            OtherApps["Other Web & IoT Services"]
        end
    end

    Router <-->|BGP Peering / VIP Routes| Cilium
    OnePassword -->|ExternalSecrets| ESO
    Cloudflare <-->|DNS Sync & Certificates| ExternalDNS
    ExternalDNS --> Cloudflare

    Cilium --> Envoy
    Envoy --> Apps
    ESO --> Apps
    Longhorn --> Apps
    CNPG --> Apps
    VM --> Observability
```

______________________________________________________________________

## Core Technologies

### Networking & Routing

- **CNI & BGP**: [Cilium](https://cilium.io/) with eBPF, `kubeProxyReplacement: true`, native BGP Control Plane peering with upstream FRR, and LoadBalancer IPAM (`CiliumLoadBalancerIPPool`).
- **Ingress & Gateway API**: [Envoy Gateway](https://gateway.envoyproxy.io/) implementing the Kubernetes Gateway API (`Gateway`, `HTTPRoute`, `SecurityPolicy`).
- **DNS**: [Blocky](https://0xerr0r.github.io/blocky/) ad-blocking DNS combined with [k8s-gateway](https://github.com/ori-edge/k8s_gateway) for cluster services, and [external-dns](https://github.com/kubernetes-sigs/external-dns) for Cloudflare public records.
- **Certificates**: [cert-manager](https://cert-manager.io/) with Cloudflare ACME DNS-01 validation.

### GitOps & Automation

- **GitOps Engine**: [FluxCD](https://fluxcd.io/) (`Kustomization`, `HelmRelease`, `OCIRepository`).
- **Infrastructure as Code**: [tofu-controller](https://github.com/flux-iac/tofu-controller) managing OpenTofu/Terraform infrastructure modules (e.g. S3 buckets, cloud configs).
- **Automated Updates**: [Renovate](https://github.com/renovatebot/renovate) with custom regex managers and automated digest pinning.

### Secrets Management

- **Primary (Runtime Secrets)**: [External Secrets Operator](https://external-secrets.io/) fetching secrets directly from **1Password** via the 1Password SDK / Connect `ClusterSecretStore`.
- **Bootstrap Secrets**: [SOPS](https://github.com/getsops/sops) with `age` encryption for cluster bootstrap tokens (1Password credentials, Flux webhooks).

### Storage & Databases

- **Block Storage**: [Longhorn](https://longhorn.io/) distributed block storage with snapshotting, and [OpenEBS](https://openebs.io/) LocalPV for high-performance node-local data.
- **Databases**: [CloudNativePG](https://cloudnative-pg.io/) managing high-availability PostgreSQL clusters with Barman Cloud backups to S3.
- **Object Storage**: [rustfs](https://github.com/rustfs) S3-compatible in-cluster object storage.
- **Key-Value Store**: [Dragonfly](https://dragonflydb.io/) Operator high-performance Redis-compatible cache.

### Observability & Alerting

- **Metrics**: [VictoriaMetrics](https://victoriametrics.com/) Operator (`vmcluster`, `vmalert`, `vmagent`) scraping targets via `PodMonitor` and evaluating `PrometheusRule` manifests.
- **Alerting**: Alertmanager with [Karma](https://github.com/prymitive/karma) dashboard UI.
- **Logging**: [Grafana Loki](https://grafana.com/oss/loki/).
- **Dashboards**: Grafana dashboards generated via **CUE** (`lib/grafana/`).

______________________________________________________________________

## Repository Structure

The deployment flow is defined by the top-level Flux `Kustomization` manifests:

```
├── repos/          # Helm repository & OCI source definitions
├── crds/           # Custom Resource Definitions & CRD controllers
├── system/         # Core infrastructure (Cilium, Envoy Gateway, Storage, Cert-Manager)
├── monitoring/     # Observability stack (VictoriaMetrics, Grafana, Alerting Rules, Loki)
├── backends/       # Foundational shared services (DNS, Authelia, LDAP, MQTT, RustFS)
├── apps/           # User-facing applications (Home Assistant, Media stack, IoT)
└── lib/grafana/    # Shared CUE library for typed Grafana dashboards
```

______________________________________________________________________

## Development & Operations

### Local Development Environment (`nix` & `direnv`)

This repository uses [Nix Flakes](https://nixos.org/) and `direnv` (`flake.nix`). Entering the repository directory automatically loads all necessary tooling:

```bash
# Enter nix development shell manually (if not using direnv)
nix develop
```

### Code Formatting (`nix fmt` / `treefmt`)

Code formatting is enforced across Markdown, YAML, and Nix via `treefmt`:

```bash
nix fmt
```

### Grafana Dashboards (CUE)

Dashboards across the repository are authored in **[CUE](https://cuelang.org/)** using shared definitions in `lib/grafana/`.

```bash
# Compile all dashboards in the repo to JSON
nix develop --command build-dashboards .

# Run unit tests and schema constraint validation
nix develop --command cue vet -c ./lib/grafana/
```

### OPA Policy Testing & Linting

Transcoder policy rules use Open Policy Agent (Rego):

```bash
# Run OPA tests
nix develop --command opa test apps/media/transcoder/policy/ -v

# Run Regal linter
nix develop --command regal lint apps/media/transcoder/policy
```

### Renovate Configuration Validation

Whenever `.github/renovate.jsonc` is modified, validate it locally:

```bash
nix develop --command renovate-config-validator .github/renovate.jsonc
```

### GitOps Workflow Rules

All cluster changes are managed strictly via GitOps (FluxCD):

- **No manual mutation**: Never run imperative `kubectl apply`, `kubectl delete`, or `helm install`.
- **Validation before commit**: Format with `nix fmt` and verify manifests render cleanly with `kustomize build`.
- **Review before push**: Git pushes trigger automatic cluster synchronization once merged.
