FROM debian:buster-slim

ARG DEBIAN_FRONTEND=noninteractive
ENV LOG_LEVEL 3

RUN apt update && \
    apt install -y --no-install-recommends ca-certificates stubby dnsutils

COPY stubby.yml /etc/stubby/

EXPOSE 53/tcp 53/udp

LABEL image="emre1393/stubby:latest"

HEALTHCHECK CMD dig +norecurse +retry=0 @127.0.0.1 cloudflare || exit 1

CMD ["/bin/sh", "-c", "/usr/bin/stubby -v $LOG_LEVEL -C /etc/stubby/stubby.yml"]