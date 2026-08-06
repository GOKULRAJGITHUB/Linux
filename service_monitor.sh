#!/bin/bash
#
# Service Monitoring Script
# Author: ChatGPT
# Description:
#   - Automatically discovers installed services.
#   - Ignores services that do not exist.
#   - Reports Active/Inactive/Failed status.
#   - Shows Node.js, PM2, React (Node process), Docker, MongoDB, Redis, Exporters, etc.
#   - Saves a log report.
#

LOG_DIR="/var/log/service_monitor"
mkdir -p "$LOG_DIR"

REPORT="$LOG_DIR/service_report_$(hostname)_$(date +%F_%H-%M-%S).log"

exec > >(tee "$REPORT") 2>&1

echo "=================================================================="
echo "                 SERVER SERVICE MONITORING REPORT"
echo "=================================================================="
echo "Hostname      : $(hostname)"
echo "Date          : $(date)"
echo "OS            : $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')"
echo "Kernel        : $(uname -r)"
echo "=================================================================="
echo

########################################################################
# Common services to check
########################################################################

SERVICES=(
apache2
nginx

mysql
mariadb
mongod
postgresql
redis-server

php8.4-fpm
php8.3-fpm
php8.2-fpm
php8.1-fpm
php8.0-fpm
php-fpm

docker
containerd
podman

ssh
cron
rsyslog
systemd-timesyncd

fail2ban
ufw

node_exporter
mysqld_exporter
blackbox_exporter
grafana-server
prometheus
alertmanager

rabbitmq-server
memcached
elasticsearch
opensearch

jenkins
gitlab-runner

tomcat
tomcat9
tomcat10

bind9
named

vsftpd
proftpd

haproxy
varnish
)

########################################################################

printf "%-30s %-12s\n" "SERVICE" "STATUS"
printf "%-30s %-12s\n" "------------------------------" "------------"

for svc in "${SERVICES[@]}"
do
    if systemctl list-unit-files --type=service --no-legend 2>/dev/null | awk '{print $1}' | grep -qx "${svc}.service"; then
        STATUS=$(systemctl is-active "$svc" 2>/dev/null)
        printf "%-30s %-12s\n" "$svc" "$STATUS"
    fi
done

echo
echo "=================================================================="
echo "DISCOVERED CUSTOM SERVICES"
echo "=================================================================="

systemctl list-unit-files --type=service --no-legend | \
awk '{print $1}' | \
grep -Ev '^(getty|systemd|dbus|snap|apt|console|proc|dev|sys|network|polkit|packagekit|bluetooth|keyboard|cups|ModemManager|accounts-daemon)' | \
sort

echo
echo "=================================================================="
echo "NODE.JS PROCESSES"
echo "=================================================================="

if command -v node >/dev/null 2>&1; then
    NODE_VERSION=$(node -v)
    echo "Node Version : $NODE_VERSION"
    echo

    ps -eo pid,user,%cpu,%mem,cmd | grep node | grep -v grep
else
    echo "Node.js Not Installed"
fi

echo
echo "=================================================================="
echo "PM2"
echo "=================================================================="

if command -v pm2 >/dev/null 2>&1; then
    pm2 list
else
    echo "PM2 Not Installed"
fi

echo
echo "=================================================================="
echo "DOCKER"
echo "=================================================================="

if command -v docker >/dev/null 2>&1; then
    docker ps
else
    echo "Docker Not Installed"
fi

echo
echo "=================================================================="
echo "MONGODB"
echo "=================================================================="

if command -v mongod >/dev/null 2>&1; then
    mongod --version | head -1
fi

echo
echo "=================================================================="
echo "REDIS"
echo "=================================================================="

if command -v redis-server >/dev/null 2>&1; then
    redis-server --version
fi

echo
echo "=================================================================="
echo "PHP"
echo "=================================================================="

if command -v php >/dev/null 2>&1; then
    php -v | head -1
fi

echo
echo "=================================================================="
echo "WEB SERVERS"
echo "=================================================================="

if command -v apache2 >/dev/null 2>&1; then
    apache2 -v | head -2
fi

if command -v nginx >/dev/null 2>&1; then
    nginx -v 2>&1
fi

echo
echo "=================================================================="
echo "DATABASES"
echo "=================================================================="

if command -v mysql >/dev/null 2>&1; then
    mysql --version
fi

if command -v psql >/dev/null 2>&1; then
    psql --version
fi

echo
echo "=================================================================="
echo "RESOURCE USAGE"
echo "=================================================================="

echo
echo "CPU Load"
uptime

echo
echo "Memory"
free -h

echo
echo "Disk"
df -h

echo
echo "Inodes"
df -i

echo
echo "=================================================================="
echo "LISTENING PORTS"
echo "=================================================================="

ss -tulnp

echo
echo "=================================================================="
echo "TOP CPU PROCESSES"
echo "=================================================================="

ps -eo pid,user,%cpu,%mem,cmd --sort=-%cpu | head -15

echo
echo "=================================================================="
echo "TOP MEMORY PROCESSES"
echo "=================================================================="

ps -eo pid,user,%cpu,%mem,cmd --sort=-%mem | head -15

echo
echo "=================================================================="
echo "REPORT LOCATION"
echo "=================================================================="

echo "$REPORT"

echo
echo "Completed Successfully."
