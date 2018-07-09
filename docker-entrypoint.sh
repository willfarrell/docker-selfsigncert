#! /usr/bin/env bash


#export TMP_DIR=${TMP_DIR:-"/tmp"}

export CA_DIR=${CA_DIR:-"/etc/ssl/ca"}
export CA_KEY=${CA_KEY:-"key.pem"}
export CA_CERT=${CA_CERT:-"cert.pem"}
export CA_ALG=${CA_ALG:-"RSA"}        # ECDSA
export CA_SIZE=${CA_SIZE:-"2048"}     # secp384r1
export CA_SUBJECT=${CA_SUBJECT:-"Test CA"}
export CA_EXPIRE=${CA_EXPIRE:-"90"}
export CA_RENEW=${CA_RENEW:-"30"}

export SSL_DIR=${SSL_DIR:-"/etc/ssl/certs"}
export SSL_CONFIG=${SSL_CONFIG:-"openssl.cnf"}
export SSL_KEY=${SSL_KEY:-"key.pem"}
export SSL_CSR=${SSL_CSR:-"key.csr"}
export SSL_CERT=${SSL_CERT:-"cert.pem"}
export SSL_ALG=${SSL_ALG:-"RSA"}        # ECDSA
export SSL_SIZE=${SSL_SIZE:-"2048"}     # secp384r1
export SSL_EXPIRE=${SSL_EXPIRE:-"90"}
export SSL_RENEW=${SSL_RENEW:-"30"}

export SSL_SUBJECT=${SSL_SUBJECT:-"example.com"}
export SSL_DNS=${SSL_DNS}
export SSL_IP=${SSL_IP}

mkdir -p ${CA_DIR}
mkdir -p ${SSL_DIR}

# TODO build in tmp, on verify pass, move to proper folder

#rm ${CA_DIR}/${CA_CERT}
#rm ${SSL_DIR}/${SSL_SUBJECT}/${SSL_CERT}

if [ "${LOG}" == "TRUE" ]; then
    LOG_DIR=/var/log/selfsigncert
	LOG_FILE=${LOG_DIR}/runtime.log
	mkdir -p ${LOG_DIR}
	touch ${LOG_FILE}

	UUID=$(cat /proc/sys/kernel/random/uuid)
	exec > >(read message; echo "${UUID} $(date -Iseconds) [info] $message" | tee -a ${LOG_FILE} )
	exec 2> >(read message; echo "${UUID} $(date -Iseconds) [error] $message" | tee -a ${LOG_FILE} >&2)
fi

RENEW_CA=FALSE

if [[ -e ${CA_DIR}/${CA_KEY} ]]; then
    [[ -z $SILENT ]] && echo "====> Using existing CA Key ${CA_DIR}/${CA_KEY}"
else
    [[ -z $SILENT ]] && echo "====> Generating new CA Key ${CA_DIR}/${CA_KEY}"
    if [ "${CA_ALG}" == "RSA" ]; then
        openssl genrsa -out ${CA_DIR}/${CA_KEY} ${CA_SIZE} > /dev/null || exit 1
    elif [ "${CA_ALG}" == "ECDSA" ]; then
        openssl ecparam -genkey -name ${CA_SIZE} -out ${CA_DIR}/${CA_KEY} > /dev/null || exit 1
    else
        exit 1
    fi
fi

generate_ca_cert() {
    [[ -z $SILENT ]] && echo "====> Generating new CA Certificate ${CA_DIR}/${CA_CERT}"
    openssl req -x509 -new -nodes -key ${CA_DIR}/${CA_KEY} -days ${CA_EXPIRE} -out ${CA_DIR}/${CA_CERT} -subj "/CN=${CA_SUBJECT}" > /dev/null  || exit 1
    RENEW_CA=TRUE
}

if [[ -e ${CA_DIR}/${CA_CERT} ]]; then
    if [ "$(openssl x509 -checkend $((86400*${CA_RENEW})) -in ${CA_DIR}/${CA_CERT})" == "Certificate will expire" ]; then
        [[ -z $SILENT ]] && echo "====> CA Certificate expiring soon ${CA_DIR}/${CA_CERT}"
        generate_ca_cert
    else
        [[ -z $SILENT ]] && echo "====> Using existing CA Certificate ${CA_DIR}/${CA_CERT}"
    fi
else
    generate_ca_cert
fi

[[ -z $SILENT ]] && echo "====> Verify CA Certificate ${CA_DIR}/${CA_CERT}"
openssl verify -purpose sslclient -CAfile ${CA_DIR}/${CA_CERT} ${CA_DIR}/${CA_CERT} > /dev/null || exit 1

mkdir -p ${SSL_DIR}/${SSL_SUBJECT}

echo "====> Generating new config file ${SSL_DIR}/${SSL_SUBJECT}/${SSL_CONFIG}"
cat > ${SSL_DIR}/${SSL_SUBJECT}/${SSL_CONFIG} <<EOM
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, serverAuth
EOM

