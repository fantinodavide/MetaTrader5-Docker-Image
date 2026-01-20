# MetaTrader 5 Docker Image

Run MetaTrader 5 in Docker with web-based VNC access and Python API support.

![MetaTrader5 running inside container](https://imgur.com/v6Hm9pa.png)

## Features

- MetaTrader 5 in an isolated Docker container
- Web-based VNC access via [KasmVNC](https://github.com/kasmtech/KasmVNC)
- Python API access via [mt5linux](https://github.com/lucas-campagna/mt5linux)
- 32-bit Wine prefix for compatibility with Wine 10.3+
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

2. Access MetaTrader 5 at `http://localhost:3000`

First startup takes 5-10 minutes for automatic MT5 installation.

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PUID` | `1000` | User ID for file permissions |
| `PGID` | `1000` | Group ID for file permissions |
| `TZ` | `Etc/UTC` | Timezone |
| `VNC_PORT` | `3000` | KasmVNC web interface port |
| `API_PORT` | `8001` | mt5linux API port |
| `CUSTOM_USER` | - | VNC username (optional) |
| `PASSWORD` | - | VNC password (optional) |

### Running Multiple Instances

Change ports in `.env` for each instance:

```bash
# Instance 1
VNC_PORT=3001
API_PORT=8011

# Instance 2
VNC_PORT=3002
API_PORT=8012
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

## Ports

| Port | Service |
|------|---------|
| 3000 | KasmVNC web interface |
| 8001 | mt5linux Python API |

## Troubleshooting

### MT5 not starting
- Check container logs: `docker compose logs -f`
- Ensure Wine prefix is 32-bit (check for `WINEARCH=win32` in logs)

### "Debugger detected" error
This image uses a 32-bit Wine prefix to avoid this issue with Wine 10.3+.
If you see this error, delete the volume and restart:
```bash
docker compose down -v
docker compose up -d
```

## License

MIT License - See [LICENSE.md](LICENSE.md)

## Acknowledgments

- [KasmVNC](https://github.com/kasmtech/KasmVNC)
- [LinuxServer KasmVNC Base Image](https://github.com/linuxserver/docker-baseimage-kasmvnc)
- [mt5linux](https://github.com/lucas-campagna/mt5linux)
