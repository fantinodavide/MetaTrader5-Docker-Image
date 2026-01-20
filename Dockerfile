FROM ghcr.io/linuxserver/webtop:alpine

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
RUN apk add --no-cache \
        wine \
        wine-mono \
        winetricks \
        cabextract \
        wget \
        curl \
        python3 \
        py3-pip \
        font-noto \
        font-noto-cjk \
        ttf-dejavu \
        ttf-liberation && \
    # Install mt5linux Python library (reusable across instances)
    # Note: mt5linux has outdated pinned deps, install without deps then add what we need
    pip install --break-system-packages --no-cache-dir --no-deps mt5linux && \
    pip install --break-system-packages --no-cache-dir rpyc plumbum numpy pyxdg

# Copy s6 service definitions and scripts
COPY root/ /

# Volume for instance-specific data:
# - Wine prefix and MT5 installation
# - User accounts and settings
# - Trading history and logs
VOLUME /config
