# MetaTrader 5 Docker Image

Run MetaTrader 5 in Docker with web-based VNC access and Python API support.

![MetaTrader5 running inside container](https://imgur.com/v6Hm9pa.png)

## Features

- MetaTrader 5 (64-bit) in an isolated Docker container
- Web-based VNC access via [LinuxServer Webtop](https://github.com/linuxserver/docker-webtop)
- Python API access via [mt5linux](https://github.com/lucas-campagna/mt5linux)
- Automatic MT5 installation on first run

## Requirements

- Docker and Docker Compose
- x86_64/amd64 host (ARM not supported)

## Quick Start

1. Clone and start:

```bash
git clone https://github.com/gmag11/MetaTrader5-Docker-Image
cd MetaTrader5-Docker-Image
cp .env.example .env
docker compose up -d
```

2. Access MetaTrader 5 via your reverse proxy or direct container access on port 3000.

First startup takes 5-10 minutes for automatic MT5 installation.

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PUID` | `1000` | User ID for file permissions |
| `PGID` | `1000` | Group ID for file permissions |
| `TZ` | `Etc/UTC` | Timezone |
| `CUSTOM_USER` | - | VNC username (optional) |
| `PASSWORD` | - | VNC password (optional) |

### Network Access

This image does not expose ports by default. It is designed to be used behind a reverse proxy in the same Docker network. Internal ports:

| Port | Service |
|------|---------|
| 3000 | KasmVNC web interface |
| 8001 | mt5linux Python API |

To expose ports directly, add them to your docker-compose.yml:

```yaml
ports:
  - "3000:3000"
  - "8001:8001"
```

## Volume Structure

All instance-specific data is stored in `/config`:

```
/config/
├── .wine/                    # Wine prefix
│   └── drive_c/
│       └── Program Files/
│           └── MetaTrader 5/ # MT5 installation
│               └── MQL5/     # Your EA/indicators go here
```

## Python API Usage

Install mt5linux on your host:

```bash
pip install mt5linux
```

Connect to MT5:

```python
from mt5linux import MetaTrader5

mt5 = MetaTrader5(host='localhost', port=8001)
mt5.initialize()
print(mt5.version())
```

## Troubleshooting

### MT5 not starting
- Check container logs: `docker compose logs -f`
- Ensure the Wine prefix is properly initialized

### Permission issues
- Verify PUID and PGID match your host user
- Check that the volume has correct permissions

## License

MIT License - See [LICENSE.md](LICENSE.md)

## Acknowledgments

- [LinuxServer Webtop](https://github.com/linuxserver/docker-webtop)
- [mt5linux](https://github.com/lucas-campagna/mt5linux)
