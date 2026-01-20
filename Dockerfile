FROM lscr.io/linuxserver/rdesktop:ubuntu-xfce

# Labels
ARG BUILD_DATE
ARG VERSION
LABEL build_version="MetaTrader5 Docker:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="gmartin"

# Wine environment - 64-bit prefix
ENV TITLE="MetaTrader 5"
ENV WINEPREFIX="/config/.wine"
ENV WINEDEBUG="-all"

# Install Wine from Debian repos and dependencies
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --install-recommends \
        wine \
        wine64 \
        wine32:i386 \
        cabextract \
        fonts-liberation \
        fonts-wine \
        fontconfig \
        python3 \
        python3-pip \
        curl \
        wget \
        x11-utils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install winetricks
RUN wget -O /usr/local/bin/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks && \
    chmod +x /usr/local/bin/winetricks

# Install mt5linux Python library (reusable across instances)
RUN pip install --break-system-packages --no-cache-dir --no-deps mt5linux && \
    pip install --break-system-packages --no-cache-dir rpyc plumbum numpy pyxdg

# Copy s6 service definitions and scripts
COPY root/ /

# Volume for instance-specific data
VOLUME /config
