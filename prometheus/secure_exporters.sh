#!/bin/bash

# Проверка наличия аргумента
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <PROMETHEUS_IP>"
    exit 1
fi

PROMETHEUS_IP="$1"

# Порты для защиты
PORTS=("9100" "9176" "9115")  # node_exporter, openvpn_exporter, blackbox_exporter

# Очистка старых правил
for port in "${PORTS[@]}"; do
    sudo iptables -D INPUT -p tcp --dport "$port" -j DROP 2>/dev/null || true
done

# Добавление новых правил
for port in "${PORTS[@]}"; do
    sudo iptables -A INPUT -p tcp --dport "$port" -s "$PROMETHEUS_IP" -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport "$port" -j DROP
done

# Сохраняем правила
if command -v netfilter-persistent &>/dev/null; then
    sudo netfilter-persistent save
elif command -v iptables-save &>/dev/null; then
    sudo iptables-save | sudo tee /etc/iptables/rules.v4 >/dev/null
fi

echo "Firewall rules updated:"
for port in "${PORTS[@]}"; do
    echo " - Port $port allowed only for $PROMETHEUS_IP"
done