#!/usr/bin/env bash
#
# log_analyzer.sh - Apache / Nginx access log analyzer
# Works with Common Log Format (CLF) and Combined Log Format.
# Supports plain text and .gz rotated logs.
#
# Author: generated for Gokul (eNova Software and Hardware Solutions)
#
# Usage:
#   ./log_analyzer.sh -f /var/log/nginx/access.log
#   ./log_analyzer.sh -f /var/log/apache2/access.log.gz -n 20
#   ./log_analyzer.sh -f /var/log/nginx/access.log -o report.txt
#   ./log_analyzer.sh -f /var/log/nginx/access.log --date "06/Aug/2026"
#
# Options:
#   -f, --file      Path to log file (required). Accepts .gz files.
#   -n, --top       Number of top entries to show per section (default: 10)
#   -o, --output    Save report to a file instead of only printing to screen
#   -d, --date      Filter for a specific day, e.g. "06/Aug/2026"
#   -s, --status    Filter for a specific HTTP status code, e.g. 500
#   -h, --help      Show usage
#
set -euo pipefail

# ---------- Defaults ----------
LOGFILE=""
TOPN=10
OUTFILE=""
DATE_FILTER=""
STATUS_FILTER=""

# ---------- Colors (disabled automatically when writing to a file) ----------
if [[ -t 1 ]]; then
    C_RESET="\033[0m"; C_BOLD="\033[1m"; C_CYAN="\033[36m"
    C_GREEN="\033[32m"; C_YELLOW="\033[33m"; C_RED="\033[31m"
else
    C_RESET=""; C_BOLD=""; C_CYAN=""; C_GREEN=""; C_YELLOW=""; C_RED=""
fi

usage() {
    grep '^#' "$0" | sed -n '2,26p' | sed 's/^#//'
    exit 1
}

# ---------- Parse arguments ----------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--file)   LOGFILE="$2"; shift 2 ;;
        -n|--top)    TOPN="$2"; shift 2 ;;
        -o|--output) OUTFILE="$2"; shift 2 ;;
        -d|--date)   DATE_FILTER="$2"; shift 2 ;;
        -s|--status) STATUS_FILTER="$2"; shift 2 ;;
        -h|--help)   usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

if [[ -z "$LOGFILE" ]]; then
    echo "Error: log file is required. Use -f /path/to/access.log"
    usage
fi

if [[ ! -f "$LOGFILE" ]]; then
    echo "Error: file not found: $LOGFILE"
    exit 1
fi

# ---------- Reader (handles .gz transparently) ----------
CAT_CMD="cat"
if [[ "$LOGFILE" == *.gz ]]; then
    CAT_CMD="zcat"
fi

# Build a reusable pipeline that applies optional date/status filters.
# CLF/Combined fields (space separated, quoting aside):
#   $1=IP $4=[timestamp  $5=+offset] $6="METHOD $7=URL $8=PROTO"  $9=STATUS $10=BYTES  "$11=REFERER" "..UA.."
read_filtered() {
    local pipeline="$CAT_CMD \"$LOGFILE\""
    if [[ -n "$DATE_FILTER" ]]; then
        pipeline="$pipeline | grep -F \"$DATE_FILTER\""
    fi
    if [[ -n "$STATUS_FILTER" ]]; then
        pipeline="$pipeline | awk -v st=\"$STATUS_FILTER\" '\$9==st'"
    fi
    eval "$pipeline"
}

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
FILTERED="$TMP_DIR/filtered.log"
read_filtered > "$FILTERED"

TOTAL_LINES=$(wc -l < "$FILTERED" | tr -d ' ')

if [[ "$TOTAL_LINES" -eq 0 ]]; then
    echo "No matching log lines found (check your filters or log format)."
    exit 0
fi

# ---------- Output handling: tee to file if requested ----------
if [[ -n "$OUTFILE" ]]; then
    exec > >(tee "$OUTFILE") 2>&1
fi

section() {
    echo -e "\n${C_BOLD}${C_CYAN}== $1 ==${C_RESET}"
}

echo -e "${C_BOLD}Apache/Nginx Log Analyzer${C_RESET}"
echo "File     : $LOGFILE"
[[ -n "$DATE_FILTER" ]]   && echo "Date filter   : $DATE_FILTER"
[[ -n "$STATUS_FILTER" ]] && echo "Status filter : $STATUS_FILTER"
echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Total requests analyzed: $TOTAL_LINES"

# ---------- 1. Top Client IPs ----------
section "Top $TOPN Client IPs"
awk '{print $1}' "$FILTERED" | sort | uniq -c | sort -rn | head -n "$TOPN" | \
    awk '{printf "  %-6s %s\n", $1, $2}'

