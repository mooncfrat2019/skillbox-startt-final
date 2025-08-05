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

# Установка node_exporter (без изменений)
install_node_exporter() {
    echo "Installing node_exporter..."
    wget https://github.com/prometheus/node_exporter/releases/download/v1.7.1/node_exporter-1.7.1.linux-amd64.tar.gz -O /tmp/node_exporter.tar.gz
    tar -xzf /tmp/node_exporter.tar.gz -C /tmp
    sudo mv /tmp/node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/
    sudo useradd --no-create-home --shell /bin/false node_exporter
    sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter

    cat > /etc/systemd/system/node_exporter.service <<EOF
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

    sudo systemctl daemon-reload
    sudo systemctl enable --now node_exporter
    echo "node_exporter installed and started!"
}

# Установка openvpn_exporter (с указанием IP и порта)
install_openvpn_exporter() {
    echo "Installing patrickjahns/openvpn_exporter for VPN server $VPN_IP:$VPN_PORT..."
    wget https://github.com/patrickjahns/openvpn_exporter/releases/download/v1.1.2/openvpn_exporter-linux-amd64 -O /tmp/openvpn_exporter
    sudo mv /tmp/openvpn_exporter /usr/local/bin/
    sudo chmod +x /usr/local/bin/openvpn_exporter
    sudo useradd --no-create-home --shell /bin/false openvpn_exporter
    sudo chown openvpn_exporter:openvpn_exporter /usr/local/bin/openvpn_exporter

    # Конфиг с переданным IP и портом
    sudo mkdir -p /etc/openvpn_exporter
    cat > /etc/openvpn_exporter/config.yaml <<EOF
openvpn:
  status_path: "/etc/openvpn/server/openvpn-status.log"
  server_ip: "$VPN_IP"
  server_port: "$VPN_PORT"  # Опционально, если используется нестандартный порт
EOF

    # Systemd-юнит с указанием порта метрик
    cat > /etc/systemd/system/openvpn_exporter.service <<EOF
[Unit]
Description=OpenVPN Exporter (patrickjahns)
After=network.target

[Service]
User=openvpn_exporter
ExecStart=/usr/local/bin/openvpn_exporter \
    --config.file=/etc/openvpn_exporter/config.yaml \
    --web.listen-address=:$VPN_PORT
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable --now openvpn_exporter
    echo "openvpn_exporter (v1.1.2) installed and started on port $VPN_PORT!"
}

# Установка blackbox_exporter (без изменений)
install_blackbox_exporter() {
    echo "Installing blackbox_exporter..."
    wget https://github.com/prometheus/blackbox_exporter/releases/download/v0.24.0/blackbox_exporter-0.24.0.linux-amd64.tar.gz -O /tmp/blackbox_exporter.tar.gz
    tar -xzf /tmp/blackbox_exporter.tar.gz -C /tmp
    sudo mv /tmp/blackbox_exporter-0.24.0.linux-amd64/blackbox_exporter /usr/local/bin/
    sudo mkdir -p /etc/blackbox_exporter
    sudo wget https://raw.githubusercontent.com/prometheus/blackbox_exporter/main/blackbox.yml -O /etc/blackbox_exporter/config.yml
    sudo useradd --no-create-home --shell /bin/false blackbox_exporter
    sudo chown blackbox_exporter:blackbox_exporter /usr/local/bin/blackbox_exporter

    cat > /etc/systemd/system/blackbox_exporter.service <<EOF
[Unit]
Description=Blackbox Exporter
After=network.target

[Service]
User=blackbox_exporter
ExecStart=/usr/local/bin/blackbox_exporter --config.file=/etc/blackbox_exporter/config.yml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable --now blackbox_exporter
    echo "blackbox_exporter installed and started (port 9115)!"
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