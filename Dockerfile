FROM ghcr.io/linuxserver/baseimage-kasmvnc:debianbookworm

# set version label
ARG BUILD_DATE
ARG VERSION
LABEL build_version="Metatrader Docker:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="gmartin"

ENV TITLE=Metatrader5
ENV WINEPREFIX="/config/.wine"
ENV WINEARCH=win32
ENV WINEDEBUG=-all

# Install all packages in a single layer to reduce image size
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    wget \
    curl \
    gnupg2 \
    software-properties-common \
    ca-certificates \
    cabextract \
    xdg-utils \
    # Font packages for proper text rendering
    fonts-liberation \
    fonts-wine \
    fontconfig \
    && mkdir -pm755 /etc/apt/keyrings \
    && wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key \
    && wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/debian/dists/bookworm/winehq-bookworm.sources \
    && dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install --install-recommends -y winehq-stable \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /etc/apt/keyrings/winehq-archive.key

# Install winetricks for Windows component installation
RUN wget -O /usr/local/bin/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks \
    && chmod +x /usr/local/bin/winetricks


COPY /Metatrader /Metatrader
RUN chmod +x /Metatrader/start.sh
COPY /root /

EXPOSE 3000 8001
VOLUME /config
