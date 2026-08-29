# qBittorrent

Optimal configuration settings are fully declared and managed via GitOps:

- Docker, network variables, and the startup API lifecycle hook (which sets the `/incoming` monitored folder) are configured in [helmrelease.yaml](helmrelease.yaml).
- Application preferences are managed in [qBittorrent.conf](resources/qBittorrent.conf) (mounted as a read-only `ConfigMap` volume).
