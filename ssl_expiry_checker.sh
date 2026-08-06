#!/bin/bash

# Number of days before expiry to trigger a warning
WARNING_DAYS=30

SITES=(
"https://google.com"
"https://github.com"
"https://example.com"
# Add the remaining domains here
)

EXPIRING=()
FAILED=()

echo "========== SSL Certificate Expiry Check =========="
echo "Date: $(date)"
echo

for SITE in "${SITES[@]}"
do
    EXPIRY=$(echo | openssl s_client -servername "$SITE" -connect "$SITE:443" 2>/dev/null \
        | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)

    if [ -z "$EXPIRY" ]; then
        printf "%-45s ERROR (Unable to retrieve certificate)\n" "$SITE"
        FAILED+=("$SITE")
        continue
    fi

    EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s)
    TODAY_EPOCH=$(date +%s)

    DAYS_LEFT=$(( (EXPIRY_EPOCH - TODAY_EPOCH) / 86400 ))

    printf "%-45s %4d days  Expires: %s\n" "$SITE" "$DAYS_LEFT" "$EXPIRY"

    if [ "$DAYS_LEFT" -le "$WARNING_DAYS" ]; then
        EXPIRING+=("$SITE ($DAYS_LEFT days)")
    fi
done

echo
echo "======================================="
echo "Summary"
echo "======================================="

echo "Total Websites : ${#SITES[@]}"
echo "Certificates Expiring within $WARNING_DAYS days : ${#EXPIRING[@]}"
echo "Certificate Check Failed : ${#FAILED[@]}"

if [ ${#EXPIRING[@]} -gt 0 ]; then
    echo
    echo "Expiring Certificates:"
    for SITE in "${EXPIRING[@]}"
    do
        echo " - $SITE"
    done
fi

if [ ${#FAILED[@]} -gt 0 ]; then
    echo
    echo "Certificate Retrieval Failed:"
    for SITE in "${FAILED[@]}"
    do
        echo " - $SITE"
    done
fi
