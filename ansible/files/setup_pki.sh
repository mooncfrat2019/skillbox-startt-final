#!/bin/bash

# Переменные (будут переданы из Ansible)
EASYRSA_REQ_COUNTRY="${ca_country:-RU}"
EASYRSA_REQ_PROVINCE="${ca_state:-Moscow}"
EASYRSA_REQ_CITY="${ca_locality:-Moscow}"
EASYRSA_REQ_ORG="${ca_organization:-NEXUS VPN}"
EASYRSA_REQ_EMAIL="${ca_email:-zix@vk.com}"
EASYRSA_REQ_OU="${ca_ou:-IT}"
EASYRSA_CA_EXPIRE="${ca_days:-3650}"
EASYRSA_CERT_EXPIRE="${cert_days:-365}"

# Установка Easy-RSA
apt update
apt install -y easy-rsa

# Настройка PKI
mkdir -p ~/easy-rsa
ln -s /usr/share/easy-rsa/* ~/easy-rsa/
cd ~/easy-rsa
./easyrsa init-pki

# Конфигурация vars
cat <<EOF > ~/easy-rsa/vars
set_var EASYRSA_REQ_COUNTRY    "$EASYRSA_REQ_COUNTRY"
set_var EASYRSA_REQ_PROVINCE   "$EASYRSA_REQ_PROVINCE"
set_var EASYRSA_REQ_CITY       "$EASYRSA_REQ_CITY"
set_var EASYRSA_REQ_ORG        "$EASYRSA_REQ_ORG"
set_var EASYRSA_REQ_EMAIL      "$EASYRSA_REQ_EMAIL"
set_var EASYRSA_REQ_OU         "$EASYRSA_REQ_OU"
set_var EASYRSA_CA_EXPIRE      "$EASYRSA_CA_EXPIRE"
set_var EASYRSA_CERT_EXPIRE    "$EASYRSA_CERT_EXPIRE"
set_var EASYRSA_CRL_DAYS       "180"
set_var EASYRSA_DIGEST         "sha256"
set_var EASYRSA_KEY_SIZE       "2048"
EOF

# Генерация CA
./easyrsa build-ca nopass <<< "$EASYRSA_REQ_ORG CA"

# Перемещение файлов в /etc/pki
sudo mkdir -p /etc/pki
sudo cp -r ~/easy-rsa /etc/pki/