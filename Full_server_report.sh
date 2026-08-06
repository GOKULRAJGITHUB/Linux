#!/bin/bash

REPORT_DIR="/tmp/server_report"
REPORT_FILE="${REPORT_DIR}/server_report_$(hostname)_$(date +%F_%H-%M-%S).txt"

mkdir -p "$REPORT_DIR"

exec > >(tee "$REPORT_FILE") 2>&1

section() {
    echo
    echo "=================================================================="
    echo "$1"
    echo "=================================================================="
}

echo "SERVER REPORT"
echo "Generated : $(date)"
echo "Hostname  : $(hostname)"
echo "=================================================================="

section "SYSTEM INFORMATION"
hostnamectl 2>/dev/null
echo
cat /etc/os-release
echo
uname -a
echo
uptime

section "CPU INFORMATION"
lscpu

section "MEMORY INFORMATION"
free -h
echo
vmstat 1 3

section "DISK INFORMATION"
lsblk
echo
df -h
echo
df -i

section "MOUNTED FILESYSTEMS"
mount

section "NETWORK INFORMATION"
ip addr
echo
ip route
echo
ss -tulnp

section "DNS CONFIGURATION"
cat /etc/resolv.conf

section "RUNNING SERVICES"
systemctl list-units --type=service --state=running --no-pager

section "ENABLED SERVICES"
systemctl list-unit-files --state=enabled --no-pager

section "TOP CPU PROCESSES"
ps -eo pid,user,%cpu,%mem,cmd --sort=-%cpu | head -20

section "TOP MEMORY PROCESSES"
ps -eo pid,user,%cpu,%mem,cmd --sort=-%mem | head -20

section "WEB SERVER"

if command -v apache2 >/dev/null 2>&1; then
    echo "Apache Version"
    apache2 -v
    echo
    apachectl -S 2>/dev/null
fi

if command -v nginx >/dev/null 2>&1; then
    echo
    echo "Nginx Version"
    nginx -v 2>&1
fi

section "PHP"

if command -v php >/dev/null 2>&1; then
    php -v
    echo
    php -m
fi

section "MYSQL"

if command -v mysql >/dev/null 2>&1; then
    mysql --version
    echo
    mysql -e "SHOW DATABASES;" 2>/dev/null || echo "Unable to fetch database list."
fi

section "DOCKER"

if command -v docker >/dev/null 2>&1; then
    docker ps -a
    echo
    docker images
fi

section "CRON JOBS"

echo "Root Cron"
crontab -l 2>/dev/null

echo
echo "System Cron"
ls -l /etc/cron* 2>/dev/null

section "USERS"

who
echo
last | head -20

section "FIREWALL"

ufw status verbose 2>/dev/null || true
echo
iptables -L -n -v 2>/dev/null || true

section "SSL CERTIFICATES"

if command -v certbot >/dev/null 2>&1; then
    certbot certificates 2>/dev/null
fi

section "DISK USAGE"

du -sh /var/www/* 2>/dev/null

section "RECENT SYSTEM LOG"

journalctl -n 100 --no-pager 2>/dev/null

section "RECENT APACHE ERROR LOG"

tail -100 /var/log/apache2/error.log 2>/dev/null

section "RECENT NGINX ERROR LOG"

tail -100 /var/log/nginx/error.log 2>/dev/null

section "INSTALLED KERNELS"

dpkg -l | grep linux-image

section "SYSTEM TIMERS"

systemctl list-timers --all --no-pager

section "NETWORK CONNECTIONS"

ss -an

section "OPEN PORTS"

ss -tuln

section "INSTALLED PACKAGES"

dpkg -l

echo
echo "=================================================================="
echo "REPORT GENERATED SUCCESSFULLY"
echo "Location : $REPORT_FILE"
echo "=================================================================="
