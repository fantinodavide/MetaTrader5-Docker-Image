FROM lscr.io/linuxserver/webtop:debian-xfce

# Labels
ARG BUILD_DATE
ARG VERSION
LABEL build_version="MetaTrader5 Docker:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="gmartin"

# Wine environment - 64-bit prefix
ENV TITLE="MetaTrader 5"
ENV WINEPREFIX="/config/.wine"
ENV WINEDEBUG="-all"

# Install Wine and dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        wget \
        ca-certificates \
        gnupg2 && \
    dpkg --add-architecture i386 && \
    mkdir -pm755 /etc/apt/keyrings && \
    wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key && \
    wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/debian/dists/bookworm/winehq-bookworm.sources && \
    apt-get update && \
    apt-get install -y --install-recommends \
        winehq-stable \
        cabextract \
        fonts-liberation \
        fonts-wine \
        fontconfig \
        python3 \
        python3-pip \
        curl \
        x11-utils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install winetricks
RUN wget -O /usr/local/bin/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks && \
    chmod +x /usr/local/bin/winetricks

# Install mt5linux Python library (reusable across instances)
# Note: mt5linux has outdated pinned deps, install without deps then add what we need
RUN pip install --break-system-packages --no-cache-dir --no-deps mt5linux && \
    pip install --break-system-packages --no-cache-dir rpyc plumbum numpy pyxdg

# Copy s6 service definitions and scripts
COPY root/ /

# Volume for instance-specific data:
# - Wine prefix and MT5 installation
# - User accounts and settings
# - Trading history and logs
VOLUME /config