# ---------- 2. HTTP Status Code Breakdown ----------
section "HTTP Status Code Breakdown"
awk '{print $9}' "$FILTERED" | grep -E '^[0-9]{3}$' | sort | uniq -c | sort -rn | \
    awk -v total="$TOTAL_LINES" '{pct=($1/total)*100; printf "  %-5s %-8s %5.1f%%\n", $2, $1, pct}'

# ---------- 3. Error Requests (4xx / 5xx) ----------
section "Top $TOPN Error URLs (4xx/5xx)"
awk '$9 ~ /^[45][0-9][0-9]$/ {print $9, $7}' "$FILTERED" | sort | uniq -c | sort -rn | head -n "$TOPN" | \
    awk '{printf "  %-6s status=%-4s %s\n", $1, $2, $3}'

# ---------- 4. Top Requested URLs ----------
section "Top $TOPN Requested URLs"
awk -F'"' '{print $2}' "$FILTERED" | awk '{print $2}' | sort | uniq -c | sort -rn | head -n "$TOPN" | \
    awk '{printf "  %-6s %s\n", $1, $2}'

# ---------- 5. HTTP Methods ----------
section "HTTP Methods"
awk -F'"' '{print $2}' "$FILTERED" | awk '{print $1}' | sort | uniq -c | sort -rn | \
    awk '{printf "  %-6s %s\n", $1, $2}'

# ---------- 6. Bandwidth Usage ----------
section "Bandwidth"
TOTAL_BYTES=$(awk '{ b=$10; if (b=="-") b=0; sum+=b } END {print sum+0}' "$FILTERED")
TOTAL_MB=$(awk -v b="$TOTAL_BYTES" 'BEGIN{printf "%.2f", b/1024/1024}')
echo "  Total transferred: ${TOTAL_MB} MB (${TOTAL_BYTES} bytes)"

section "Top $TOPN URLs by Bandwidth Consumed"
awk -F'"' '{split($2,r," "); url=r[2]; split($3,s," "); size=s[2]; if (size=="-" || size=="") size=0; sum[url]+=size} END {for (u in sum) printf "%d %s\n", sum[u], u}' "$FILTERED" | \
    sort -rn | head -n "$TOPN" | \
    awk '{mb=$1/1024/1024; printf "  %-10.2f MB  %s\n", mb, $2}'

# ---------- 7. Hourly Traffic Distribution ----------
section "Hourly Traffic Distribution"
awk -F'[' '{print $2}' "$FILTERED" | awk -F: '{print $2}' | sort -n | uniq -c | \
    awk '{ printf "  %02d:00  %-6s ", $2, $1; bar=""; n=$1; if(n>50) n=50; for(i=0;i<n;i++) bar=bar"#"; print bar }'

# ---------- 8. Top User Agents ----------
section "Top $TOPN User Agents"
awk -F'"' '{print $(NF-1)}' "$FILTERED" | sort | uniq -c | sort -rn | head -n "$TOPN" | \
    awk '{count=$1; $1=""; printf "  %-6s %s\n", count, $0}'

# ---------- 9. Likely Bots / Crawlers ----------
section "Likely Bots / Crawlers (by User-Agent)"
awk -F'"' '{print $(NF-1)}' "$FILTERED" | \
    grep -Ei 'bot|crawl|spider|slurp|curl|wget|python-requests|scrapy|httpclient' | \
    sort | uniq -c | sort -rn | head -n "$TOPN" | \
    awk '{count=$1; $1=""; printf "  %-6s %s\n", count, $0}'

# ---------- 10. Top Referers ----------
section "Top $TOPN Referers"
awk -F'"' '{print $4}' "$FILTERED" | grep -v '^-$' | sort | uniq -c | sort -rn | head -n "$TOPN" | \
    awk '{printf "  %-6s %s\n", $1, $2}'

# ---------- 11. Suspicious / Attack Pattern Hints ----------
section "Suspicious Request Patterns (basic heuristic)"
SUSPICIOUS=$(grep -EiC0 '\.\.\/|<script|union\s+select|base64_decode|etc\/passwd|wp-login|xmlrpc\.php|\.env|phpmyadmin' "$FILTERED" | wc -l | tr -d ' ')
echo "  Requests matching common attack patterns: $SUSPICIOUS"
if [[ "$SUSPICIOUS" -gt 0 ]]; then
    grep -Ei '\.\.\/|<script|union\s+select|base64_decode|etc\/passwd|wp-login|xmlrpc\.php|\.env|phpmyadmin' "$FILTERED" | \
        awk '{print $1, $7}' | sort | uniq -c | sort -rn | head -n "$TOPN" | \
        awk '{printf "  %-6s ip=%-16s url=%s\n", $1, $2, $3}'
fi

echo -e "\n${C_GREEN}Done.${C_RESET}"
[[ -n "$OUTFILE" ]] && echo "Report saved to: $OUTFILE"
