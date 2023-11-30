#!/bin/bash

# set -xe

# must be run with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo"
    exit 1
fi

# check if .env file exists
if [ ! -f .env ]; then
    echo ".env file not found"
    exit 1
fi

# variables section
export ROOT_DIR=$(pwd)
export SERVICES_ARRAY=(dashboard director minio records)
export SERVICES_BASENAME=$(grep -oP '(?<=^SERVICES_BASENAME=).*$' .env | tr -d "'")
export CA_BASENAME=$(grep -oP '(?<=^CA_BASENAME=).*$' .env | tr -d "'")
export COUNTRY=$(grep -oP '(?<=^COUNTRY=).*$' .env | tr -d "'")
export STATE=$(grep -oP '(?<=^STATE=).*$' .env | tr -d "'")
export LOCATION=$(grep -oP '(?<=^LOCATION=).*$' .env | tr -d "'")
export ORGANIZATION=$(grep -oP '(?<=^ORGANIZATION=).*$' .env | tr -d "'")
export ORGANIZATION_UNIT=$(grep -oP '(?<=^ORGANIZATION_UNIT=).*$' .env | tr -d "'")
export CA_DOMAIN=$(grep -oP '(?<=^CA_DOMAIN=).*$' .env | tr -d "'")
export DOMAIN_SUFFIX=$(grep -oP '(?<=^DOMAIN_SUFFIX=).*$' .env | tr -d "'")
export VMS_IPS=($(grep -oP '(?<=^VMS_IPS=).*$' .env | tr -d "'"))
export MINIO_ROOT_USER=$(grep -oP '(?<=^MINIO_ROOT_USER=).*$' .env | tr -d "'")
export MINIO_ROOT_PASSWORD=$(grep -oP '(?<=^MINIO_ROOT_PASSWORD=).*$' .env | tr -d "'")
export MINIO_BUCKET=$(grep -oP '(?<=^MINIO_BUCKET=).*$' .env | tr -d "'")
export MONGO_INITDB_ROOT_USERNAME=$(grep -oP '(?<=^MONGO_INITDB_ROOT_USERNAME=).*$' .env | tr -d "'")
export MONGO_INITDB_ROOT_PASSWORD=$(grep -oP '(?<=^MONGO_INITDB_ROOT_PASSWORD=).*$' .env | tr -d "'")
export MONGODB_DATABASE=$(grep -oP '(?<=^MONGODB_DATABASE=).*$' .env | tr -d "'")
export MINIO_ACCESS_KEY=$(grep -oP '(?<=^MINIO_ROOT_USER=).*$' .env | tr -d "'")
export MINIO_SECRET_KEY=$(grep -oP '(?<=^MINIO_ROOT_PASSWORD=).*$' .env | tr -d "'")
export CYPRESS_VM_IP=$(echo ${VMS_IPS[0]} | tr -d ")" | tr -d "(") # first element of VMS_IPS should be cypress vm ip
export MINIO_VM_IP=$(echo ${VMS_IPS[1]} | tr -d ")" | tr -d "(") # second element of VMS_IPS should be minio vm ip

# check if ca.crt exists in the current directory

if [ ! -f $ROOT_DIR/$CA_BASENAME.crt ]; then
    echo -e "\n${CA_BASENAME}.crt not found"

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

    echo -e "\nCreating certificate for ${SERVICE_FULLNAME}"
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

    # remove redundant files
    rm $SERVICE-config.cnf
    rm $SERVICE_CSR

    # export services' certs, keys, and domains as environment variables
    if [ "$SERVICE" = "dashboard" ]; then
        export DASHBOARD_CRT=$SERVICE_CRT
        export DASHBOARD_KEY=$SERVICE_KEY
        export DASHBOARD_SERVICE_DOMAIN=$SERVICE_DOMAIN
    elif [ "$SERVICE" = "director" ]; then
        export DIRECTOR_CRT=$SERVICE_CRT
        export DIRECTOR_KEY=$SERVICE_KEY
        export DIRECTOR_SERVICE_DOMAIN=$SERVICE_DOMAIN
    elif [ "$SERVICE" = "minio" ]; then
        export MINIO_CRT=$SERVICE_CRT
        export MINIO_KEY=$SERVICE_KEY
        export MINIO_SERVICE_DOMAIN=$SERVICE_DOMAIN
    elif [ "$SERVICE" = "records" ]; then
        export RECORDS_CRT=$SERVICE_CRT
        export RECORDS_KEY=$SERVICE_KEY
        export RECORDS_SERVICE_DOMAIN=$SERVICE_DOMAIN
    fi

done

# copy CA to each service directory
cp $CA_BASENAME.pem cypress-service/$CA_BASENAME.pem
cp $CA_BASENAME.pem minio-service/$CA_BASENAME.pem

cp $CA_BASENAME.crt cypress-service/$CA_BASENAME.crt
cp $CA_BASENAME.crt minio-service/$CA_BASENAME.crt

cp $CA_BASENAME.key cypress-service/$CA_BASENAME.key
cp $CA_BASENAME.key minio-service/$CA_BASENAME.key

# move service-specific certs and keys to each service directory
mv $DASHBOARD_CRT cypress-service/$DASHBOARD_CRT
mv $DASHBOARD_KEY cypress-service/$DASHBOARD_KEY

mv $DIRECTOR_CRT cypress-service/$DIRECTOR_CRT
mv $DIRECTOR_KEY cypress-service/$DIRECTOR_KEY

mv $MINIO_CRT minio-service/$MINIO_CRT
mv $MINIO_KEY minio-service/$MINIO_KEY

mv $RECORDS_CRT minio-service/$RECORDS_CRT
mv $RECORDS_KEY minio-service/$RECORDS_KEY

# create /etc/hosts entries from etc.hosts.template
envsubst < etc-hosts.template > etc-hosts.file

cp etc-hosts.file cypress-service/etc-hosts.file
cp etc-hosts.file minio-service/etc-hosts.file

# Create docker-compose files from templates
envsubst < cypress.docker-compose.template > cypress-service/docker-compose.yaml
envsubst < minio.docker-compose.template > minio-service/docker-compose.yaml

# Create nginx conf files from templates
envsubst '${DASHBOARD_CRT},${DASHBOARD_KEY},${DASHBOARD_SERVICE_DOMAIN},${DIRECTOR_CRT},${DIRECTOR_KEY},${DIRECTOR_SERVICE_DOMAIN}' < cypress.nginx.template > cypress-service/nginx.conf
envsubst '${MINIO_CRT},${MINIO_KEY},${MINIO_SERVICE_DOMAIN},${RECORDS_CRT},${RECORDS_KEY},${RECORDS_SERVICE_DOMAIN}' < minio.nginx.template > minio-service/nginx.conf

if [ $? -eq 0 ]; then
    echo -e "\nOpen source Cypress project initialized successfully!\n"

    echo "To start the Cypress project, add 'etc-hosts.file' entries to your local machine's /etc/hosts file, then"
    echo "Copy the service directories to their respective VMs using ssh (i.e. cypress-service/ to the cypress vm, and minio-service/ to the minio vm),"
    echo "Copy the etc.hosts file's entries to /etc/hosts on each VM,"
    echo "and run the following commands:"
    echo ""
    echo "cd <service-name>-service && docker-compose up -d --remove-orphans"

    exit 0
else
    echo -e "\nInit script failed.\n"
    exit 1
fi
