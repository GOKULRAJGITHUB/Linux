#!/bin/bash
####################################################################
# MySQL Backup Script with Detailed Logging
# Author: Gokul | eNova Software and Hardware Solutions Pvt. Ltd.
####################################################################

CONFIG="/opt/mysql-backup/backup.conf"

if [ ! -f "$CONFIG" ]; then
    echo "[$(date '+%F %T')] [ERROR] Configuration file missing at $CONFIG"
    exit 1
fi

source "$CONFIG"

DATE=$(date +"%Y-%m-%d_%H-%M-%S")
HOST=$(hostname)
SCRIPT_PID=$$

mkdir -p "$BACKUP_DIR"
mkdir -p "$LOG_DIR"
mkdir -p "$LOG_DIR/archive"

LOGFILE="$LOG_DIR/mysql_backup_${DATE}.log"
BACKUP_FILE="$BACKUP_DIR/mysql_backup_${DATE}.sql.gz"

START_TIME=$(date +%s)

####################################################################
# Logging Functions (level tagged, PID + line-numbered)
####################################################################

log(){
    echo "[$(date '+%F %T')] [INFO]  [PID:$SCRIPT_PID] $1" | tee -a "$LOGFILE"
}

warn(){
    echo "[$(date '+%F %T')] [WARN]  [PID:$SCRIPT_PID] $1" | tee -a "$LOGFILE"
}

error(){
    echo "[$(date '+%F %T')] [ERROR] [PID:$SCRIPT_PID] $1" | tee -a "$LOGFILE"
}

debug(){
    if [ "$DEBUG" = true ]; then
        echo "[$(date '+%F %T')] [DEBUG] [PID:$SCRIPT_PID] $1" | tee -a "$LOGFILE"
    fi
}

section(){
    log "----------------------------------------------------------"
    log "$1"
    log "----------------------------------------------------------"
}

####################################################################
# Trap: capture unexpected exits and always log final status
####################################################################

trap 'error "Script terminated unexpectedly (line $LINENO). Exit code: $?"; finalize 1' ERR
trap 'warn "Script interrupted by signal (SIGINT/SIGTERM)"; finalize 130' SIGINT SIGTERM

finalize(){
    local exit_code=$1
    END_TIME=$(date +%s)
    TOTAL_TIME=$((END_TIME-START_TIME))
    log "Total Execution Time : ${TOTAL_TIME}s"
    log "Exit Code            : $exit_code"
    log "============================================================"
    exit "$exit_code"
}

####################################################################
# Header
####################################################################

log "============================================================"
log "MySQL Backup Started"
log "Hostname     : $HOST"
log "Script PID   : $SCRIPT_PID"
log "Backup File  : $BACKUP_FILE"
log "Log File     : $LOGFILE"
log "Retention    : ${RETENTION_DAYS} days"
log "============================================================"

####################################################################
# Pre-flight Checks
####################################################################

section "PRE-FLIGHT CHECKS"

log "Checking disk space on backup volume..."
DISK_AVAIL=$(df -Pk "$BACKUP_DIR" | awk 'NR==2 {print $4}')
DISK_AVAIL_HUMAN=$(df -h "$BACKUP_DIR" | awk 'NR==2 {print $4}')
log "Available Space : $DISK_AVAIL_HUMAN"

if [ "$DISK_AVAIL" -lt 1048576 ]; then
    warn "Less than 1GB free space available on backup volume."
fi

log "Checking mysqldump binary..."
command -v mysqldump >/dev/null 2>&1
if [ $? -ne 0 ]; then
    error "mysqldump command not found. Aborting."
    finalize 1
fi
MYSQLDUMP_VERSION=$(mysqldump --version)
log "mysqldump found: $MYSQLDUMP_VERSION"

log "Checking gzip binary..."
command -v gzip >/dev/null 2>&1
if [ $? -ne 0 ]; then
    error "gzip command not found. Aborting."
    finalize 1
fi

