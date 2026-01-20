FROM ghcr.io/linuxserver/baseimage-kasmvnc:debianbookworm

# Labels
ARG BUILD_DATE
ARG VERSION
LABEL build_version="MetaTrader5 Docker:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="gmartin"

# Wine environment - use 32-bit prefix to avoid debugger detection issues with Wine 10.3+
ENV TITLE="MetaTrader 5"
ENV WINEPREFIX="/config/.wine"
ENV WINEARCH="win32"
ENV WINEDEBUG="-all"

# Install Wine and dependencies in a single layer
RUN apt-get update && \
    apt-get install -y --no-install-recommends wget ca-certificates && \
    dpkg --add-architecture i386 && \
    mkdir -pm755 /etc/apt/keyrings && \
    wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key && \
    wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/debian/dists/bookworm/winehq-bookworm.sources && \
    apt-get update && \
    apt-get install -y --install-recommends \
        winehq-stable \
        cabextract \
        xdg-utils \
        fonts-liberation \
        fonts-wine \
        fontconfig \
        python3 \
        python3-pip \
        curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install winetricks for Windows component installation
RUN wget -O /usr/local/bin/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks && \
    chmod +x /usr/local/bin/winetricks

# Install mt5linux Python library (reusable across instances)
RUN pip install --break-system-packages --no-cache-dir \
    "mt5linux>=0.1.9" rpyc plumbum numpy pyxdg

# Copy s6 service definitions and scripts
COPY root/ /

# Ports: 3000=KasmVNC web interface, 8001=mt5linux API
EXPOSE 3000 8001

# Volume for instance-specific data:
# - Wine prefix and MT5 installation
# - User accounts and settings
# - Trading history and logs
VOLUME /config