if [[ -n ${SSL_DNS} || -n ${SSL_IP} ]]; then
    cat >> ${SSL_DIR}/${SSL_SUBJECT}/${SSL_CONFIG} <<EOM
subjectAltName = @alt_names
[alt_names]
EOM

    IFS=","
    dns=(${SSL_DNS})
    dns+=(${SSL_SUBJECT})
    for i in "${!dns[@]}"; do
      echo DNS.$((i+1)) = ${dns[$i]} >> ${SSL_DIR}/${SSL_SUBJECT}/${SSL_CONFIG}
    done

    if [[ -n ${SSL_IP} ]]; then
        ip=(${SSL_IP})
        for i in "${!ip[@]}"; do
          echo IP.$((i+1)) = ${ip[$i]} >> ${SSL_DIR}/${SSL_SUBJECT}/${SSL_CONFIG}
        done
    fi
fi

if [[ -e ${SSL_DIR}/${SSL_SUBJECT}/${SSL_KEY} ]]; then
    [[ -z $SILENT ]] && echo "====> Using existing SSL Key ${SSL_DIR}/${SSL_SUBJECT}/${SSL_KEY}"
else
    [[ -z $SILENT ]] && echo "====> Generating new SSL KEY ${SSL_DIR}/${SSL_SUBJECT}/${SSL_KEY}"
    if [ "${SSL_ALG}" == "RSA" ]; then
        openssl genrsa -out ${SSL_DIR}/${SSL_SUBJECT}/${SSL_KEY} ${SSL_SIZE} > /dev/null || exit 1
    elif [ "${CA_ALG}" == "ECDSA" ]; then
        openssl ecparam -genkey -name ${SSL_SIZE} -out ${SSL_DIR}/${SSL_SUBJECT}/${SSL_KEY} > /dev/null || exit 1
    else
        exit 1
    fi
fi

if [[ -e ${SSL_DIR}/${SSL_SUBJECT}/${SSL_CSR} ]]; then
    [[ -z $SILENT ]] && echo "====> Using existing SSL CSR ${SSL_DIR}/${SSL_SUBJECT}/${SSL_CSR}"
else
    [[ -z $SILENT ]] && echo "====> Generating new SSL CSR ${SSL_DIR}/${SSL_SUBJECT}/${SSL_CSR}"
    openssl req -new -key ${SSL_DIR}/${SSL_SUBJECT}/${SSL_KEY} -out ${SSL_DIR}/${SSL_SUBJECT}/${SSL_CSR} -subj "/CN=${SSL_SUBJECT}" -config ${SSL_DIR}/${SSL_SUBJECT}/${SSL_CONFIG} > /dev/null || exit 1
fi

generate_ssl_cert() {
    [[ -z $SILENT ]] && echo "====> Generating new SSL CERT ${SSL_DIR}/${SSL_SUBJECT}/${SSL_CERT}"
    openssl x509 -req -in ${SSL_DIR}/${SSL_SUBJECT}/${SSL_CSR} -CA ${CA_DIR}/${CA_CERT} -CAkey ${CA_DIR}/${CA_KEY} -CAcreateserial -out ${SSL_DIR}/${SSL_SUBJECT}/${SSL_CERT} \
        -days ${SSL_EXPIRE} -extensions v3_req -extfile ${SSL_DIR}/${SSL_SUBJECT}/${SSL_CONFIG} > /dev/null || exit 1

    cp ${SSL_DIR}/${SSL_SUBJECT}/${SSL_CERT} ${SSL_DIR}/${SSL_SUBJECT}/chain.pem
    cp ${SSL_DIR}/${SSL_SUBJECT}/${SSL_CERT} ${SSL_DIR}/${SSL_SUBJECT}/fullchain.pem
}


if [[ -e ${SSL_DIR}/${SSL_SUBJECT}/${SSL_CERT} ]]; then
    if [ "${RENEW_CA}" == "TRUE" ]; then
        [[ -z $SILENT ]] && echo "====> CA Certificate expiring soon, Re-issue SSL Certificate ${SSL_DIR}/${SSL_SUBJECT}/${SSL_CERT}"
        generate_ssl_cert
    elif [ "$(openssl x509 -checkend $((86400*${SSL_RENEW})) -in ${SSL_DIR}/${SSL_SUBJECT}/${SSL_CERT})" == "Certificate will expire" ]; then
        [[ -z $SILENT ]] && echo "====> SSL Certificate expiring soon ${SSL_DIR}/${SSL_SUBJECT}/${SSL_CERT}"
        generate_ssl_cert
    else
        [[ -z $SILENT ]] && echo "====> Using existing SSL Certificate ${SSL_DIR}/${SSL_SUBJECT}/${SSL_CERT}"
    fi
else
    generate_ssl_cert
fi

[[ -z $SILENT ]] && echo "====> Verify SSL Certificate ${SSL_DIR}/${SSL_SUBJECT}/${SSL_CERT}"
openssl verify -purpose sslclient -CAfile ${CA_DIR}/${CA_CERT} ${SSL_DIR}/${SSL_SUBJECT}/${SSL_CERT} > /dev/null || exit 1