log "Checking MySQL connectivity..."
MYSQL_ERROR=$(mysqladmin -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" ping 2>&1)
if [ $? -ne 0 ]; then
    error "MySQL Connection Failed"
    error "$MYSQL_ERROR"
    finalize 1
fi
log "MySQL Connection Successful."

MYSQL_VERSION=$(mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -N -e "SELECT VERSION();" 2>>"$LOGFILE")
log "MySQL Server Version: $MYSQL_VERSION"

DB_COUNT=$(mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -N -e "SHOW DATABASES;" 2>>"$LOGFILE" | grep -Ev "^(information_schema|performance_schema|sys)$" | wc -l)
DB_LIST=$(mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -N -e "SHOW DATABASES;" 2>>"$LOGFILE" | grep -Ev "^(information_schema|performance_schema|sys)$" | tr '\n' ',' | sed 's/,$//')
log "Databases to be backed up (${DB_COUNT}): $DB_LIST"

####################################################################
# Backup
####################################################################

section "BACKUP IN PROGRESS"

log "Starting mysqldump (--all-databases, single-transaction, routines, events, triggers)..."
DUMP_START=$(date +%s)

mysqldump \
    -u"$MYSQL_USER" \
    -p"$MYSQL_PASSWORD" \
    --all-databases \
    --single-transaction \
    --quick \
    --routines \
    --events \
    --triggers \
    --hex-blob \
    --verbose \
    2>"$LOG_DIR/mysqldump_verbose_${DATE}.log" | gzip > "$BACKUP_FILE"

STATUS=${PIPESTATUS[0]}
DUMP_END=$(date +%s)
DUMP_TIME=$((DUMP_END-DUMP_START))

# Append condensed dump summary into main log (last 20 lines of verbose log)
log "mysqldump verbose output (tail):"
tail -n 20 "$LOG_DIR/mysqldump_verbose_${DATE}.log" | while read -r line; do
    log "  | $line"
done

if [ "$STATUS" -ne 0 ]; then
    error "mysqldump failed with exit code $STATUS"
    error "Full verbose log: $LOG_DIR/mysqldump_verbose_${DATE}.log"
    rm -f "$BACKUP_FILE"
    finalize 1
fi

log "mysqldump completed in ${DUMP_TIME}s"

####################################################################
# Verify Backup
####################################################################

section "BACKUP VERIFICATION"

if [ ! -s "$BACKUP_FILE" ]; then
    error "Backup file is empty: $BACKUP_FILE"
    finalize 1
fi

log "Verifying gzip integrity..."
gzip -t "$BACKUP_FILE" 2>>"$LOGFILE"
if [ $? -ne 0 ]; then
    error "Backup file failed gzip integrity check: $BACKUP_FILE"
    finalize 1
fi
log "Gzip integrity check passed."

log "Checking for CREATE DATABASE statements in dump (sanity check)..."
DBCHECK=$(zcat "$BACKUP_FILE" | grep -c "^-- Current Database:")
log "Found $DBCHECK database sections in dump."
if [ "$DBCHECK" -eq 0 ]; then
    warn "No 'Current Database' markers found. Dump may be incomplete — review manually."
fi

####################################################################
# Backup Info / Stats
####################################################################

section "BACKUP SUMMARY"

SIZE=$(du -sh "$BACKUP_FILE" | awk '{print $1}')
SIZE_BYTES=$(du -b "$BACKUP_FILE" | awk '{print $1}')
MD5SUM=$(md5sum "$BACKUP_FILE" | awk '{print $1}')

END_TIME=$(date +%s)
TIME_TAKEN=$((END_TIME-START_TIME))

log "Backup Completed Successfully"
log "Backup File  : $BACKUP_FILE"
log "Backup Size  : $SIZE ($SIZE_BYTES bytes)"
log "MD5 Checksum : $MD5SUM"
log "Dump Duration: ${DUMP_TIME}s"
log "Total Duration: ${TIME_TAKEN}s"

# Write a machine-readable manifest alongside the backup
MANIFEST="$BACKUP_DIR/mysql_backup_${DATE}.manifest"
cat > "$MANIFEST" <<EOF
backup_file=$BACKUP_FILE
timestamp=$DATE
hostname=$HOST
mysql_version=$MYSQL_VERSION
database_count=$DB_COUNT
databases=$DB_LIST
size_human=$SIZE
size_bytes=$SIZE_BYTES
md5sum=$MD5SUM
dump_duration_seconds=$DUMP_TIME
total_duration_seconds=$TIME_TAKEN
EOF
log "Manifest written : $MANIFEST"

####################################################################
# Cleanup Old Backups
####################################################################

section "CLEANUP OLD BACKUPS"

log "Searching for backups older than ${RETENTION_DAYS} days in $BACKUP_DIR"

find "$BACKUP_DIR" -type f -name "*.gz" -mtime +"$RETENTION_DAYS" > /tmp/mysql_old_backups.txt
find "$BACKUP_DIR" -type f -name "*.manifest" -mtime +"$RETENTION_DAYS" > /tmp/mysql_old_manifests.txt

COUNT=$(wc -l < /tmp/mysql_old_backups.txt)

if [ "$COUNT" -eq 0 ]; then
    log "No old backups found for deletion."
else
    log "Found $COUNT old backup(s) to remove:"
    TOTAL_FREED=0
    while read -r FILE; do
        FSIZE=$(du -b "$FILE" 2>/dev/null | awk '{print $1}')
        log "  Deleting : $FILE ($(du -sh "$FILE" 2>/dev/null | awk '{print $1}'))"
        rm -f "$FILE"
        if [ $? -ne 0 ]; then
            warn "  Unable to delete $FILE"
        else
            TOTAL_FREED=$((TOTAL_FREED + FSIZE))
        fi
    done < /tmp/mysql_old_backups.txt
    log "Total space freed: $(numfmt --to=iec $TOTAL_FREED 2>/dev/null || echo "${TOTAL_FREED} bytes")"
fi

while read -r FILE; do
    rm -f "$FILE"
done < /tmp/mysql_old_manifests.txt

rm -f /tmp/mysql_old_backups.txt /tmp/mysql_old_manifests.txt

####################################################################
# Log Rotation (archive logs older than retention, compress them)
####################################################################

section "LOG ROTATION"

log "Archiving logs older than ${RETENTION_DAYS} days..."
find "$LOG_DIR" -maxdepth 1 -type f -name "*.log" -mtime +"$RETENTION_DAYS" ! -name "cron.log" | while read -r OLDLOG; do
    gzip -f "$OLDLOG"
    mv -f "${OLDLOG}.gz" "$LOG_DIR/archive/" 2>/dev/null
    log "Archived: $(basename "$OLDLOG")"
done

# Purge archived logs older than 90 days
find "$LOG_DIR/archive" -type f -name "*.gz" -mtime +90 -exec rm -f {} \; 2>/dev/null

####################################################################
# Disk Usage Report
####################################################################

section "DISK USAGE REPORT"

DISK=$(df -h "$BACKUP_DIR" | awk 'NR==2 {print $5}')
DISK_USED=$(df -h "$BACKUP_DIR" | awk 'NR==2 {print $3}')
DISK_TOTAL=$(df -h "$BACKUP_DIR" | awk 'NR==2 {print $2}')
BACKUP_DIR_SIZE=$(du -sh "$BACKUP_DIR" | awk '{print $1}')
BACKUP_FILE_COUNT=$(find "$BACKUP_DIR" -type f -name "*.gz" | wc -l)

log "Volume Usage      : $DISK ($DISK_USED / $DISK_TOTAL)"
log "Backup Dir Size    : $BACKUP_DIR_SIZE"
log "Total Backups Kept : $BACKUP_FILE_COUNT"

DISK_PCT=$(echo "$DISK" | tr -d '%')
if [ "$DISK_PCT" -ge 85 ]; then
    warn "Disk usage is at ${DISK}% — approaching capacity threshold."
fi

# ####################################################################
# # Slack Notification (Optional)
# ####################################################################

# section "NOTIFICATION"

# if [ "$ENABLE_SLACK" = true ]; then
#     log "Sending Slack notification..."
#     MESSAGE="✅ *MySQL Backup Success*
# Server    : $HOST
# Backup    : $(basename "$BACKUP_FILE")
# Size      : $SIZE
# Databases : $DB_COUNT
# Duration  : ${TIME_TAKEN}s
# Disk Used : $DISK"

#     SLACK_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
#         -X POST \
#         -H "Content-type: application/json" \
#         --data "{\"text\":\"$MESSAGE\"}" \
#         "$SLACK_WEBHOOK")

#     if [ "$SLACK_RESPONSE" = "200" ]; then
#         log "Slack notification sent successfully."
#     else
#         warn "Slack notification failed with HTTP status $SLACK_RESPONSE"
#     fi
# else
#     log "Slack notifications disabled (ENABLE_SLACK=false)."
# fi

####################################################################
# Finish
####################################################################

log "Backup Finished Successfully."
finalize 0
