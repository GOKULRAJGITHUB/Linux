#!/bin/bash

LOGFILE="$HOME/website_monitor.log"

SITES=(
"https://google.com"
"https://github.com"
"https://example.com"
)
DOWN_SITES=()

echo "========== $(date '+%Y-%m-%d %H:%M:%S') ==========" | tee -a "$LOGFILE"

for SITE in "${SITES[@]}"
do
    URL="https://$SITE"

    RESULT=$(curl -k -L -s -o /dev/null \
        --connect-timeout 10 \
        --max-time 20 \
        -w "%{http_code} %{time_total}" "$URL")

    STATUS=$(echo "$RESULT" | awk '{print $1}')
    TIME=$(echo "$RESULT" | awk '{print $2}')

    if [[ "$STATUS" == "200" || "$STATUS" == "301" || "$STATUS" == "302" ]]; then
        printf "%-45s UP    HTTP:%s  Time:%ss\n" "$SITE" "$STATUS" "$TIME" | tee -a "$LOGFILE"
    else
        printf "%-45s DOWN  HTTP:%s\n" "$SITE" "$STATUS" | tee -a "$LOGFILE"
        DOWN_SITES+=("$SITE (HTTP:$STATUS)")
    fi
done

echo "" | tee -a "$LOGFILE"

echo "==========================================" | tee -a "$LOGFILE"
echo "Summary" | tee -a "$LOGFILE"
echo "==========================================" | tee -a "$LOGFILE"

echo "Total Websites : ${#SITES[@]}" | tee -a "$LOGFILE"
echo "Working        : $((${#SITES[@]}-${#DOWN_SITES[@]}))" | tee -a "$LOGFILE"
echo "Not Working    : ${#DOWN_SITES[@]}" | tee -a "$LOGFILE"

if [ ${#DOWN_SITES[@]} -gt 0 ]; then
    echo "" | tee -a "$LOGFILE"
    echo "The following websites are NOT working:" | tee -a "$LOGFILE"
    for SITE in "${DOWN_SITES[@]}"
    do
        echo " - $SITE" | tee -a "$LOGFILE"
    done
else
    echo "" | tee -a "$LOGFILE"
    echo "All websites are working." | tee -a "$LOGFILE"
fi

echo "" | tee -a "$LOGFILE"
