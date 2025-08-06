#!/bin/bash

# справка
show_help() {
  echo "Usage: $0 <admin-email> [options]"
  echo ""
  echo "Required:"
  echo "  <admin-email>    Email address for receiving alerts"
  echo ""
  echo "Options:"
  echo "  --smtp-from      Email sender address (default: alerts@prometheus.local)"
  echo "  --smtp-user      SMTP auth username (default: alerts@prometheus.local)"
  echo "  --smtp-pass      SMTP auth password"
  echo "  --smtp-host      SMTP server with port (default: smtp.gmail.com:587)"
  echo "  --smtp-tls       Enable TLS (true/false, default: true)"
  echo ""
  echo "Example:"
  echo "  $0 admin@example.com --smtp-from alerts@example.com --smtp-user alerts@example.com --smtp-pass 'password' --smtp-host 'smtp.mailprovider.com:465'"
  exit 1
}

# Проверка наличия обязательного аргумента
if [ $# -lt 1 ]; then
  show_help
fi

# Параметры по умолчанию
ADMIN_EMAIL="$1"
shift
SMTP_FROM="alerts@prometheus.local"
SMTP_USER="alerts@prometheus.local"
SMTP_PASS=""
SMTP_HOST="smtp.gmail.com:587"
SMTP_TLS="true"

# Разбор аргументов командной строки
while [ $# -gt 0 ]; do
  case "$1" in
    --smtp-from)
      SMTP_FROM="$2"
      shift 2
      ;;
    --smtp-user)
      SMTP_USER="$2"
      shift 2
      ;;
    --smtp-pass)
      SMTP_PASS="$2"
      shift 2
      ;;
    --smtp-host)
      SMTP_HOST="$2"
      shift 2
      ;;
    --smtp-tls)
      SMTP_TLS="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      ;;
  esac
done

# Проверка обязательных параметров
if [ -z "$ADMIN_EMAIL" ]; then
  echo "Error: Admin email is required!"
  show_help
fi

if [ -z "$SMTP_PASS" ]; then
  echo "Warning: SMTP password not provided. Email notifications may not work."
fi

# Пути к файлам конфигурации
ALERTS_FILE="/etc/prometheus/alerts.yml"
ALERTMANAGER_FILE="/etc/alertmanager/alertmanager.yml"

# Создаем директории
mkdir -p /etc/prometheus /etc/alertmanager

# 1. Создаем файл алертов (без изменений)
cat > $ALERTS_FILE <<'EOF'
groups:
- name: vm-alerts
  rules:
  - alert: HighCPU
    expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100 > 90
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High CPU usage on {{ $labels.instance }}"
      description: "CPU usage is {{ $value }}% for 5 minutes."

  - alert: HighMemory
    expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 90
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High memory usage on {{ $labels.instance }}"
      description: "Memory usage is {{ $value }}%."

  - alert: HighDiskUsage
    expr: (node_filesystem_size_bytes{mountpoint="/"} - node_filesystem_free_bytes{mountpoint="/"}) / node_filesystem_size_bytes{mountpoint="/"} * 100 > 85
    for: 30m
    labels:
      severity: warning
    annotations:
      summary: "High disk usage on {{ $labels.instance }}"
      description: "Root filesystem is {{ $value }}% full."

  - alert: HighNetworkConnections
    expr: node_netstat_Tcp_CurrEstab > 1000
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High TCP connections on {{ $labels.instance }}"
      description: "{{ $value }} active TCP connections."

  - alert: OpenVPNServiceDown
    expr: systemd_unit_state{name="openvpn.service",state="active"} != 1
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "OpenVPN service is down on {{ $labels.instance }}"
      description: "OpenVPN service is not running."

- name: openvpn-alerts
  rules:
  - alert: OpenVPNProcessDown
    expr: up{job="openvpn_exporter"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "OpenVPN exporter is down on {{ $labels.instance }}"
      description: "OpenVPN process or exporter is not running."

  - alert: OpenVPNPortDown
    expr: probe_success{job="blackbox", target=~".*:1194"} == 0
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "OpenVPN port 1194 is unreachable on {{ $labels.instance }}"
      description: "TCP probe failed for OpenVPN port."

  - alert: HighVPNPing
    expr: avg_over_time(probe_duration_seconds{job="blackbox", target=~"icmp://.*"}[5m]) > 0.5
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High ping latency to VPN server ({{ $value }}s)"
      description: "Average ping latency exceeds 500ms."

  - alert: HighVPNReconnects
    expr: increase(openvpn_client_reconnections_total[1h]) > 10
    for: 30m
    labels:
      severity: warning
    annotations:
      summary: "High OpenVPN reconnects on {{ $labels.instance }}"
      description: "{{ $value }} reconnects in the last hour."
EOF

# 2. Настраиваем Alertmanager с переданными параметрами
cat > $ALERTMANAGER_FILE <<EOF
global:
  smtp_smarthost: '$SMTP_HOST'
  smtp_from: '$SMTP_FROM'
  smtp_auth_username: '$SMTP_USER'
  smtp_auth_password: '$SMTP_PASS'
  smtp_require_tls: $SMTP_TLS

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 5m
  repeat_interval: 3h
  receiver: 'email-notifications'

receivers:
- name: 'email-notifications'
  email_configs:
  - to: '$ADMIN_EMAIL'
    send_resolved: true
EOF

# 3. Проверяем конфигурацию
if ! /usr/local/bin/promtool check rules $ALERTS_FILE; then
  echo "ERROR: Invalid alerts configuration"
  exit 1
fi

if ! /usr/local/bin/amtool check-config $ALERTMANAGER_FILE; then
  echo "ERROR: Invalid Alertmanager configuration"
  exit 1
fi

# 4. Обновляем конфиг Prometheus
if ! grep -q "rule_files:" /etc/prometheus/prometheus.yml; then
  echo -e "\nrule_files:\n  - '$ALERTS_FILE'" >> /etc/prometheus/prometheus.yml
fi

# 5. Перезапускаем сервисы
systemctl restart prometheus
systemctl restart alertmanager

# Выводим информацию о настройках
echo -e "\nConfiguration applied successfully!"
echo "====================================="
echo "Admin email:        $ADMIN_EMAIL"
echo "SMTP sender:        $SMTP_FROM"
echo "SMTP server:        $SMTP_HOST"
echo "SMTP username:      $SMTP_USER"
echo "SMTP TLS enabled:   $SMTP_TLS"
echo "Alerts file:        $ALERTS_FILE"
echo "Alertmanager config: $ALERTMANAGER_FILE"
echo "====================================="