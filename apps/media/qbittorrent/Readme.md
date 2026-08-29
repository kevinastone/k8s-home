# qBittorrent

There's a number of manual settings that need to be configured for optimal use

## Options

- Behavior
  - [Uncheck] Confirm when deleting torrents
  - [Check] Auto hide zero status filters
  - [Check] Show external IP in status bar
- Downloads
  - Default Save Path: `/incoming`
  - Monitored Folder: `/incoming`
  - [Check] Keep incomplete torrents in: `/downloads`
- Connection
  - Listening Port: `[port from VPN]`
  - [Check] Global maximum number of connections: 1000
  - [Check] Maximum number of connections per torrent: 500
- BitTorrent
  - [Uncheck] Torrent Queuing
  - [Check] Seeding Limits: when ratio reaches `0`
- Advanced
  - Network interface: `tun0`
  - Optional IP address to bind to: `All IPV4 addresses`
