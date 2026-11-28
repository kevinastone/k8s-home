# qBittorrent

Optimal configuration settings are fully declared and managed via GitOps:

- Container, network, and volume configuration are defined in [helmrelease.yaml](helmrelease.yaml).
- Application preferences are managed in [qBittorrent.conf](resources/qBittorrent.conf) (mounted as a read-only `ConfigMap` volume).
- Monitored folders (e.g. `/incoming`) are declared in [watched_folders.json](resources/watched_folders.json) (mounted read-only at `/config/qBittorrent/watched_folders.json`).
