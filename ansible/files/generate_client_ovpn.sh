#!/bin/bash
# Генерация клиентского .ovpn файла с tls-auth
# Использование: ./generate_client_ovpn.sh <client_name> <server_ip>

set -euo pipefail

CLIENT_NAME="$1"
SERVER_IP="${2:-192.168.1.100}"
OVPN_DIR="/etc/openvpn/clients"
EASYRSA_DIR="/etc/pki/easy-rsa"

# Проверка аргументов
if [[ -z "$CLIENT_NAME" ]]; then
  echo "Ошибка: укажите имя клиента" >&2
  exit 1
fi

# Создаём директорию для клиентов
mkdir -p "$OVPN_DIR"

# Генерируем tls-auth ключ (если не существует)
if [[ ! -f "$EASYRSA_DIR/ta.key" ]]; then
  openvpn --genkey --secret "$EASYRSA_DIR/ta.key"
fi

# Создаём конфиг
cat <<EOF > "$OVPN_DIR/$CLIENT_NAME.ovpn"
client
dev tun
proto udp
remote $SERVER_IP 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
auth SHA256
key-direction 1
verb 3
<ca>
$(cat "$EASYRSA_DIR/pki/ca.crt")
</ca>
<cert>
$(cat "$EASYRSA_DIR/pki/issued/$CLIENT_NAME.crt")
</cert>
<key>
$(cat "$EASYRSA_DIR/pki/private/$CLIENT_NAME.key")
</key>
<tls-auth>
$(cat "$EASYRSA_DIR/ta.key")
</tls-auth>
EOF

# Создаём архив
tar -czf "$OVPN_DIR/$CLIENT_NAME.tar.gz" -C "$OVPN_DIR" "$CLIENT_NAME.ovpn"

chmod 600 "$OVPN_DIR/$CLIENT_NAME.ovpn"
chmod 644 "$OVPN_DIR/$CLIENT_NAME.tar.gz"

echo "Конфиг создан: $OVPN_DIR/$CLIENT_NAME.ovpn"
echo "Архив для скачивания: $OVPN_DIR/$CLIENT_NAME.tar.gz"