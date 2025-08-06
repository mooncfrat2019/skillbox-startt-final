#!/bin/bash

# Парсинг аргументов
IS_VPN_SERVER=false
INSTALL_BLACKBOX=false
VPN_IP=""
VPN_PORT="9176"  # Порт по умолчанию

while [ "$#" -gt 0 ]; do
    case "$1" in
        --vpn)
            IS_VPN_SERVER=true
            shift
            ;;
        --vpn-ip)
            VPN_IP="$2"
            shift 2
            ;;
        --vpn-port)
            VPN_PORT="$2"
            shift 2
            ;;
        --blackbox)
            INSTALL_BLACKBOX=true
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

# Проверка обязательных аргументов для VPN
if [ "$IS_VPN_SERVER" = true ] && [ -z "$VPN_IP" ]; then
    echo "Error: --vpn-ip must be specified when using --vpn!"
    exit 1
fi

# Установка node_exporter
install_node_exporter() {
    echo "Installing node_exporter..."
    wget https://github.com/prometheus/node_exporter/releases/download/v1.9.1/node_exporter-1.9.1.linux-amd64.tar.gz -O /tmp/node_exporter.tar.gz
    tar -xzf /tmp/node_exporter.tar.gz -C /tmp
    sudo mv /tmp/node_exporter-1.9.1.linux-amd64/node_exporter /usr/local/bin/
    sudo useradd --no-create-home --shell /bin/false node_exporter || echo "User node_exporter already exists"
    sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter

    # Создаем временный файл
    TMP_FILE=$(mktemp)
    cat > "$TMP_FILE" <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
ExecStart=/usr/local/bin/node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # Копируем с правами root
    sudo cp "$TMP_FILE" /etc/systemd/system/node_exporter.service
    sudo chmod 644 /etc/systemd/system/node_exporter.service
    rm "$TMP_FILE"

    sudo systemctl daemon-reload
    sudo systemctl enable --now node_exporter
    echo "node_exporter installed and started!"
    echo "Service status:"
    sudo systemctl status node_exporter --no-pager
}

# Установка openvpn_exporter
install_openvpn_exporter() {
    echo "Installing patrickjahns/openvpn_exporter for VPN server $VPN_IP:$VPN_PORT..."
    wget https://github.com/patrickjahns/openvpn_exporter/releases/download/v1.1.2/openvpn_exporter-linux-amd64 -O /tmp/openvpn_exporter
    sudo mv /tmp/openvpn_exporter /usr/local/bin/
    sudo chmod +x /usr/local/bin/openvpn_exporter
    sudo useradd --no-create-home --shell /bin/false openvpn_exporter || echo "User openvpn_exporter already exists"
    sudo chown openvpn_exporter:openvpn_exporter /usr/local/bin/openvpn_exporter

    # Создаем переменные окружения (правильный способ конфигурации для этого экспортера)
    TMP_FILE=$(mktemp)
    cat > "$TMP_FILE" <<EOF
[Unit]
Description=OpenVPN Exporter (patrickjahns)
After=network.target

[Service]
User=openvpn_exporter
ExecStart=/usr/local/bin/openvpn_exporter --web.address 0.0.0.0:$VPN_PORT --status-file /etc/openvpn/openvpn-status.log
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    sudo cp "$TMP_FILE" /etc/systemd/system/openvpn_exporter.service
    sudo chmod 644 /etc/systemd/system/openvpn_exporter.service
    rm "$TMP_FILE"

    sudo systemctl daemon-reload
    sudo systemctl enable --now openvpn_exporter
    
    echo "Service configuration:"
    echo "Status Path: /etc/openvpn/server/openvpn-status.log"
    echo "Server IP: $VPN_IP"
    echo "Server Port: $VPN_PORT"
    echo "Web Listen Port: $VPN_PORT"
    
    echo "Service status:"
    sudo systemctl status openvpn_exporter --no-pager
}

# Установка blackbox_exporter
install_blackbox_exporter() {
    echo "Installing blackbox_exporter..."
    
    # Скачиваем и распаковываем бинарник
    wget https://github.com/prometheus/blackbox_exporter/releases/download/v0.24.0/blackbox_exporter-0.24.0.linux-amd64.tar.gz -O /tmp/blackbox_exporter.tar.gz
    tar -xzf /tmp/blackbox_exporter.tar.gz -C /tmp
    sudo mv /tmp/blackbox_exporter-0.24.0.linux-amd64/blackbox_exporter /usr/local/bin/
    
    # Создаем пользователя
    sudo useradd --no-create-home --shell /bin/false blackbox_exporter || echo "User blackbox_exporter already exists"
    sudo chown blackbox_exporter:blackbox_exporter /usr/local/bin/blackbox_exporter

    # Создаем кастомный конфиг
    sudo mkdir -p /etc/blackbox_exporter
    sudo tee /etc/blackbox_exporter/config.yml > /dev/null <<'EOF'
modules:
  http_2xx:
    prober: http
    timeout: 5s
    http:
      valid_status_codes: [200]
      method: GET

  tcp_connect:
    prober: tcp
    timeout: 5s
    tcp:
      preferred_ip_protocol: "ip4"

  icmp:
    prober: icmp
    timeout: 5s
    icmp:
      preferred_ip_protocol: "ip4"
EOF

    # Создаем systemd unit файл
    sudo tee /etc/systemd/system/blackbox_exporter.service > /dev/null <<'EOF'
[Unit]
Description=Blackbox Exporter
After=network.target

[Service]
User=blackbox_exporter
ExecStart=/usr/local/bin/blackbox_exporter \
    --config.file=/etc/blackbox_exporter/config.yml \
    --web.listen-address=:9115
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # Устанавливаем права
    sudo chmod 644 /etc/blackbox_exporter/config.yml
    sudo chmod 644 /etc/systemd/system/blackbox_exporter.service

    # Перезагружаем и запускаем
    sudo systemctl daemon-reload
    sudo systemctl enable --now blackbox_exporter
    
    echo "blackbox_exporter installed and started (port 9115)!"
    echo "Custom config created at /etc/blackbox_exporter/config.yml"
    echo "Service status:"
    sudo systemctl status blackbox_exporter --no-pager
}

# Основная логика
install_node_exporter

if [ "$IS_VPN_SERVER" = true ]; then
    install_openvpn_exporter
fi

if [ "$INSTALL_BLACKBOX" = true ]; then
    install_blackbox_exporter
fi

echo "Exporters installation complete!"