#!/bin/bash

# set -xe

# variables section
ROOT_DIR=$(pwd)
SERVICES_ARRAY=(dashboard director minio records)
SERVICES_BASENAME='cypress'
CA_BASENAME='demo'
COUNTRY='PL'
STATE='Warsaw'
LOCATION='Warsaw'
ORGANIZATION='Develeap'
ORGANIZATION_UNIT='Demo Unit'
CA_DOMAIN='develeap.com'
DOMAIN_SUFFIX='.local'

# check if ca.crt exists in the current directory

if [ ! -f $ROOT_DIR/$CA_BASENAME.crt ]; then
    echo "${CA_BASENAME}.crt not found"

    # create CA key and CA crt
    echo "Creating ${CA_BASENAME}.crt"
    openssl req -new -x509 -days 365 -nodes -out $CA_BASENAME.crt -keyout $CA_BASENAME.key -subj "/C=${COUNTRY}/ST=${STATE}/L=${LOCATION}/O=${ORGANIZATION}/OU={ORGANIZATION_UNIT}/CN=${CA_DOMAIN}"
fi

# create certificates for each service
for SERVICE in "${SERVICES_ARRAY[@]}"; do
    SERVICE_FULLNAME="${SERVICE}-${SERVICES_BASENAME}"
    SERVICE_DOMAIN="${SERVICE}${DOMAIN_SUFFIX}"
    SERVICE_KEY="${SERVICE_FULLNAME}.key"
    SERVICE_CSR="${SERVICE_FULLNAME}.csr"
    SERVICE_CRT="${SERVICE_FULLNAME}.crt"

    cat > ${SERVICE}-config.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = req_ext

[req_distinguished_name]
commonName = ${SERVICE_DOMAIN}

[req_ext]
subjectAltName = DNS:${SERVICE_DOMAIN}
EOF

    echo "Creating certificate for ${SERVICE_FULLNAME}"
    echo "Domain: ${SERVICE_DOMAIN}"

    # create key
    echo "Creating key: ${SERVICE_KEY}"
    openssl genrsa -out $SERVICE_KEY 2048

    # create csr
    echo "Creating csr: ${SERVICE_CSR}"
    openssl req -new -key $SERVICE_KEY -out $SERVICE_CSR -subj "/C=${COUNTRY}/ST=${STATE}/L=${LOCATION}/O=${ORGANIZATION}/OU=${ORGANIZATION_UNIT}/CN=${SERVICE_DOMAIN}"

    # create crt
    echo "Creating crt: ${SERVICE_CRT}"
    openssl x509 -req -in $SERVICE_CSR -CA $CA_BASENAME.crt -CAkey $CA_BASENAME.key -CAcreateserial -out $SERVICE_CRT -days 365 -sha256 -extfile ${SERVICE}-config.cnf

# check if SERVICE is equal to dashboard or director
if [ "$SERVICE" = "dashboard" ] || [ "$SERVICE" = "director" ]; then
    mv $SERVICE_KEY cypress-service/$SERVICE_KEY
    mv $SERVICE_CRT cypress-service/$SERVICE_CRT
elif [ "$SERVICE" = "minio" ] || [ "$SERVICE" = "records" ]; then
    mv $SERVICE_KEY minio-service/$SERVICE_KEY
    mv $SERVICE_CRT minio-service/$SERVICE_CRT
fi

rm $SERVICE-config.cnf
rm $SERVICE_CSR

done

# copy CA to each service directory
cp $CA_BASENAME.crt cypress-service/$CA_BASENAME.crt
cp $CA_BASENAME.crt minio-service/$CA_BASENAME.crt

cp $CA_BASENAME.key cypress-service/$CA_BASENAME.key
cp $CA_BASENAME.key minio-service/$CA_BASENAME.key

exit 0
