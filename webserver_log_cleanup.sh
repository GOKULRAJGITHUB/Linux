#!/bin/bash

#####################################
# Configuration
#####################################

RETENTION_DAYS=30
LOGFILE="/var/log/webserver_cleanup.log"

# Directories
NGINX_LOG="/var/log/nginx"
APACHE_LOG="/var/log/apache2"

#####################################

echo "=============================================" | tee -a "$LOGFILE"
echo "Web Server Log Cleanup - $(date)" | tee -a "$LOGFILE"
echo "=============================================" | tee -a "$LOGFILE"

TOTAL_DELETED=0

cleanup_logs() {

    DIR=$1
    SERVER=$2

    if [ ! -d "$DIR" ]; then
        echo "$SERVER log directory not found: $DIR" | tee -a "$LOGFILE"
        return
    fi

    echo "" | tee -a "$LOGFILE"
    echo "Cleaning $SERVER logs..." | tee -a "$LOGFILE"

    COUNT=$(find "$DIR" -type f \
    \( \
        -name "*.log.[0-9]*" -o \
        -name "*.log.*.gz" -o \
        -name "*.gz" -o \
        -name "*.old" \
    \) \
    -mtime +"$RETENTION_DAYS" | wc -l)

    if [ "$COUNT" -eq 0 ]; then
        echo "No old logs found." | tee -a "$LOGFILE"
        return
    fi

    find "$DIR" -type f \
    \( \
        -name "*.log.[0-9]*" -o \
        -name "*.log.*.gz" -o \
        -name "*.gz" -o \
        -name "*.old" \
    \) \
    -mtime +"$RETENTION_DAYS" \
    -print -delete | tee -a "$LOGFILE"

    TOTAL_DELETED=$((TOTAL_DELETED+COUNT))

    echo "$COUNT files deleted." | tee -a "$LOGFILE"
}

cleanup_logs "$NGINX_LOG" "NGINX"
cleanup_logs "$APACHE_LOG" "APACHE"

echo "" | tee -a "$LOGFILE"
echo "=============================================" | tee -a "$LOGFILE"
echo "Cleanup Completed" | tee -a "$LOGFILE"
echo "Total Files Deleted : $TOTAL_DELETED" | tee -a "$LOGFILE"
echo "=============================================" | tee -a "$LOGFILE"
