# Docker: Self-Signed Certificates
Container to easily inject self-signed certs into other docker containers via volumes

## Features
- Creates separate CA using RSA or ECDSA
- Creates certificates using RSA and ECDSA
- Saves certificate and keys in volumes
- Will only renew during specified time period
- Verifies certificates

## ENV
```bash
# See source code for full list
CA_ALG: RSA, ECDSA
CA_SIZE: 2048, 4096 for RSA and secp384r1, and others for ECDSA
CA_SUBJECT: Organization name
CA_EXPIRE: How many days till expire
CA_RENEW: How many days before expire to try to renew

SSL_ALG: See CA_ALG
SSL_SIZE: See CA_SIZE
SSL_EXPIRE: See CA_EXPIRE
SSL_RENEW: See CA_RENEW

SSL_SUBJECT: Primary domain to generate cert for
SSL_DNS: Secondary domains to add on the certificate
SSL_IP: Secondary IPs to add on the certificate
```

## Use

### docker cli
```bash
docker run \
    -e CA_SUBJECT="Farrell Labs Inc" \
    -e SSL_SUBJECT=app.example.com \
    willfarrell/selfsigncert
```

### docker-compose.yml
```yml
version: "3"

services:
  selfsigncert:
    image: willfarrell/selfsigncert
    environment:
      - CA_SUBJECT="Farrell Labs Inc"
      - SSL_SUBJECT=app.example.com
    volumes:
      - "tls_ca:/etc/ssl/ca"
      - "tls_certs:/etc/ssl/certs"

volumes:
  tls_ca:
  tls_certs:

```


## Credit:
https://github.com/paulczar/omgwtfssl
