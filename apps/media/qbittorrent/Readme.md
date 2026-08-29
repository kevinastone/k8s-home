# qBittorrent

Optimal configuration settings are fully declared and managed via GitOps:

- Docker and network variables are configured in [helmrelease.yaml](helmrelease.yaml).
- Application preferences are managed in [qBittorrent.conf](resources/qBittorrent.conf) (mounted as a read-only `ConfigMap` volume).

## Manual Settings

Due to serialization limitations in `qBittorrent.conf` (which stores watch paths as serialized Qt binary blobs), the monitored directory must be configured manually via the WebUI:

- **Downloads**
  - **Automatically add torrents from:** `/incoming` (monitors `/incoming` for `.torrent` files)
