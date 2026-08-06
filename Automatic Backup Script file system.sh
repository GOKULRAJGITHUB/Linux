#!/bin/bash

##############################################
# Automatic Web Backup Script
##############################################

# Source Directory
SOURCE_DIR="/var/www/html"

# Backup Directory
BACKUP_DIR="/backup/web"

# Log Directory
LOG_DIR="/backup/logs"

# Retention
BACKUP_RETENTION_DAYS=7
LOG_RETENTION_DAYS=30

# Date Format
DATE=$(date +"%Y-%m-%d_%H-%M-%S")

mkdir -p "$BACKUP_DIR"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/web_backup_$DATE.log"

log() {
    echo "[$(date '+%F %T')] $1" | tee -a "$LOG_FILE"
}

log "=========================================="
log "Backup Started"
log "Source Directory : $SOURCE_DIR"
log "Backup Directory : $BACKUP_DIR"
log "=========================================="

TOTAL=0
SUCCESS=0
FAILED=0

for DIR in "$SOURCE_DIR"/*; do

    if [ -d "$DIR" ]; then

        TOTAL=$((TOTAL+1))

        NAME=$(basename "$DIR")
        BACKUP_FILE="$BACKUP_DIR/${NAME}_${DATE}.tar.gz"

        log ""
        log "Backing up : $NAME"

        tar -czf "$BACKUP_FILE" "$DIR" >>"$LOG_FILE" 2>&1

        if [ $? -eq 0 ]; then

            SIZE=$(du -sh "$BACKUP_FILE" | awk '{print $1}')

            log "SUCCESS"
            log "Backup File : $BACKUP_FILE"
            log "Backup Size : $SIZE"

            SUCCESS=$((SUCCESS+1))

        else

            log "FAILED"

            FAILED=$((FAILED+1))

        fi
    fi

done

log ""
log "Removing Backup Files older than $BACKUP_RETENTION_DAYS days..."
find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +$BACKUP_RETENTION_DAYS -exec rm -f {} \;

log "Removing Log Files older than $LOG_RETENTION_DAYS days..."
find "$LOG_DIR" -type f -name "*.log" -mtime +$LOG_RETENTION_DAYS -exec rm -f {} \;

log ""
log "=========================================="
log "Backup Completed"
log "Directories Processed : $TOTAL"
log "Successful            : $SUCCESS"
log "Failed                : $FAILED"
log "Finished At           : $(date)"
log "=========================================="
