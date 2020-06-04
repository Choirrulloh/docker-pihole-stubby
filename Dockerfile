FROM debian:buster as openssl

ENV VERSION_OPENSSL=openssl-1.1.1g \
    SHA256_OPENSSL=ddb04774f1e32f0c49751e21b67216ac87852ceb056b75209af2443400636d46 \
    SOURCE_OPENSSL=https://www.openssl.org/source/ \
    OPGP_OPENSSL=8657ABB260F056B1E5190839D9C4D26D0E604491

WORKDIR /tmp/src
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -e -x && \
    build_deps="build-essential ca-certificates curl dirmngr gnupg libidn2-0-dev libssl-dev" && \
    DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        dirmngr \
        gnupg \
        libidn2-0-dev \
        libssl-dev && \
    curl -L $SOURCE_OPENSSL$VERSION_OPENSSL.tar.gz -o openssl.tar.gz && \
    echo "${SHA256_OPENSSL} ./openssl.tar.gz" | sha256sum -c - && \
    curl -L $SOURCE_OPENSSL$VERSION_OPENSSL.tar.gz.asc -o openssl.tar.gz.asc && \
    GNUPGHOME="$(mktemp -d)" && \
    export GNUPGHOME && \
    ( gpg --no-tty --keyserver ipv4.pool.sks-keyservers.net --recv-keys "${OPGP_OPENSSL}" \
    || gpg --no-tty --keyserver ha.pool.sks-keyservers.net --recv-keys "${OPGP_OPENSSL}" ) && \
    gpg --batch --verify openssl.tar.gz.asc openssl.tar.gz && \
    tar xzf openssl.tar.gz && \
    cd "${VERSION_OPENSSL}" && \
    ./config \
        -Wl,-rpath=/opt/openssl/lib \
        --prefix=/opt/openssl \
        --openssldir=/opt/openssl \
        enable-ec_nistp_64_gcc_128 \
        -DOPENSSL_NO_HEARTBEATS \
        no-weak-ssl-ciphers \
        no-ssl2 \
        no-ssl3 \
        shared \
        -fstack-protector-strong && \
    make depend && \
    make && \
    make install_sw && \
    apt-get purge -y --auto-remove \
      $build_deps && \
    rm -rf \
        /tmp/* \
        /var/tmp/* \
        /var/lib/apt/lists/*

FROM debian:buster as stubby

ENV VERSION_GETDNS=v1.6.0

WORKDIR /tmp/src
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY --from=openssl /opt/openssl /opt/openssl

RUN set -e -x && \
    build_deps="autoconf build-essential check cmake dh-autoreconf git libssl-dev libyaml-dev make m4" && \
    debian_frontend=noninteractive apt-get update && apt-get install -y --no-install-recommends \
      ${build_deps} \
      ca-certificates \
      dns-root-data \
      libyaml-0-2 && \
    debian_frontend=noninteractive apt-get update && apt-get install -y --no-install-recommends check cmake && \
    git clone https://github.com/getdnsapi/getdns.git && \
    cd getdns && \
    git checkout "${VERSION_GETDNS}" && \
    git submodule update --init && \
    mkdir build && \
    cd build && \
    cmake \
        -DBUILD_STUBBY=ON \
        -DENABLE_STUB_ONLY=ON \
        -DCMAKE_INSTALL_PREFIX=/etc/stubby \
        -DOPENSSL_INCLUDE_DIR=/opt/openssl \
        -DOPENSSL_CRYPTO_LIBRARY=/opt/openssl/lib/libcrypto.so \
        -DOPENSSL_SSL_LIBRARY=/opt/openssl/lib/libssl.so \
        -DUSE_LIBIDN2=OFF \
        -DBUILD_LIBEV=OFF \
        -DBUILD_LIBEVENT2=OFF \
        -DBUILD_LIBUV=OFF ..&& \
    cmake .. && \
    make && \
    make install

FROM gcr.io/distroless/base-debian10:debug

COPY --from=openssl /opt/openssl /opt/openssl
COPY --from=stubby /etc/stubby /etc/stubby
COPY stubby.yml /etc/stubby/stubby.yml

ENV PATH /etc/stubby/:$PATH

RUN set -e -x && \
    debian_frontend=noninteractive apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      dns-root-data \
      ldnsutils \
      libyaml-0-2 && \
    groupadd -r stubby && \
    useradd --no-log-init -r -g stubby stubby && \
    rm -rf \
      /tmp/* \
      /var/tmp/* \
      /var/lib/apt/lists/*

WORKDIR /etc/stubby

EXPOSE 8053/udp

USER stubby:stubby

HEALTHCHECK --interval=5s --timeout=3s --start-period=5s CMD drill @127.0.0.1 -p 8053 cloudflare.com || exit 1

CMD ["/etc/stubby/"]