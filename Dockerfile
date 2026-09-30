# Same Debian release as the webtop image, so the library links against the
# same glibc.
FROM debian:trixie-slim AS mt5net
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc libc6-dev && \
    rm -rf /var/lib/apt/lists/*
COPY src/mt5net.c /src/
RUN gcc -shared -fPIC -O2 -Wall -Wextra -o /libmt5net.so /src/mt5net.c

FROM lscr.io/linuxserver/webtop:debian-xfce

LABEL org.opencontainers.image.licenses="AGPL-3.0-only"

# winemenubuilder is disabled because it generates launchers and file
# associations that bypass our environment; ours are baked into the image.
ENV TITLE="MetaTrader 5" \
    WINEPREFIX="/config/.wine" \
    WINEDEBUG="-all" \
    WINEDLLOVERRIDES="winemenubuilder.exe=d"

# Debian's own Wine (10.0). WineHQ 10.3+ trips MT5's debugger detection.
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --install-recommends \
        wine \
        wine64 \
        wine32:i386 \
        cabextract \
        fonts-liberation \
        fonts-wine \
        fontconfig && \
    curl -fsSL -o /usr/local/bin/winetricks \
        https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks && \
    chmod +x /usr/local/bin/winetricks && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY root/ /
# Fixed network adapter identity for Wine, see src/mt5net.c
COPY --from=mt5net /libmt5net.so /usr/local/lib/mt5/
# Register the baked-in wine.desktop so file managers offer it for .exe files
RUN update-desktop-database /usr/share/applications

VOLUME /config
