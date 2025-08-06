#!/bin/bash

# Проверка наличия аргументов
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <prometheus_ip> [<node_exporter_ip1> <node_exporter_ip2> ...] [--openvpn <openvpn_exporter_ip>] [--blackbox <blackbox_exporter_ip> <target_to_monitor>]"
    echo "Example: $0 192.168.1.100 192.168.1.101 --openvpn 192.168.1.102 --blackbox 192.168.1.103 192.168.1.102:1194"
    exit 1
fi

PROMETHEUS_IP="$1"
shift
NODE_EXPORTER_IPS=()
OPENVPN_EXPORTER_IP=""
BLACKBOX_EXPORTER_IP=""
BLACKBOX_TARGETS=()

# Парсинг аргументов
while [ "$#" -gt 0 ]; do
    case "$1" in
        --openvpn)
            OPENVPN_EXPORTER_IP="$2"
            shift 2
            ;;
        --blackbox)
            BLACKBOX_EXPORTER_IP="$2"
            BLACKBOX_TARGETS+=("$3")
            shift 3
            ;;
        *)
            NODE_EXPORTER_IPS+=("$1")
            shift
            ;;
    esac
done

# Установка Prometheus v3.5.0
echo "Installing Prometheus v3.5.0..."
wget https://github.com/prometheus/prometheus/releases/download/v3.5.0/prometheus-3.5.0.linux-amd64.tar.gz -O /tmp/prometheus.tar.gz
tar -xzf /tmp/prometheus.tar.gz -C /tmp

# Создаем директории с правильными правами
sudo mkdir -p /opt/prometheus
sudo chown -R $USER:$USER /opt/prometheus
mv /tmp/prometheus-3.5.0.linux-amd64/* /opt/prometheus/

# Генерация конфига prometheus.yml
echo "Configuring Prometheus..."
TMP_CONF=$(mktemp)
cat > "$TMP_CONF" <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: "node_exporter"
    static_configs:
      - targets: [$(printf "\"%s:9100\"," "${NODE_EXPORTER_IPS[@]}" | sed 's/,$//')]
EOF

# Добавляем OpenVPN-экспортер, если указан
if [ -n "$OPENVPN_EXPORTER_IP" ]; then
    cat >> "$TMP_CONF" <<EOF

  - job_name: "openvpn_exporter"
    static_configs:
      - targets: ["$OPENVPN_EXPORTER_IP:9176"]
EOF
fi

# Добавляем blackbox_exporter, если указан
if [ -n "$BLACKBOX_EXPORTER_IP" ]; then
    cat >> "$TMP_CONF" <<EOF

  - job_name: "blackbox"
    metrics_path: /probe
    params:
      module: [tcp_connect, icmp]
    static_configs:
      - targets:
$(printf "          - %s\n" "${BLACKBOX_TARGETS[@]}")
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: "$BLACKBOX_EXPORTER_IP:9115"
EOF
fi

# Копируем конфиг с правильными правами
sudo cp "$TMP_CONF" /opt/prometheus/prometheus.yml
sudo chown prometheus:prometheus /opt/prometheus/prometheus.yml
rm "$TMP_CONF"

# Проверка конфига
echo "Validating configuration..."
if ! /opt/prometheus/promtool check config /opt/prometheus/prometheus.yml; then
    echo "Error: Invalid Prometheus config!"
    exit 1
fi

# Создание systemd-юнита
TMP_SERVICE=$(mktemp)
cat > "$TMP_SERVICE" <<EOF
[Unit]
Description=Prometheus Server
After=network.target

[Service]
User=prometheus
ExecStart=/opt/prometheus/prometheus \\
    --config.file=/opt/prometheus/prometheus.yml \\
    --storage.tsdb.path=/opt/prometheus/data \\
    --web.listen-address=0.0.0.0:9090
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo cp "$TMP_SERVICE" /etc/systemd/system/prometheus.service
sudo chmod 644 /etc/systemd/system/prometheus.service
rm "$TMP_SERVICE"

# Настройка пользователя и прав
echo "Setting up permissions..."
sudo useradd --no-create-home --shell /bin/false prometheus 2>/dev/null || echo "User prometheus already exists, continuing..."
sudo chown -R prometheus:prometheus /opt/prometheus

# Запуск Prometheus
echo "Starting Prometheus..."
sudo systemctl daemon-reload
sudo systemctl enable --now prometheus

# Проверка статуса
echo "Checking Prometheus status..."
if ! sudo systemctl status prometheus --no-pager; then
    echo "Error starting Prometheus!"
    sudo journalctl -u prometheus -n 50 --no-pager
    exit 1
fi

# Вывод информации о конфигурации
echo -e "\nPrometheus v3.5.0 has been successfully configured!"
echo "===================================================="
echo "Node Exporters:    ${NODE_EXPORTER_IPS[*]}"
[ -n "$OPENVPN_EXPORTER_IP" ] && echo "OpenVPN Exporter:  $OPENVPN_EXPORTER_IP:9176"
[ -n "$BLACKBOX_EXPORTER_IP" ] && echo -e "Blackbox Exporter: $BLACKBOX_EXPORTER_IP:9115\nMonitoring targets:\n$(printf '  - %s\n' "${BLACKBOX_TARGETS[@]}")"
echo "Prometheus Web UI: http://$PROMETHEUS_IP:9090"
echo "===================================================="