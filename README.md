# MetaTrader 5 Docker Image

Run MetaTrader 5 in Docker with web-based VNC access.

![MetaTrader5 running inside container](https://imgur.com/v6Hm9pa.png)

## Features

- MetaTrader 5 (64-bit) in an isolated Docker container
- Web-based desktop via [LinuxServer Webtop](https://github.com/linuxserver/docker-webtop) (Selkies), with full clipboard support (including files)
- Automatic MT5 installation on first run
- Watchdog restarts MT5 if it crashes or is closed
- Configurable login, instance name and MT5 command line options
- Self-healing file ownership after a `PUID`/`PGID` change

## Requirements

- Docker and Docker Compose
- x86_64/amd64 host (ARM is not supported)

## Quick Start

```bash
git clone https://github.com/fantinodavide/MetaTrader5-Docker-Image
cd MetaTrader5-Docker-Image
cp .env.example .env   # optional, adjust as needed
docker compose up -d
```

Open the web desktop through your reverse proxy (see [Network Access](#network-access)).
The first start takes a few minutes while MetaTrader 5 is downloaded and installed.

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PUID` | `1000` | User ID that owns the files in the volume |
| `PGID` | `1000` | Group ID that owns the files in the volume |
| `TZ` | `Etc/UTC` | Timezone |
| `CUSTOM_USER` | `abc` | Web desktop username |
| `PASSWORD` | - | Web desktop password (no login when empty) |
| `TITLE` | `MetaTrader 5` | Browser tab / PWA name |
| `SELKIES_SCALING_DPI` | `96` | Desktop scaling: `96` = 100%, `120` = 125%, `144` = 150% (steps of 24, up to 288). Append `\|locked` to hide the setting from the web UI |
| `MT5_WATCHDOG_INTERVAL` | `60` | Seconds between watchdog checks, `0` disables the watchdog |
| `MT5_CMD_OPTIONS` | - | Extra command line options for `terminal64.exe`, e.g. `/portable` |

### Network Access

No ports are published by default: the image is meant to sit behind a reverse proxy on the
same Docker network.

| Port | Service |
|------|---------|
| 3000 | Web desktop (HTTP) |
| 3001 | Web desktop (HTTPS, self-signed) |

To publish them directly, add to `docker-compose.yml`:

```yaml
    ports:
      - "3001:3001"
```

Browsers only allow clipboard access over HTTPS, so prefer 3001 or a TLS-terminating proxy.

## Volume Structure

All instance data lives in `/config`:

```
/config/
├── .wine/                       # Wine prefix
│   └── drive_c/
│       └── Program Files/
│           └── MetaTrader 5/    # MT5 installation and data folder
│               ├── Config/      # Accounts (accounts.dat) and settings
│               ├── MQL5/        # Your EAs, indicators and scripts
│               └── Tester/      # Strategy Tester data
├── Desktop/                     # Desktop shortcuts
├── mt5-install.log              # Setup log of the current session (.1 = previous)
└── mt5-watchdog.log             # Watchdog log of the current session (.1 = previous)
```

## How It Works

- `init-mt5-perms` (s6, as root) gives any file in `/config` that isn't owned by
  `PUID`/`PGID` back to the desktop user before the desktop starts.
- `mt5-install` (desktop autostart) creates the Wine prefix, installs MetaTrader 5 on first
  run and starts it.
- `mt5-watchdog` (desktop autostart) starts MetaTrader 5 again whenever it isn't running.
- `mt5-launch` backs the desktop and menu shortcuts.
- `svc-mt5-shutdown` (s6) closes MetaTrader 5 cleanly when the container stops, before the
  desktop goes down, so it saves its accounts and settings.

## Troubleshooting

### MT5 is not starting

```bash
docker exec <container> cat /config/mt5-install.log /config/mt5-watchdog.log
```

If the installer download failed, restarting the container retries it.

### Text is not rendering / missing fonts

```bash
docker exec -it -u abc -e HOME=/config <container> winetricks -q corefonts tahoma
```

### UI too large or too small

Set `SELKIES_SCALING_DPI` (see [Environment Variables](#environment-variables)) and restart
the container. The web UI's sidebar changes the DPI too, but MetaTrader 5 reads it only when
it starts: after changing it there, close MT5 with File > Exit and the watchdog starts it
again at the new size.

### Permission errors

Files in `/config` are handed back to `PUID`/`PGID` on every start, so restarting the
container fixes files copied in as root. Directories bind-mounted inside `/config` are left
alone; fix their ownership on the host.

### MT5 asks for the login again after a restart

MetaTrader 5 saves accounts only when it exits cleanly and "Save password" is ticked.
The container closes it cleanly on stop, as long as Docker waits long enough:
`docker-compose.yml` sets `stop_grace_period: 1m`. The shutdown is logged in
`docker logs <container>`.

### Upgrading from the bind-mounted `./config` layout

Older versions of `docker-compose.yml` stored `/config` in `./config` next to the compose file.
It now uses the named volume `mt5-data`, so the first start after upgrading installs
MetaTrader 5 from scratch. To bring the old data over, stop the stack and copy it into the
volume (`docker volume ls` shows its name, `<project>_mt5-data`):

```bash
docker compose stop
docker run --rm -v "$PWD/config:/old:ro" -v <project>_mt5-data:/new alpine cp -a /old/. /new/
docker compose start
```

On Dokploy, `./config` lives in the deployment's code folder, which Dokploy clears on each
deploy: copy it out of `/etc/dokploy/compose/<app>/code/config` before deploying this version.

### Upgrading from a 32-bit image

Older images used a 32-bit Wine prefix. It is moved to `/config/.wine.win32-<date>` and a
new 64-bit prefix is created. Copy your `MQL5` folder and account data over from the old
prefix, then delete it.

### "Debugger detected" error

This comes from WineHQ 10.3 and later. The image uses Debian's Wine 10.0, which isn't
affected; make sure you're running an image built from this repository.

## License

[GNU Affero General Public License v3.0](LICENSE). Portions derived from
[gmag11/MetaTrader5-Docker-Image](https://github.com/gmag11/MetaTrader5-Docker-Image) remain
under their original [MIT License](LICENSE-MIT).

## Acknowledgments

- [gmag11/MetaTrader5-Docker-Image](https://github.com/gmag11/MetaTrader5-Docker-Image), the original project
- [LinuxServer Webtop](https://github.com/linuxserver/docker-webtop)
- [Wine](https://www.winehq.org/)
