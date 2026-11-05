# qBittorrent

Optimal configuration settings are fully declared and managed via GitOps:

- Docker, network variables, and the startup API lifecycle hook are configured in [helmrelease.yaml](helmrelease.yaml).
- Application preferences are managed in [qBittorrent.conf](resources/qBittorrent.conf) (mounted as a read-only `ConfigMap` volume).
- Startup Web API preferences (e.g. the `/incoming` monitored folder and peer connection limits) are declared in [preferences.jsonc](resources/preferences.jsonc).
