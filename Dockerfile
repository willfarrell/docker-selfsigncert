FROM alpine

RUN apk --update add bash openssl

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint

CMD ["docker-entrypoint"]

VOLUME /etc/ssl/private
VOLUME /etc/ssl/certs
