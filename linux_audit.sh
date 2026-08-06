#!/bin/bash

REPORT="linux_audit_$(date +%F_%H-%M-%S).txt"

exec > >(tee "$REPORT") 2>&1

echo "========================================"
echo "        Linux System Audit Report"
echo "========================================"

echo
echo "Date: $(date)"
echo "Hostname: $(hostname)"
echo "User: $(whoami)"

echo
echo "========================================"
echo "OS INFORMATION"
echo "========================================"
cat /etc/os-release

echo
echo "Kernel Version"
uname -r

echo
echo "Architecture"
uname -m

echo
echo "========================================"
echo "NETWORK"
echo "========================================"

echo "Hostname:"
hostname

echo
echo "IP Address:"
hostname -I

echo
echo "Public IP:"
curl -s ifconfig.me

echo
echo "========================================"
echo "CPU INFORMATION"
echo "========================================"

lscpu

echo
echo "========================================"
echo "MEMORY"
echo "========================================"

free -h

echo
echo "========================================"
echo "DISK USAGE"
echo "========================================"

df -h

echo
echo "========================================"
echo "INODE USAGE"
echo "========================================"

df -i

echo
echo "========================================"
echo "UPTIME"
echo "========================================"

uptime

echo
echo "========================================"
echo "LOGGED-IN USERS"
echo "========================================"

who

echo
echo "========================================"
echo "LAST LOGIN"
echo "========================================"

last | head

echo
echo "========================================"
echo "FAILED LOGIN ATTEMPTS"
echo "========================================"

lastb 2>/dev/null | head

echo
echo "========================================"
echo "TOP 10 CPU PROCESSES"
echo "========================================"

ps -eo pid,user,%cpu,%mem,cmd --sort=-%cpu | head -11

echo
echo "========================================"
echo "TOP 10 MEMORY PROCESSES"
echo "========================================"

ps -eo pid,user,%cpu,%mem,cmd --sort=-%mem | head -11

echo
echo "========================================"
echo "OPEN PORTS"
echo "========================================"

ss -tulnp

echo
echo "========================================"
echo "RUNNING SERVICES"
echo "========================================"

systemctl list-units --type=service --state=running

echo
echo "========================================"
echo "FIREWALL STATUS"
echo "========================================"

if command -v ufw >/dev/null; then
    ufw status
else
    echo "UFW not installed"
fi

echo
echo "========================================"
echo "DOCKER"
echo "========================================"

if command -v docker >/dev/null; then
    systemctl is-active docker
    docker ps
else
    echo "Docker not installed"
fi

echo
echo "========================================"
echo "DISK ALERT"
echo "========================================"

THRESHOLD=80

df -hP | tail -n +2 | while read FS SIZE USED AVAIL USEP MOUNT
do
    USAGE=${USEP%\%}

    if [ "$USAGE" -ge "$THRESHOLD" ]; then
        echo "WARNING: $MOUNT is ${USEP} full."
    fi
done

echo
echo "========================================"
echo "AUDIT COMPLETED"
echo "========================================"
echo
echo "Report saved as: $REPORT"
