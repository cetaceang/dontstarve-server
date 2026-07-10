FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG STEAM_UID=10001
ARG STEAM_GID=10001

RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl file gettext-base gosu lib32gcc-s1 lib32stdc++6 \
        libc6-i386 procps tar tini util-linux \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid "${STEAM_GID}" steam \
    && useradd --uid "${STEAM_UID}" --gid steam --create-home --shell /bin/bash steam \
    && install -d -o steam -g steam /opt/steamcmd /opt/dst /data /config \
    && curl -fsSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz \
       | tar -xz -C /opt/steamcmd \
    && chown -R steam:steam /opt/steamcmd

COPY docker/dst-entrypoint.sh /usr/local/bin/dst-entrypoint
RUN chmod 0755 /usr/local/bin/dst-entrypoint

ENV HOME=/home/steam \
    STEAMCMD_DIR=/opt/steamcmd \
    DST_INSTALL_DIR=/opt/dst \
    PERSISTENT_ROOT=/data \
    CONF_DIR=cluster

WORKDIR /opt/dst
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/dst-entrypoint"]
CMD ["master"]
