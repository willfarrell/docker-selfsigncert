FROM alpine:3.8

RUN apk --no-cache --update add bash openssl && \
    mkdir -p /etc/ssl/ca

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint

CMD ["docker-entrypoint"]

VOLUME /etc/ssl/ca
VOLUME /etc/ssl/certs
