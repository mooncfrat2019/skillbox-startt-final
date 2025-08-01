#!/bin/bash
# Скрипт для копирования сертификатов с CA на VPN-сервер
# Использует переменную окружения CA_IP для указания адреса CA-сервера

set -euo pipefail

# Проверяем, что CA_IP задан
if [[ -z "${CA_IP:-}" ]]; then
  echo "Ошибка: переменная CA_IP не установлена!" >&2
  exit 1
fi

# Параметры подключения
CA_USER="ubuntu"
CA_CERTS_PATH="/etc/pki/easy-rsa/pki"
LOCAL_OVPN_DIR="/etc/openvpn/server"

echo "Копируем сертификаты с CA-сервера ${CA_IP}..."

# Копируем файлы
scp -i ~/.ssh/id_rsa \
    "${CA_USER}@${CA_IP}:${CA_CERTS_PATH}/ca.crt" \
    "${CA_USER}@${CA_IP}:${CA_CERTS_PATH}/issued/vpn-server.crt" \
    "${CA_USER}@${CA_IP}:${CA_CERTS_PATH}/private/vpn-server.key" \
    "${LOCAL_OVPN_DIR}/"

# Настраиваем права
chmod 600 "${LOCAL_OVPN_DIR}/vpn-server.key"
chmod 644 "${LOCAL_OVPN_DIR}/"{ca.crt,vpn-server.crt}

echo "Сертификаты успешно скопированы в ${LOCAL_OVPN_DIR}"

# Запускаем OpenVPN (если установлен)
if systemctl is-active --quiet openvpn-server@server.service; then
  systemctl restart openvpn-server@server.service
else
  systemctl start openvpn-server@server.service
  systemctl enable openvpn-server@server.service
fi

echo "OpenVPN запущен и настроен!"