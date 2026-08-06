#!/bin/bash

# Disk usage threshold
THRESHOLD=80

# Log file
LOGFILE="$HOME/disk_usage.log"

# Array to store partitions exceeding threshold
ALERTS=()

echo "========== Disk Usage Report ==========" | tee -a "$LOGFILE"
echo "Date: $(date)" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"

df -hP | tail -n +2 | while read FILESYSTEM SIZE USED AVAIL USEPERCENT MOUNT
do
    USAGE=${USEPERCENT%\%}

    if [ "$USAGE" -ge "$THRESHOLD" ]; then
        printf "%-20s %-8s %-8s %-8s %-6s %-20s ALERT\n" \
        "$FILESYSTEM" "$SIZE" "$USED" "$AVAIL" "$USEPERCENT" "$MOUNT" | tee -a "$LOGFILE"
    else
        printf "%-20s %-8s %-8s %-8s %-6s %-20s OK\n" \
        "$FILESYSTEM" "$SIZE" "$USED" "$AVAIL" "$USEPERCENT" "$MOUNT" | tee -a "$LOGFILE"
    fi
done

echo "" | tee -a "$LOGFILE"

echo "Partitions above ${THRESHOLD}% usage:" | tee -a "$LOGFILE"

while read FILESYSTEM SIZE USED AVAIL USEPERCENT MOUNT
do
    USAGE=${USEPERCENT%\%}
    if [ "$USAGE" -ge "$THRESHOLD" ]; then
        echo " - $FILESYSTEM mounted on $MOUNT ($USEPERCENT)" | tee -a "$LOGFILE"
    fi
done < <(df -hP | tail -n +2)

echo "" | tee -a "$LOGFILE"
