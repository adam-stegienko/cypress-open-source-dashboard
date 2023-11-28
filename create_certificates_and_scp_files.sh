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
VMS_IPS=(192.168.1.43 192.168.1.42)
VM_NAMES=(minio cypress)

# must be run with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo"
    exit 1
fi

# check if ca.crt exists in the current directory

if [ ! -f $ROOT_DIR/$CA_BASENAME.crt ]; then
    echo "${CA_BASENAME}.crt not found"

    # create CA key and CA crt
    echo "Creating ${CA_BASENAME}.crt"
    openssl req -new -x509 -days 365 -nodes -out $CA_BASENAME.crt -keyout $CA_BASENAME.key -subj "/C=${COUNTRY}/ST=${STATE}/L=${LOCATION}/O=${ORGANIZATION}/OU={ORGANIZATION_UNIT}/CN=${CA_DOMAIN}"
fi

cp $CA_BASENAME.crt /usr/local/share/ca-certificates/$CA_BASENAME.crt
cp $CA_BASENAME.crt /etc/ssl/certs/$CA_BASENAME.crt
cp $CA_BASENAME.key /etc/ssl/private/$CA_BASENAME.key
update-ca-certificates

cp /etc/ssl/certs/$CA_BASENAME.pem $ROOT_DIR/$CA_BASENAME.pem

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
cp $CA_BASENAME.pem cypress-service/$CA_BASENAME.pem
cp $CA_BASENAME.pem minio-service/$CA_BASENAME.pem

cp $CA_BASENAME.crt cypress-service/$CA_BASENAME.crt
cp $CA_BASENAME.crt minio-service/$CA_BASENAME.crt

cp $CA_BASENAME.key cypress-service/$CA_BASENAME.key
cp $CA_BASENAME.key minio-service/$CA_BASENAME.key

# scp files to each vm
sudo apt update
sudo apt install sshpass -y

options="-o StrictHostKeyChecking=no"
for VM in "${VM_NAMES[@]}"; do
    password="${VM}"
    sshpass -p $password scp $options -r ${ROOT_DIR}/${VM}-service ${VM}@${VM}.local:/home/${VM}/
    sshpass -p $password ssh $options ${VM}@${VM}.local sudo -S cp /home/${VM}/${VM}-service/${CA_BASENAME}.crt /etc/ssl/certs/${CA_BASENAME}.crt
    sshpass -p $password ssh $options ${VM}@${VM}.local sudo -S cp /home/${VM}/${VM}-service/${CA_BASENAME}.crt /usr/local/share/ca-certificates/${CA_BASENAME}.crt
    sshpass -p $password ssh $options ${VM}@${VM}.local sudo -S update-ca-certificates
done

exit 0
