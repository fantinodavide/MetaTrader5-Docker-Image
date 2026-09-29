# MetaTrader 5 Docker Image

Run MetaTrader 5 in Docker with web-based VNC access.

![MetaTrader5 running inside container](https://imgur.com/v6Hm9pa.png)

## Features

- MetaTrader 5 (64-bit) in an isolated Docker container
- Web-based access via [LinuxServer Webtop](https://github.com/linuxserver/docker-webtop) (Selkies)
- Automatic MT5 installation on first run
- Watchdog auto-restarts MT5 if it crashes
- Configurable VNC credentials and instance name
- Full clipboard support (including files)

## Requirements

- Docker and Docker Compose
- x86_64/amd64 host (ARM not supported)

## Quick Start

1. Clone and start:

```bash
git clone https://github.com/fantinodavide/MetaTrader5-Docker-Image
cd MetaTrader5-Docker-Image
docker compose up -d
```

2. Access MetaTrader 5 via your reverse proxy or directly on port 3000.

First startup takes 5-10 minutes for automatic MT5 installation.

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PUID` | `1000` | User ID for file permissions |
| `PGID` | `1000` | Group ID for file permissions |
| `TZ` | `Etc/UTC` | Timezone |
| `CUSTOM_USER` | - | VNC username |
| `PASSWORD` | - | VNC password |
| `TITLE` | `MetaTrader 5` | Browser tab / PWA app name |
| `MT5_WATCHDOG_INTERVAL` | `60` | Seconds between watchdog checks |

### Network Access

This image does not expose ports by default. It is designed to be used behind a reverse proxy in the same Docker network.

| Port | Service |
|------|---------|
| 3000 | Web-based VNC interface |

To expose ports directly, add to your docker-compose.yml:

```yaml
ports:
  - "3000:3000"
```

## Volume Structure

All instance-specific data is stored in `/config`:

```
/config/
├── .wine/                    # Wine prefix
│   └── drive_c/
│       ├── Program Files/
│       │   └── MetaTrader 5/ # MT5 installation
│       │       └── MQL5/     # Your EAs/indicators
│       └── users/
│           └── abc/
│               └── AppData/  # MT5 account data
├── Desktop/                  # Desktop shortcuts
└── mt5-install.log          # Installation log
```

## Troubleshooting

### MT5 not starting
- Check logs: `docker compose logs -f`
- Check install log: `docker exec <container> cat /config/mt5-install.log`
- The watchdog will attempt to restart MT5 every 60 seconds (configurable)

### Text not rendering / missing fonts
Run inside the container:
```bash
su abc
export WINEPREFIX=/config/.wine
winetricks corefonts tahoma
```

### Permission issues
- Verify PUID and PGID match your host user
- Check volume permissions: files should be owned by the specified PUID/PGID

### "Debugger detected" error
This image uses Debian's Wine packages which avoid this issue. If you see this error, delete the volume and recreate:
```bash
docker compose down -v
docker compose up -d
```

## License

MIT License - See [LICENSE.md](LICENSE.md)

## Acknowledgments

- [LinuxServer Webtop](https://github.com/linuxserver/docker-webtop)
- [Wine](https://www.winehq.org/)
